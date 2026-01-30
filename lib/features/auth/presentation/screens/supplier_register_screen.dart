import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/models/user_type.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/core/services/google_auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SupplierRegisterScreen extends StatefulWidget {
  const SupplierRegisterScreen({super.key});

  @override
  State<SupplierRegisterScreen> createState() => _SupplierRegisterScreenState();
}

class _SupplierRegisterScreenState extends State<SupplierRegisterScreen> {
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  bool _isLoading = false;

  void _showWhatsAppNotice(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF25D366)),
            SizedBox(width: 8),
            Text('WhatsApp (Beta)'),
          ],
        ),
        content: const Text(
          'O registro via WhatsApp está em fase de testes. '
          'Para usar, você precisa primeiro enviar "join <sandbox-code>" '
          'para o número do WhatsApp sandbox.\n\n'
          'Recomendamos usar o registro por Telefone (SMS) para uma experiência mais simples.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push(
                Routes.inputWhatsapp,
                extra: {
                  'userType': UserType.supplier,
                  'isLogin': false,
                },
              );
            },
            child: const Text(
              'Continuar com WhatsApp',
              style: TextStyle(color: Color(0xFF25D366)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    final result = await _googleAuthService.signInWithGoogle(userType: UserType.supplier);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.green,
        ),
      );
      // Navigate to supplier basic data to complete profile
      if (result.isNewUser) {
        context.go(Routes.supplierBasicData);
      } else {
        context.go(Routes.supplierDashboard);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: const Text(
          'BODA CONNECT',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.peach,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),

              const Text(
                'Registrar-se como\nFornecedor',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Comece a receber pedidos de eventos na BODA CONNECT.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF737373),
                ),
              ),

              const SizedBox(height: 32),

              // Phone (SMS) - PRIMARY for SUPPLIER REGISTRATION
              _ActionButton(
                color: AppColors.peach,
                icon: Icons.phone,
                label: 'Registrar com Telefone',
                onTap: () {
                  context.push(
                    Routes.inputPhone,
                    extra: {
                      'userType': UserType.supplier,
                      'isLogin': false,
                    },
                  );
                },
              ),

              const SizedBox(height: 14),

              // WhatsApp - SECONDARY for SUPPLIER REGISTRATION
              _ActionButton(
                outlined: true,
                icon: Icons.chat,
                label: 'Registrar com WhatsApp',
                onTap: () => _showWhatsAppNotice(context),
              ),

              const SizedBox(height: 14),

              // Email - SUPPLIER REGISTRATION
              _ActionButton(
                outlined: true,
                icon: Icons.email_outlined,
                label: 'Registrar com Email',
                onTap: () {
                  context.push(
                    Routes.inputEmail,
                    extra: {
                      'userType': UserType.supplier,
                      'isLogin': false,
                    },
                  );
                },
              ),

              // Google Sign-In Button - hidden on Web due to popup limitations
              if (!kIsWeb) ...[
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _isLoading ? () {} : _handleGoogleSignIn,
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.peach),
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: const Center(
                                  child: Text(
                                    'G',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4285F4),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Registrar com Google',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Benefits card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.peachLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vantagens de ser fornecedor:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 8),
                    _BenefitItem(text: 'Acesso a milhares de clientes'),
                    _BenefitItem(text: 'Gestão fácil de pedidos'),
                    _BenefitItem(text: 'Pagamentos seguros'),
                  ],
                ),
              ),

              const Spacer(),

              // Already have account
              GestureDetector(
                onTap: () => context.push(Routes.login),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Já tem uma conta? ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF737373),
                      ),
                    ),
                    Text(
                      'Entrar',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.peach,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              const Divider(height: 1),

              const SizedBox(height: 12),

              const Text(
                'Ao se registrar, você concorda com os\n'
                'Termos e Condições da BODA CONNECT e com a\n'
                'nossa Política de Privacidade.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF737373),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.peach, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF737373)),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.outlined = false,
  });

  final Color? color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: outlined ? Colors.white : color,
          borderRadius: BorderRadius.circular(16),
          border: outlined ? Border.all(color: const Color(0xFFE0E0E0)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: outlined ? Colors.black : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: outlined ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}