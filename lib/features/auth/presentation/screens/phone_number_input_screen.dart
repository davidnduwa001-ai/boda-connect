import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/models/user_type.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/core/providers/whatsapp_auth_provider.dart';
import 'package:boda_connect/core/providers/sms_aut_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum PhoneInputType { phone, whatsapp }

class PhoneNumberInputScreen extends ConsumerStatefulWidget {
  const PhoneNumberInputScreen({
    required this.type,
    super.key,
    this.userType,
    this.isLogin = false,
  });

  final PhoneInputType type;
  final UserType? userType;
  final bool isLogin;

  @override
  ConsumerState<PhoneNumberInputScreen> createState() =>
      _PhoneNumberInputScreenState();
}

class _PhoneNumberInputScreenState
    extends ConsumerState<PhoneNumberInputScreen> {
  final _phoneController = TextEditingController();
  bool _isValid = false;
  String _selectedCountryCode = '+244';

  final List<Map<String, String>> _countryCodes = [
    {'code': '+244', 'name': 'Angola', 'flag': '🇦🇴'},
    {'code': '+351', 'name': 'Portugal', 'flag': '🇵🇹'},
    {'code': '+258', 'name': 'Moçambique', 'flag': '🇲🇿'},
    {'code': '+55', 'name': 'Brasil', 'flag': '🇧🇷'},
    {'code': '+243', 'name': 'Congo (DRC)', 'flag': '🇨🇩'},
    {'code': '+33', 'name': 'France', 'flag': '🇫🇷'},
    {'code': '+1', 'name': 'United States', 'flag': '🇺🇸'},
    {'code': '+27', 'name': 'South Africa', 'flag': '🇿🇦'},
  ];

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_validatePhone);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _validatePhone() {
    final digitsOnly = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _isValid = digitsOnly.length >= 6;
    });
  }

  String _normalizePhoneNumber() {
    final raw = _phoneController.text.trim();
    final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');
    return '$_selectedCountryCode$digitsOnly';
  }

  Future<void> _sendOTP() async {
    final isWhatsapp = widget.type == PhoneInputType.whatsapp;
    final fullPhoneNumber = _normalizePhoneNumber();

    // ===============================
    // ✅ WHATSAPP OTP (TWILIO)
    // ===============================
    if (isWhatsapp) {
      final success = await ref
          .read(whatsAppOTPProvider.notifier)
          .sendOTP(phone: fullPhoneNumber);

      if (success && mounted) {
        context.push(
          Routes.otpVerification,
          extra: {
            'userType': widget.userType,
            'isLogin': widget.isLogin,
            'phone': fullPhoneNumber,
            'isWhatsApp': true,
          },
        );
      }
      return;
    }

    // ===============================
    // ✅ SMS OTP (FIREBASE via Provider)
    // ===============================
    final success = await ref
        .read(smsAuthProvider.notifier)
        .sendOTP(phone: fullPhoneNumber, countryCode: _selectedCountryCode);

    if (mounted) {
      if (success) {
        // Navigate to OTP screen - verificationId is stored in smsAuthProvider
        context.push(
          Routes.otpVerification,
          extra: {
            'userType': widget.userType,
            'isLogin': widget.isLogin,
            'phone': fullPhoneNumber,
            'isWhatsApp': false,
          },
        );
      } else {
        final error = ref.read(smsAuthProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Erro ao enviar SMS')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWhatsapp = widget.type == PhoneInputType.whatsapp;
    final otpState = ref.watch(whatsAppOTPProvider);
    final smsState = ref.watch(smsAuthProvider);
    final isLoading = isWhatsapp ? otpState.isLoading : smsState.isLoading;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            ref.read(whatsAppOTPProvider.notifier).reset();
            context.pop();
          },
        ),
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            if (!widget.isLogin) ...[
              const Text(
                'Passo 1 de 4',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const LinearProgressIndicator(
                value: 0.25,
                backgroundColor: AppColors.gray200,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.peach),
              ),
            ],

            const SizedBox(height: 24),

            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color:
                    isWhatsapp ? const Color(0xFFE8F5E9) : AppColors.peachLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isWhatsapp ? Icons.chat_bubble_outline : Icons.call_outlined,
                size: 28,
                color: isWhatsapp ? const Color(0xFF25D366) : AppColors.peach,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              isWhatsapp ? 'Número de WhatsApp' : 'Número de Telefone',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              widget.isLogin
                  ? 'Introduza o número associado à sua conta.'
                  : isWhatsapp
                      ? 'Receberá um código de verificação no seu WhatsApp.'
                      : 'Receberá um código de verificação por SMS.',
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 24),

            const Text(
              'Número',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // ===============================
            // 📱 INPUT UI (RESTORED)
            // ===============================
            Row(
              children: [
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCountryCode,
                      items: _countryCodes.map((country) {
                        return DropdownMenuItem(
                          value: country['code'],
                          child: Text(
                            '${country['flag']} ${country['code']}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedCountryCode = value!);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '923 456 789',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isWhatsapp
                              ? const Color(0xFF25D366)
                              : AppColors.peach,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isValid && !isLoading ? _sendOTP : null,
                child: const Text('Continuar'),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
