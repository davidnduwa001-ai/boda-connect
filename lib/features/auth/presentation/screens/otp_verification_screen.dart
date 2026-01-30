import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/models/user_type.dart';
import 'package:boda_connect/core/providers/auth_provider.dart';
import 'package:boda_connect/core/providers/whatsapp_auth_provider.dart';
import 'package:boda_connect/core/providers/sms_aut_provider.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/core/services/auth_service.dart';
import 'package:boda_connect/core/services/device_fingerprint_service.dart';
import 'package:boda_connect/core/services/security_service.dart';
import 'package:boda_connect/core/widgets/loading_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OTPVerificationScreen extends ConsumerStatefulWidget {
  const OTPVerificationScreen({
    super.key,
    required this.isLogin,
    required this.userType,
    required this.phone,
    required this.countryCode,
    required this.isWhatsApp,
    this.verificationId,
  });

  final bool isLogin;
  final UserType? userType;
  final String phone;
  final String? countryCode;
  final bool isWhatsApp;
  final String? verificationId; // For Firebase SMS OTP

  @override
  ConsumerState<OTPVerificationScreen> createState() =>
      _OTPVerificationScreenState();
}

class _OTPVerificationScreenState
    extends ConsumerState<OTPVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Debug: Log verification ID status (after frame to access ref)
      final smsState = ref.read(smsAuthProvider);
      debugPrint('🔑 OTP Screen - verificationId from widget: ${widget.verificationId}');
      debugPrint('🔑 OTP Screen - verificationId from provider: ${smsState.verificationId}');
      debugPrint('🔑 OTP Screen - isWhatsApp: ${widget.isWhatsApp}');
      debugPrint('🔑 OTP Screen - phone: ${widget.phone}');

      _focusNodes[0].requestFocus();
    });

    // Setup auto-advance for OTP fields
    for (int i = 0; i < 6; i++) {
      _controllers[i].addListener(() {
        if (_controllers[i].text.length == 1 && i < 5) {
          _focusNodes[i + 1].requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _getOTPCode() {
    return _controllers.map((c) => c.text).join();
  }

  bool _isOTPComplete() {
    return _getOTPCode().length == 6;
  }

  String _formatPhoneForDisplay(String phone) {
    if (phone.startsWith('+1') && phone.length == 12) {
      final digits = phone.substring(2);
      return '+1 (${digits.substring(0, 3)}) '
          '${digits.substring(3, 6)}-${digits.substring(6)}';
    }

    if (phone.startsWith('+244') && phone.length >= 13) {
      final digits = phone.substring(4);
      return '+244 ${digits.substring(0, 3)} '
          '${digits.substring(3, 6)} ${digits.substring(6)}';
    }

    if (phone.startsWith('+33')) {
      final digits = phone.substring(3);
      return '+33 ${digits.replaceAllMapped(
        RegExp(r'.{2}'),
        (m) => '${m.group(0)} ',
      )}'.trim();
    }

    return phone;
  }

  String _deliveryLabel(bool isWhatsApp) {
    return isWhatsApp
        ? 'Código enviado por WhatsApp'
        : 'Código enviado por SMS';
  }

  Future<void> _verifyOTP() async {
    if (!_isOTPComplete()) {
      setState(() {
        _errorMessage = 'Por favor, digite o código completo';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final otpCode = _getOTPCode();

    try {
      if (widget.isWhatsApp) {
        // WhatsApp OTP verification
        await _verifyWhatsAppOTP(otpCode);
      } else {
        // Firebase SMS OTP verification
        await _verifyFirebaseOTP(otpCode);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'Erro ao verificar código. Tente novamente.';
        });
      }
    }
  }

  Future<void> _verifyWhatsAppOTP(String otpCode) async {
    final result = await ref.read(whatsAppOTPProvider.notifier).verifyOTP(
          phone: widget.phone,
          otp: otpCode,
          countryCode: widget.countryCode ?? '+244',
        );

    if (!mounted) return;

    if (result.success && result.user != null) {
      // User already signed in via WhatsApp service
      await _handleSuccessfulAuth(result.user!);
    } else {
      setState(() {
        _isVerifying = false;
        _errorMessage = result.message;
      });
    }
  }

  Future<void> _verifyFirebaseOTP(String otpCode) async {
    // Get verificationId from provider (primary) or widget (fallback)
    final smsState = ref.read(smsAuthProvider);
    final verificationId = smsState.verificationId ?? widget.verificationId;

    debugPrint('🔐 Verifying Firebase OTP: $otpCode');
    debugPrint('🔐 VerificationId from provider: ${smsState.verificationId}');
    debugPrint('🔐 VerificationId from widget: ${widget.verificationId}');
    debugPrint('🔐 Using verificationId: $verificationId');

    if (verificationId == null) {
      debugPrint('❌ VerificationId is NULL!');
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Erro de verificação. Tente enviar o código novamente.';
      });
      return;
    }

    try {
      debugPrint('🔐 Creating PhoneAuthCredential...');
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otpCode,
      );

      debugPrint('🔐 Signing in with credential...');
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      debugPrint('✅ Sign in successful: ${userCredential.user?.uid}');
      if (userCredential.user != null) {
        await _handleSuccessfulAuth(userCredential.user!);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      setState(() {
        _isVerifying = false;
        _errorMessage = _getFirebaseErrorMessage(e.code);
      });
    } catch (e) {
      debugPrint('❌ Unknown error during OTP verification: $e');
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Erro ao verificar código. Tente novamente.';
      });
    }
  }

  Future<void> _handleSuccessfulAuth(User user) async {
    try {
      final authService = AuthService();

      // Check if user exists in Firestore
      final userExists = await authService.userExists(user.uid);

      if (!userExists) {
        // NEW USER - Create user document
        if (widget.isLogin) {
          // User tried to login but doesn't exist
          setState(() {
            _isVerifying = false;
            _errorMessage = 'Conta não encontrada. Por favor, registre-se primeiro.';
          });
          await FirebaseAuth.instance.signOut();
          return;
        }

        // Create new user document using auth service (includes duplicate check)
        try {
          await authService.createUser(
            uid: user.uid,
            phone: widget.phone,
            userType: widget.userType ?? UserType.client,
          );

          debugPrint('✅ New user document created: ${user.uid}');
        } on AuthException catch (e) {
          // Handle duplicate account error
          setState(() {
            _isVerifying = false;
            _errorMessage = e.message;
          });
          await FirebaseAuth.instance.signOut();
          return;
        } catch (e) {
          setState(() {
            _isVerifying = false;
            _errorMessage = 'Erro ao criar conta. Tente novamente.';
          });
          await FirebaseAuth.instance.signOut();
          return;
        }

        await _initializeSecurityContext(user);

        // Navigate to registration flow based on user type
        if (mounted) {
          if (widget.userType == UserType.client) {
            context.go(Routes.clientDetails);
          } else if (widget.userType == UserType.supplier) {
            context.go(Routes.supplierBasicData);
          } else {
            context.go(Routes.clientHome);
          }
        }
      } else {
        // EXISTING USER - Login
        final userData = await authService.getUser(user.uid);

        if (userData == null) {
          setState(() {
            _isVerifying = false;
            _errorMessage = 'Erro ao carregar dados do usuário.';
          });
          return;
        }

        debugPrint('✅ User logged in: ${user.uid}');

        // Update last login
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'updatedAt': FieldValue.serverTimestamp(),
          'phoneVerified': true,
        });

        // Refresh auth provider state with user data
        await ref.read(authProvider.notifier).refreshUser();

        await _initializeSecurityContext(user);

        // Navigate based on user type
        if (mounted) {
          if (userData.userType == UserType.client) {
            context.go(Routes.clientHome);
          } else if (userData.userType == UserType.supplier) {
            context.go(Routes.supplierDashboard);
          } else {
            context.go(Routes.clientHome);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error in _handleSuccessfulAuth: $e');
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Erro ao processar autenticação. Tente novamente.';
      });
    }
  }

  Future<void> _initializeSecurityContext(User user) async {
    try {
      final deviceService = DeviceFingerprintService();
      final trustedDevice =
          await deviceService.registerTrustedDevice(userId: user.uid);

      final securityService = SecurityService();
      await securityService.initialize();
      await securityService.createSession(
        userId: user.uid,
        deviceId: trustedDevice.deviceId,
        deviceName: trustedDevice.deviceName,
        platform: trustedDevice.fingerprint.platform,
      );
    } catch (e) {
      debugPrint('Security initialization failed: $e');
    }
  }

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'invalid-verification-code':
        return 'Código inválido. Verifique e tente novamente.';
      case 'session-expired':
        return 'Sessão expirada. Solicite um novo código.';
      case 'invalid-phone-number':
        return 'Número de telefone inválido.';
      case 'quota-exceeded':
        return 'Limite de tentativas excedido. Tente mais tarde.';
      case 'credential-already-in-use':
        return 'Este número já está em uso.';
      case 'operation-not-allowed':
        return 'Operação não permitida.';
      default:
        return 'Código inválido. Tente novamente.';
    }
  }

  Future<void> _resendOTP() async {
    if (widget.isWhatsApp) {
      final success = await ref
          .read(whatsAppOTPProvider.notifier)
          .resendOTP(phone: widget.phone, countryCode: widget.countryCode ?? '+244');

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Novo código enviado!')),
        );
      }
    } else {
      // Navigate back to phone input to resend
      if (mounted) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final otpState = ref.watch(whatsAppOTPProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            ref.read(whatsAppOTPProvider.notifier).reset();
            ref.read(smsAuthProvider.notifier).reset();
            context.pop();
          },
        ),
      ),
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: AppColors.peachLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          size: 28,
                          color: AppColors.peach,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Verificação de Cadastro',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Digite o código enviado',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatPhoneForDisplay(widget.phone),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _deliveryLabel(widget.isWhatsApp),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // OTP Input Fields
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          return SizedBox(
                            width: 44,
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              onChanged: (value) {
                                setState(() {});
                                if (value.isEmpty && index > 0) {
                                  _focusNodes[index - 1].requestFocus();
                                }
                              },
                              decoration: InputDecoration(
                                counterText: '',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.peach,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      // Error Message
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      // Resend OTP
                      TextButton(
                        onPressed: otpState.resendCooldown == null ||
                                otpState.resendCooldown == 0
                            ? _resendOTP
                            : null,
                        child: Text(
                          otpState.resendCooldown != null && otpState.resendCooldown! > 0
                              ? 'Reenviar código em ${otpState.resendCooldown}s'
                              : 'Reenviar código',
                          style: TextStyle(
                            color: otpState.resendCooldown == null ||
                                    otpState.resendCooldown == 0
                                ? AppColors.peach
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Verify Button (fixed at bottom)
              SizedBox(
                width: double.infinity,
                child: LoadingButton(
                  isLoading: _isVerifying,
                  onPressed: _isOTPComplete() ? _verifyOTP : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.peach,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Verificar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
