import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/constants/dimensions.dart';
import 'package:boda_connect/core/models/user_type.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/core/services/google_auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  bool _isLoading = false;

  void _showWhatsAppNotice(BuildContext context, {required bool isLogin}) {
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
          'O login via WhatsApp está em fase de testes. '
          'Para usar, você precisa primeiro enviar "join <sandbox-code>" '
          'para o número do WhatsApp sandbox.\n\n'
          'Recomendamos usar o login por Telefone (SMS) para uma experiência mais simples.',
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
                extra: {'isLogin': isLogin},
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

    // Show dialog to select user type
    final userType = await showDialog<UserType>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecione o tipo de conta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Cliente'),
              subtitle: const Text('Buscar fornecedores'),
              onTap: () => Navigator.pop(context, UserType.client),
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Fornecedor'),
              subtitle: const Text('Oferecer serviços'),
              onTap: () => Navigator.pop(context, UserType.supplier),
            ),
          ],
        ),
      ),
    );

    if (userType == null) {
      setState(() => _isLoading = false);
      return;
    }

    final result = await _googleAuthService.signInWithGoogle(userType: userType);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate based on user type
      if (userType == UserType.supplier) {
        if (result.isNewUser) {
          context.go(Routes.supplierBasicData);
        } else {
          context.go(Routes.supplierDashboard);
        }
      } else {
        // Client user type
        if (result.isNewUser) {
          context.go(Routes.clientDetails);
        } else {
          context.go(Routes.clientHome);
        }
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
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppDimensions.getMaxContentWidth(context) > 500
                  ? 500
                  : AppDimensions.getMaxContentWidth(context),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppDimensions.getHorizontalPadding(context),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Logo
                  Image.asset(
                    'assets/images/boda_logo.png',
                    width: AppDimensions.isWideScreen(context) ? 160 : 130,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'B',
                              style: TextStyle(
                                fontSize: AppDimensions.isWideScreen(context) ? 28 : 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            'ODA',
                            style: TextStyle(
                              fontSize: AppDimensions.isWideScreen(context) ? 28 : 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.peach,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'CONNECT',
                            style: TextStyle(
                              fontSize: AppDimensions.isWideScreen(context) ? 28 : 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.peach.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'Bem-vindo de volta!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Escolha como deseja entrar',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF737373),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Phone Button (SMS) - PRIMARY for LOGIN
                  _LoginButton(
                    color: AppColors.peach,
                    icon: Icons.phone,
                    label: 'Entrar com Telefone',
                    onTap: () {
                      context.push(
                        Routes.inputPhone,
                        extra: {'isLogin': true},
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  // WhatsApp Button - SECONDARY for LOGIN
                  _LoginButton(
                    outlined: true,
                    icon: Icons.chat,
                    label: 'Entrar com WhatsApp',
                    onTap: () => _showWhatsAppNotice(context, isLogin: true),
                  ),

                  const SizedBox(height: 14),

                  // Email Button - LOGIN
                  _LoginButton(
                    outlined: true,
                    icon: Icons.email_outlined,
                    label: 'Entrar com Email',
                    onTap: () {
                      context.push(
                        Routes.inputEmail,
                        extra: {'isLogin': true},
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
                                  // Google Logo
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
                                    'Entrar com Google',
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

                  // Divider text
                  const Text(
                    'Por que escolher BODA CONNECT?',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF737373),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFEDEDED)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_user, color: AppColors.peach),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Seguro & Confiável',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Login seguro com verificação em duas etapas',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF737373),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Footer - Go to registration
                  GestureDetector(
                    onTap: () => context.push(Routes.accountType),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Não tem uma conta? ',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF737373),
                          ),
                        ),
                        Text(
                          'Criar conta',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.peach,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
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