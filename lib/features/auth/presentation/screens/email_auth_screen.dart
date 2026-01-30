import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/models/user_type.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/core/providers/auth_provider.dart';
import 'package:boda_connect/core/providers/email_auth_provider.dart';
import 'package:boda_connect/core/services/email_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({
    super.key,
    this.userType,
    this.isLogin = false,
  });

  final UserType? userType;
  final bool isLogin;

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLogin = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // ValueNotifier for password text to update strength indicator without full rebuild
  final _passwordTextNotifier = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    _passwordTextNotifier.value = _passwordController.text;
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordTextNotifier.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
    ref.read(emailAuthProvider.notifier).clearError();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(emailAuthProvider.notifier);

    if (_isLogin) {
      final result = await notifier.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (result.success && mounted) {
        // IMPORTANT: Refresh auth state from Firestore to get correct userType
        await ref.read(authProvider.notifier).refreshUser();

        if (result.requiresVerification) {
          _showVerificationDialog();
        } else {
          _navigateAfterAuth();
        }
      }
    } else {
      // Registration
      if (widget.userType == null) {
        // Show error if userType is not provided
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tipo de usuário não especificado'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final result = await notifier.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text,
        userType: widget.userType!,
      );

      if (result.success && mounted) {
        // IMPORTANT: Refresh auth state from Firestore to get correct userType
        // This ensures the auth provider has the newly created user document
        await ref.read(authProvider.notifier).refreshUser();

        // Skip verification for testing and navigate directly
        _navigateAfterAuth();
      }
    }
  }

  void _navigateAfterAuth() {
    if (widget.isLogin) {
      // Login - use userType from auth state (refreshed from Firestore)
      final authState = ref.read(authProvider);
      if (authState.isSupplier) {
        context.go(Routes.supplierDashboard);
      } else {
        context.go(Routes.clientHome);
      }
    } else {
      // Registration - use widget.userType (from account type selection)
      if (widget.userType == UserType.supplier) {
        context.go(Routes.supplierBasicData);
      } else {
        context.go(Routes.clientDetails);
      }
    }
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EmailVerificationDialog(
        onVerified: () {
          Navigator.of(context).pop();
          _navigateAfterAuth();
        },
        onCancel: () {
          Navigator.of(context).pop();
          ref.read(emailAuthProvider.notifier).signOut();
        },
      ),
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar Senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Digite seu email para receber um link de recuperação.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.peach,
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (result == true && emailController.text.isNotEmpty) {
      final success = await ref.read(emailAuthProvider.notifier).sendPasswordReset(
        email: emailController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Email de recuperação enviado!'
                  : 'Erro ao enviar email. Verifique o endereço.',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(emailAuthProvider);
    final emailService = ref.watch(emailAuthServiceProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            ref.read(emailAuthProvider.notifier).reset();
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Progress indicator (only for registration)
                if (!_isLogin && !widget.isLogin) ...[
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

                // Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.peachLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.email_outlined,
                    size: 28,
                    color: AppColors.peach,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  _isLogin ? 'Entrar com Email' : 'Criar Conta',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  _isLogin
                      ? 'Digite seu email e senha para entrar.'
                      : 'Preencha os dados para criar sua conta.',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),

                // Error message
                if (authState.error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authState.error!,
                            style:
                                TextStyle(color: Colors.red[700], fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Name field (only for registration)
                if (!_isLogin) ...[
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Nome completo',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.peach, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Digite seu nome';
                      }
                      if (value.trim().length < 3) {
                        return 'Nome muito curto';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.peach, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Digite seu email';
                    }
                    if (!emailService.isValidEmail(value)) {
                      return 'Email inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.peach, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Digite sua senha';
                    }
                    if (value.length < 6) {
                      return 'Senha deve ter pelo menos 6 caracteres';
                    }
                    return null;
                  },
                ),

                // Password strength indicator (only for registration)
                // Uses ValueListenableBuilder to avoid full rebuilds on every keystroke
                if (!_isLogin)
                  ValueListenableBuilder<String>(
                    valueListenable: _passwordTextNotifier,
                    builder: (context, passwordText, child) {
                      if (passwordText.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _PasswordStrengthIndicator(
                          strength: emailService.checkPasswordStrength(passwordText),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),

                // Confirm password field (only for registration)
                if (!_isLogin) ...[
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirmar senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() =>
                              _obscureConfirmPassword = !_obscureConfirmPassword);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.peach, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'As senhas não coincidem';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Forgot password (only for login)
                if (_isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: const Text(
                        'Esqueceu a senha?',
                        style: TextStyle(color: AppColors.peach),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.peach,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isLogin ? 'Entrar' : 'Criar Conta',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Toggle login/register
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLogin ? 'Não tem uma conta? ' : 'Já tem uma conta? ',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    GestureDetector(
                      onTap: _toggleMode,
                      child: Text(
                        _isLogin ? 'Criar conta' : 'Entrar',
                        style: const TextStyle(
                          color: AppColors.peach,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Password strength indicator widget
class _PasswordStrengthIndicator extends StatelessWidget {
  final PasswordStrength strength;

  const _PasswordStrengthIndicator({required this.strength});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    double progress;

    switch (strength) {
      case PasswordStrength.weak:
        color = Colors.red;
        text = 'Fraca';
        progress = 0.33;
        break;
      case PasswordStrength.medium:
        color = Colors.orange;
        text = 'Média';
        progress = 0.66;
        break;
      case PasswordStrength.strong:
        color = Colors.green;
        text = 'Forte';
        progress = 1.0;
        break;
    }

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }
}

// Email verification dialog
class _EmailVerificationDialog extends ConsumerStatefulWidget {
  final VoidCallback onVerified;
  final VoidCallback onCancel;

  const _EmailVerificationDialog({
    required this.onVerified,
    required this.onCancel,
  });

  @override
  ConsumerState<_EmailVerificationDialog> createState() =>
      _EmailVerificationDialogState();
}

class _EmailVerificationDialogState
    extends ConsumerState<_EmailVerificationDialog> {
  bool _isChecking = false;

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);

    final verified =
        await ref.read(emailAuthProvider.notifier).checkEmailVerified();

    setState(() => _isChecking = false);

    if (verified) {
      widget.onVerified();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email ainda não verificado. Verifique sua caixa de entrada.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _resendEmail() async {
    final success =
        await ref.read(emailAuthProvider.notifier).resendVerificationEmail();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Email de verificação reenviado!'
                : 'Erro ao reenviar email.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.mark_email_unread, color: AppColors.peach),
          SizedBox(width: 8),
          Text('Verificar Email'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Enviamos um link de verificação para seu email. '
            'Clique no link e depois pressione "Verificar".',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Verifique também a pasta de spam.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _resendEmail,
          child: const Text('Reenviar'),
        ),
        ElevatedButton(
          onPressed: _isChecking ? null : _checkVerification,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.peach,
          ),
          child: _isChecking
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Verificar'),
        ),
      ],
    );
  }
}