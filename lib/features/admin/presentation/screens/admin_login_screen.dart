import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/constants/text_styles.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/core/services/admin_two_factor_service.dart';
import 'package:boda_connect/core/services/device_fingerprint_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Admin login screen with Two-Factor Authentication
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // 2FA State
  final AdminTwoFactorService _twoFactorService = AdminTwoFactorService();
  final DeviceFingerprintService _deviceService = DeviceFingerprintService();

  bool _show2FAStep = false;
  bool _showTOTPSetup = false;
  String? _2faSessionId;
  String? _2faDestination;
  Admin2FAMethod? _2faMethod;
  DateTime? _2faExpiresAt;
  bool _trustDevice = false;

  // TOTP Setup state
  String? _totpSecret;
  String? _totpUri;
  String? _pendingAdminId;

  // OTP input controllers for 6-digit code
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _animationController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _combinedOtp =>
      _otpControllers.map((c) => c.text).join();

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Sign in with Firebase Auth
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Login failed');
      }

      // Check if user has admin role
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      final role = userData['role'] as String?;

      // Accept both "admin" and "app_admin" roles
      if (role != 'admin' && role != 'app_admin') {
        await FirebaseAuth.instance.signOut();
        throw Exception('Access denied. Admin privileges required.');
      }

      // Check 2FA requirement
      final deviceId = await _deviceService.getDeviceId();
      final requirement = await _twoFactorService.check2FARequirement(
        adminId: user.uid,
        deviceId: deviceId,
      );

      if (requirement.required) {
        // Check if authenticator is preferred but not yet set up
        if (requirement.preferredMethod == Admin2FAMethod.authenticator &&
            !requirement.totpEnabled) {
          // Need to set up TOTP first
          final setupResult = await _twoFactorService.setupTOTP(
            adminId: user.uid,
            adminEmail: user.email ?? _emailController.text.trim(),
          );

          if (!setupResult.success) {
            await FirebaseAuth.instance.signOut();
            throw Exception(setupResult.error ?? 'Failed to setup authenticator');
          }

          // Show TOTP setup screen
          setState(() {
            _showTOTPSetup = true;
            _totpSecret = setupResult.secret;
            _totpUri = setupResult.uri;
            _pendingAdminId = user.uid;
            _isLoading = false;
          });

          // Focus first OTP field for verification
          _otpFocusNodes[0].requestFocus();
          return;
        }

        // Initiate 2FA
        final initResult = await _twoFactorService.initiate2FA(
          adminId: user.uid,
          method: requirement.preferredMethod ?? Admin2FAMethod.authenticator,
          phoneNumber: requirement.phoneNumber,
          totpSecret: requirement.totpSecret,
        );

        if (!initResult.success) {
          if (initResult.requiresSetup) {
            // Need to set up TOTP
            final setupResult = await _twoFactorService.setupTOTP(
              adminId: user.uid,
              adminEmail: user.email ?? _emailController.text.trim(),
            );

            if (!setupResult.success) {
              await FirebaseAuth.instance.signOut();
              throw Exception(setupResult.error ?? 'Failed to setup authenticator');
            }

            setState(() {
              _showTOTPSetup = true;
              _totpSecret = setupResult.secret;
              _totpUri = setupResult.uri;
              _pendingAdminId = user.uid;
              _isLoading = false;
            });

            _otpFocusNodes[0].requestFocus();
            return;
          }
          await FirebaseAuth.instance.signOut();
          throw Exception(initResult.error ?? 'Failed to initiate 2FA');
        }

        // Show 2FA verification step
        setState(() {
          _show2FAStep = true;
          _2faSessionId = initResult.sessionId;
          _2faDestination = initResult.destination;
          _2faMethod = initResult.method;
          _2faExpiresAt = initResult.expiresAt;
          _isLoading = false;
        });

        // Focus first OTP field
        _otpFocusNodes[0].requestFocus();
      } else {
        // No 2FA required (trusted device or 2FA disabled)
        if (mounted) {
          context.go(Routes.adminDashboard);
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getFirebaseErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted && !_show2FAStep) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verify2FA() async {
    final otp = _combinedOtp;
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final deviceId = await _deviceService.getDeviceId();
      final deviceInfo = await _deviceService.getDeviceFingerprint();

      final result = await _twoFactorService.verify2FA(
        sessionId: _2faSessionId!,
        code: otp,
        deviceId: deviceId,
        deviceName: deviceInfo.model,
        trustDevice: _trustDevice,
      );

      if (result.success) {
        // Navigate to admin dashboard
        if (mounted) {
          context.go(Routes.adminDashboard);
        }
      } else {
        setState(() {
          _errorMessage = result.error ?? 'Verification failed';
        });

        // Clear OTP fields
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _otpFocusNodes[0].requestFocus();

        // If max attempts reached, go back to login
        if (result.remainingAttempts == 0) {
          await FirebaseAuth.instance.signOut();
          setState(() {
            _show2FAStep = false;
            _errorMessage =
                'Too many failed attempts. Please try logging in again.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Verification error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyTOTPSetup() async {
    final otp = _combinedOtp;
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit code';
      });
      return;
    }

    if (_pendingAdminId == null) {
      setState(() {
        _errorMessage = 'Setup error. Please try again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _twoFactorService.verifyAndEnableTOTP(
        adminId: _pendingAdminId!,
        code: otp,
      );

      if (success) {
        // TOTP enabled, navigate to dashboard
        if (mounted) {
          context.go(Routes.adminDashboard);
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid code. Please check your authenticator app and try again.';
        });

        // Clear OTP fields
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _otpFocusNodes[0].requestFocus();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Verification error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resend2FA() async {
    if (_2faSessionId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _twoFactorService.resend2FA(
        sessionId: _2faSessionId!,
      );

      if (result.success) {
        setState(() {
          _2faSessionId = result.sessionId;
          _2faDestination = result.destination;
          _2faExpiresAt = result.expiresAt;
          _errorMessage = null;
        });

        // Clear OTP fields
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _otpFocusNodes[0].requestFocus();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Code resent to ${result.destination}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = result.error ?? 'Failed to resend code';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error resending code: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _cancel2FA() async {
    await FirebaseAuth.instance.signOut();
    setState(() {
      _show2FAStep = false;
      _showTOTPSetup = false;
      _2faSessionId = null;
      _2faDestination = null;
      _2faMethod = null;
      _2faExpiresAt = null;
      _errorMessage = null;
      _trustDevice = false;
      _totpSecret = null;
      _totpUri = null;
      _pendingAdminId = null;
      for (var controller in _otpControllers) {
        controller.clear();
      }
    });
  }

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isWideScreen = screenSize.width > 900;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF5F2),
              Color(0xFFFCEBE6),
              Color(0xFFFFE4DD),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Decorative circles
            _buildDecorativeCircles(screenSize),

            // Main content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.lg),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left side - Branding (only on wide screens)
                        if (isWideScreen) ...[
                          Expanded(
                            child: _buildBrandingSection(),
                          ),
                          const SizedBox(width: 40),
                        ],

                        // Right side - Login/2FA/TOTP Setup form
                        Container(
                          width: isWideScreen ? 420 : null,
                          constraints: BoxConstraints(
                            maxWidth: isWideScreen ? 420 : 400,
                          ),
                          child: _showTOTPSetup
                              ? _buildTOTPSetupForm(isWideScreen)
                              : _show2FAStep
                                  ? _build2FAForm(isWideScreen)
                                  : _buildLoginForm(isWideScreen),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecorativeCircles(Size screenSize) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.peach.withValues(alpha: 0.1),
            ),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -150,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.peach.withValues(alpha: 0.08),
            ),
          ),
        ),
        Positioned(
          top: screenSize.height * 0.3,
          left: -50,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.peach.withValues(alpha: 0.05),
            ),
          ),
        ),
        Positioned(
          bottom: screenSize.height * 0.2,
          right: -30,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.peachDark.withValues(alpha: 0.1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandingSection() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.peach.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/boda_logo.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.peach, AppColors.peachDark],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.celebration,
                      size: 50, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'BODA CONNECT',
            style: AppTextStyles.h1.copyWith(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Admin Dashboard',
            style: AppTextStyles.h2.copyWith(
              color: AppColors.peachDark,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Manage your event services marketplace.\nMonitor appeals, suspensions, and platform analytics.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 40),
          _buildFeatureItem(
            Icons.security_outlined,
            'Two-Factor Authentication',
            'Enhanced security for admin access',
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            Icons.analytics_outlined,
            'Real-time Analytics',
            'Monitor platform performance',
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            Icons.support_agent_outlined,
            'User Management',
            'Handle appeals & suspensions',
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(bool isWideScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: AppColors.peach.withValues(alpha: 0.15),
            blurRadius: 60,
            offset: const Offset(0, 30),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo (only on mobile)
              if (!isWideScreen) ...[
                Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.peach.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/images/boda_logo.png',
                        width: 90,
                        height: 90,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.peach, AppColors.peachDark],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.admin_panel_settings,
                              size: 40, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'BODA CONNECT',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
              ],

              // Welcome text
              Text(
                isWideScreen ? 'Welcome Back' : 'Admin Portal',
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to access the dashboard',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Error message
              if (_errorMessage != null) ...[
                _buildErrorMessage(_errorMessage!),
                const SizedBox(height: 20),
              ],

              // Email field
              _buildInputLabel('Email Address'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 15),
                decoration: _buildInputDecoration(
                  hint: 'Enter your email',
                  icon: Icons.email_outlined,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Password field
              _buildInputLabel('Password'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 15),
                onFieldSubmitted: (_) => _login(),
                decoration: _buildInputDecoration(
                  hint: 'Enter your password',
                  icon: Icons.lock_outlined,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.gray400,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // Login button
              _buildPrimaryButton(
                label: 'Sign In',
                icon: Icons.arrow_forward_rounded,
                onPressed: _isLoading ? null : _login,
                isLoading: _isLoading,
              ),

              const SizedBox(height: 24),

              // Footer with 2FA notice
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.security,
                    size: 14,
                    color: AppColors.peach,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Protected by Two-Factor Authentication',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build2FAForm(bool isWideScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: AppColors.peach.withValues(alpha: 0.15),
            blurRadius: 60,
            offset: const Offset(0, 30),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 2FA Icon
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.peach.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _2faMethod == Admin2FAMethod.sms
                      ? Icons.sms_outlined
                      : Icons.security_rounded,
                  size: 40,
                  color: AppColors.peach,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Two-Factor Authentication',
              style: AppTextStyles.h3.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _2faMethod == Admin2FAMethod.authenticator
                  ? 'Enter the 6-digit code from your'
                  : 'Enter the 6-digit code sent to',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _2faDestination ?? '',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Error message
            if (_errorMessage != null) ...[
              _buildErrorMessage(_errorMessage!),
              const SizedBox(height: 20),
            ],

            // OTP Input Fields
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 48,
                  height: 56,
                  child: TextFormField(
                    controller: _otpControllers[index],
                    focusNode: _otpFocusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.gray50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.gray200, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.peach, width: 2),
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 5) {
                        _otpFocusNodes[index + 1].requestFocus();
                      }
                      // Auto-submit when all fields are filled
                      if (_combinedOtp.length == 6) {
                        _verify2FA();
                      }
                    },
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            // Trust device checkbox
            Row(
              children: [
                Checkbox(
                  value: _trustDevice,
                  onChanged: (value) {
                    setState(() {
                      _trustDevice = value ?? false;
                    });
                  },
                  activeColor: AppColors.peach,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _trustDevice = !_trustDevice;
                      });
                    },
                    child: Text(
                      'Trust this device for 30 days',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Verify button
            _buildPrimaryButton(
              label: 'Verify',
              icon: Icons.check_circle_outline,
              onPressed: _isLoading ? null : _verify2FA,
              isLoading: _isLoading,
            ),

            const SizedBox(height: 16),

            // Resend and Cancel buttons
            Row(
              mainAxisAlignment: _2faMethod == Admin2FAMethod.authenticator
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _isLoading ? null : _cancel2FA,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
                // Only show resend for SMS, authenticator generates codes locally
                if (_2faMethod == Admin2FAMethod.sms)
                  TextButton.icon(
                    onPressed: _isLoading ? null : _resend2FA,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Resend Code'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.peach,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Expiry notice (only for SMS)
            if (_2faMethod == Admin2FAMethod.sms && _2faExpiresAt != null)
              Center(
                child: Text(
                  'Code expires in ${_2faExpiresAt!.difference(DateTime.now()).inMinutes} minutes',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            // Authenticator hint
            if (_2faMethod == Admin2FAMethod.authenticator)
              Center(
                child: Text(
                  'Codes refresh every 30 seconds',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTOTPSetupForm(bool isWideScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: AppColors.peach.withValues(alpha: 0.15),
            blurRadius: 60,
            offset: const Offset(0, 30),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Setup Icon
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.peach.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.security_rounded,
                  size: 40,
                  color: AppColors.peach,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Setup Authenticator App',
              style: AppTextStyles.h3.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Scan this QR code with your authenticator app (Google Authenticator, Authy, etc.)',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // QR Code
            if (_totpUri != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gray200),
                  ),
                  child: QrImageView(
                    data: _totpUri!,
                    version: QrVersions.auto,
                    size: 180,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Manual entry option
            if (_totpSecret != null) ...[
              ExpansionTile(
                title: Text(
                  'Can\'t scan? Enter manually',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _totpSecret!,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontFamily: 'monospace',
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _totpSecret!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Secret copied to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          tooltip: 'Copy secret',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // Verification instructions
            Text(
              'Enter the 6-digit code from your app to verify setup:',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Error message
            if (_errorMessage != null) ...[
              _buildErrorMessage(_errorMessage!),
              const SizedBox(height: 16),
            ],

            // OTP Input Fields
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 48,
                  height: 56,
                  child: TextFormField(
                    controller: _otpControllers[index],
                    focusNode: _otpFocusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: AppColors.gray50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.gray200, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.peach, width: 2),
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 5) {
                        _otpFocusNodes[index + 1].requestFocus();
                      }
                      // Auto-submit when all fields are filled
                      if (_combinedOtp.length == 6) {
                        _verifyTOTPSetup();
                      }
                    },
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            // Verify button
            _buildPrimaryButton(
              label: 'Verify & Enable',
              icon: Icons.check_circle_outline,
              onPressed: _isLoading ? null : _verifyTOTPSetup,
              isLoading: _isLoading,
            ),

            const SizedBox(height: 16),

            // Cancel button
            Center(
              child: TextButton.icon(
                onPressed: _isLoading ? null : _cancel2FA,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isLoading,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.peach,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.peach.withValues(alpha: 0.6),
          elevation: 0,
          shadowColor: AppColors.peach.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.gray400,
        fontSize: 14,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 16, right: 12),
        child: Icon(icon, color: AppColors.gray400, size: 20),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.gray50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.gray200, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.peach, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.peach.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppColors.peach,
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
