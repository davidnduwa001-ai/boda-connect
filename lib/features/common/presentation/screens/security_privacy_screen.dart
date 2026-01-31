import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/supplier_provider.dart';
import '../../../../core/models/supplier_model.dart';
import '../../../../core/services/biometric_auth_service.dart';
import '../../../../core/services/totp_service.dart';

class SecurityPrivacyScreen extends ConsumerStatefulWidget {
  const SecurityPrivacyScreen({super.key});

  @override
  ConsumerState<SecurityPrivacyScreen> createState() => _SecurityPrivacyScreenState();
}

class _SecurityPrivacyScreenState extends ConsumerState<SecurityPrivacyScreen> {
  bool _biometricsEnabled = false;
  bool _biometricsAvailable = false;
  bool _twoFactorEnabled = false;
  bool _profilePublic = true;
  bool _showEmail = false;  // Default: hide for privacy
  bool _showPhone = false;  // Default: hide for privacy
  bool _showAddress = false; // Default: hide for privacy
  bool _allowMessages = true;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLoadingSecurity = true;

  final BiometricAuthService _biometricService = BiometricAuthService();
  final TotpService _totpService = TotpService();

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
    _loadSecuritySettings();
  }

  /// Load biometric and 2FA settings
  Future<void> _loadSecuritySettings() async {
    final userId = ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) {
      setState(() => _isLoadingSecurity = false);
      return;
    }

    try {
      // Check biometric availability
      final biometricsAvailable = await _biometricService.isBiometricAvailable();
      final biometricsEnabled = await _biometricService.isBiometricEnabled(userId);
      final twoFactorEnabled = await _totpService.is2FAEnabled(userId);

      if (mounted) {
        setState(() {
          _biometricsAvailable = biometricsAvailable;
          _biometricsEnabled = biometricsEnabled;
          _twoFactorEnabled = twoFactorEnabled;
          _isLoadingSecurity = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading security settings: $e');
      if (mounted) {
        setState(() => _isLoadingSecurity = false);
      }
    }
  }

  /// Load privacy settings from supplier profile in Firestore
  Future<void> _loadPrivacySettings() async {
    final supplierState = ref.read(supplierProvider);
    final supplier = supplierState.currentSupplier;

    if (supplier != null) {
      setState(() {
        _profilePublic = supplier.privacySettings.isProfilePublic;
        _showEmail = supplier.privacySettings.showEmail;
        _showPhone = supplier.privacySettings.showPhone;
        _showAddress = supplier.privacySettings.showAddress;
        _allowMessages = supplier.privacySettings.allowMessages;
        _isLoading = false;
      });
    } else {
      // Try to load from user document if not a supplier
      final userId = ref.read(authProvider).firebaseUser?.uid;
      if (userId != null) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          if (userDoc.exists) {
            final privacyData = userDoc.data()?['privacySettings'] as Map<String, dynamic>?;
            if (privacyData != null) {
              final settings = PrivacySettings.fromMap(privacyData);
              setState(() {
                _profilePublic = settings.isProfilePublic;
                _showEmail = settings.showEmail;
                _showPhone = settings.showPhone;
                _showAddress = settings.showAddress;
                _allowMessages = settings.allowMessages;
              });
            }
          }
        } catch (e) {
          debugPrint('Error loading privacy settings: $e');
        }
      }
      setState(() => _isLoading = false);
    }
  }

  /// Save privacy settings to Firestore
  Future<void> _savePrivacySettings() async {
    setState(() => _isSaving = true);

    try {
      final supplierState = ref.read(supplierProvider);
      final supplier = supplierState.currentSupplier;

      final newSettings = PrivacySettings(
        isProfilePublic: _profilePublic,
        showEmail: _showEmail,
        showPhone: _showPhone,
        showAddress: _showAddress,
        allowMessages: _allowMessages,
      );

      if (supplier != null) {
        // Save to supplier document
        await ref.read(supplierProvider.notifier).updateSupplier({
          'privacySettings': newSettings.toMap(),
        });
      } else {
        // Save to user document
        final userId = ref.read(authProvider).firebaseUser?.uid;
        if (userId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'privacySettings': newSettings.toMap(),
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações de privacidade salvas'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Segurança & Privacidade'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Security Banner
            Container(
              margin: const EdgeInsets.all(AppDimensions.md),
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withAlpha((0.3 * 255).toInt())),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha((0.2 * 255).toInt()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.verified_user, color: AppColors.success, size: 24),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conta Protegida',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Seus dados estão seguros conosco',
                          style: AppTextStyles.caption.copyWith(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Security Section
            _buildSectionHeader('SEGURANÇA DA CONTA'),
            _buildSecuritySettings(),

            // Privacy Section
            _buildSectionHeader('PRIVACIDADE'),
            _buildPrivacySettings(),

            // Data Management Section
            _buildSectionHeader('GESTÃO DE DADOS'),
            _buildDataManagement(),

            // Legal Section
            _buildSectionHeader('LEGAL'),
            _buildLegalLinks(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.lg,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      child: Text(
        title,
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSecuritySettings() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.lock_outline,
            title: 'Alterar Senha',
            subtitle: 'Atualizar senha de acesso',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _showChangePasswordDialog(),
          ),
          const Divider(height: 1, indent: 56),
          _buildSwitchTile(
            icon: Icons.fingerprint,
            title: 'Autenticação Biométrica',
            subtitle: _biometricsAvailable
                ? 'Use impressão digital ou Face ID'
                : 'Não disponível neste dispositivo',
            value: _biometricsEnabled,
            enabled: _biometricsAvailable && !_isLoadingSecurity,
            onChanged: _biometricsAvailable ? (value) => _toggleBiometrics(value) : null,
          ),
          const Divider(height: 1, indent: 56),
          _buildSwitchTile(
            icon: Icons.security,
            title: 'Autenticação de Dois Factores',
            subtitle: _twoFactorEnabled
                ? 'Protegido com app autenticador'
                : 'Adicione segurança extra com TOTP',
            value: _twoFactorEnabled,
            enabled: !_isLoadingSecurity,
            onChanged: (value) => _toggle2FA(value),
          ),
          const Divider(height: 1, indent: 56),
          _buildSettingTile(
            icon: Icons.shield_outlined,
            title: 'Safety history',
            subtitle: 'View safety score and warnings',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              final userId = ref.read(authProvider).firebaseUser?.uid;
              if (userId != null) {
                context.push(Routes.safetyHistory, extra: userId);
              }
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildSettingTile(
            icon: Icons.devices,
            title: 'Dispositivos Conectados',
            subtitle: 'Gerir sessões activas',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _showConnectedDevicesSheet(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySettings() {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildSwitchTile(
            icon: Icons.public,
            title: 'Perfil Público',
            subtitle: 'Permitir que clientes vejam seu perfil',
            value: _profilePublic,
            onChanged: (value) {
              setState(() => _profilePublic = value);
              _savePrivacySettings();
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildSwitchTile(
            icon: Icons.email_outlined,
            title: 'Mostrar Email',
            subtitle: 'Exibir email no perfil público',
            value: _showEmail,
            onChanged: (value) {
              setState(() => _showEmail = value);
              _savePrivacySettings();
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildSwitchTile(
            icon: Icons.phone_outlined,
            title: 'Mostrar Telefone',
            subtitle: 'Exibir telefone no perfil público',
            value: _showPhone,
            onChanged: (value) {
              setState(() => _showPhone = value);
              _savePrivacySettings();
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildSwitchTile(
            icon: Icons.location_on_outlined,
            title: 'Mostrar Endereço',
            subtitle: 'Exibir localização no perfil público',
            value: _showAddress,
            onChanged: (value) {
              setState(() => _showAddress = value);
              _savePrivacySettings();
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildSwitchTile(
            icon: Icons.message_outlined,
            title: 'Permitir Mensagens',
            subtitle: 'Aceitar mensagens de clientes',
            value: _allowMessages,
            onChanged: (value) {
              setState(() => _allowMessages = value);
              _savePrivacySettings();
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildSettingTile(
            icon: Icons.block,
            title: 'Utilizadores Bloqueados',
            subtitle: 'Gerir lista de bloqueios',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _showBlockedUsersSheet(),
          ),
          // Saving indicator
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(AppDimensions.sm),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildDataManagement() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.download_outlined,
            title: 'Descarregar Meus Dados',
            subtitle: 'Exportar dados da conta',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () async {
              final confirmed = await _showConfirmDialog(
                context,
                title: 'Descarregar Dados',
                message:
                    'Será enviado um email com um link para descarregar todos os seus dados. Este processo pode levar até 48 horas.',
              );
              if (confirmed && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Solicitação enviada! Verifique seu email em breve.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildSettingTile(
            icon: Icons.delete_outline,
            iconColor: Colors.red,
            title: 'Eliminar Conta',
            titleColor: Colors.red,
            subtitle: 'Remover permanentemente',
            trailing: const Icon(Icons.chevron_right, color: Colors.red),
            onTap: () async {
              final confirmed = await _showDangerDialog(
                context,
                title: 'Eliminar Conta',
                message:
                    'ATENÇÃO: Esta ação é irreversível!\n\n'
                    'Todos os seus dados, incluindo:\n'
                    '• Perfil e informações pessoais\n'
                    '• Histórico de reservas\n'
                    '• Avaliações e comentários\n'
                    '• Conversas e mensagens\n\n'
                    'Serão permanentemente eliminados.\n\n'
                    'Tem certeza que deseja continuar?',
              );
              if (confirmed && mounted) {
                await _deleteAccount();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegalLinks() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.description_outlined,
            title: 'Política de Privacidade',
            subtitle: 'Como protegemos seus dados',
            trailing: const Icon(Icons.open_in_new, size: 20, color: Colors.grey),
            onTap: () => _launchUrl('https://bodaconnect.ao/privacy'),
          ),
          const Divider(height: 1, indent: 56),
          _buildSettingTile(
            icon: Icons.gavel_outlined,
            title: 'Termos de Uso',
            subtitle: 'Condições de utilização',
            trailing: const Icon(Icons.open_in_new, size: 20, color: Colors.grey),
            onTap: () => _launchUrl('https://bodaconnect.ao/terms'),
          ),
          const Divider(height: 1, indent: 56),
          _buildSettingTile(
            icon: Icons.cookie_outlined,
            title: 'Política de Cookies',
            subtitle: 'Uso de cookies e rastreamento',
            trailing: const Icon(Icons.open_in_new, size: 20, color: Colors.grey),
            onTap: () => _launchUrl('https://bodaconnect.ao/cookies'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.peach).withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor ?? AppColors.peach, size: 20),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
    bool enabled = true,
  }) {
    final isEnabled = enabled && onChanged != null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.peach.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.peach, size: 20),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              onChanged: isEnabled ? onChanged : null,
              activeColor: AppColors.peach,
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _showDangerDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o link')),
        );
      }
    }
  }

  // ==================== CHANGE PASSWORD ====================
  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Alterar Senha'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Senha Atual',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => obscureCurrent = !obscureCurrent),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Nova Senha',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => obscureNew = !obscureNew),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    helperText: 'Mínimo 8 caracteres',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirmar Nova Senha',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      // Validate
                      if (newPasswordController.text.length < 8) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('A senha deve ter pelo menos 8 caracteres'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }
                      if (newPasswordController.text != confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('As senhas não coincidem'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null || user.email == null) {
                          throw Exception('Utilizador não autenticado');
                        }

                        // Re-authenticate user
                        final credential = EmailAuthProvider.credential(
                          email: user.email!,
                          password: currentPasswordController.text,
                        );
                        await user.reauthenticateWithCredential(credential);

                        // Update password
                        await user.updatePassword(newPasswordController.text);

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Senha alterada com sucesso!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        String message = 'Erro ao alterar senha';
                        if (e.code == 'wrong-password') {
                          message = 'Senha atual incorreta';
                        } else if (e.code == 'weak-password') {
                          message = 'A nova senha é muito fraca';
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message), backgroundColor: AppColors.error),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      } finally {
                        if (context.mounted) setState(() => isLoading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Alterar'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== CONNECTED DEVICES ====================
  void _showConnectedDevicesSheet() {
    final userId = ref.read(authProvider).firebaseUser?.uid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Row(
                children: [
                  const Icon(Icons.devices, color: AppColors.peach),
                  const SizedBox(width: 12),
                  Text(
                    'Dispositivos Conectados',
                    style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Devices List
            Expanded(
              child: userId == null
                  ? const Center(child: Text('Não foi possível carregar dispositivos'))
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('sessions')
                          .orderBy('lastActive', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        // If no sessions collection, show current device only
                        final sessions = snapshot.data?.docs ?? [];

                        if (sessions.isEmpty) {
                          return _buildCurrentDeviceOnly();
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(AppDimensions.md),
                          itemCount: sessions.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final session = sessions[index].data() as Map<String, dynamic>;
                            final isCurrentDevice = session['isCurrent'] == true;
                            final deviceName = session['deviceName'] ?? 'Dispositivo Desconhecido';
                            final lastActive = session['lastActive'] as Timestamp?;
                            final location = session['location'] ?? 'Localização desconhecida';

                            return ListTile(
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isCurrentDevice
                                      ? AppColors.successLight
                                      : AppColors.gray100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getDeviceIcon(session['deviceType'] ?? 'mobile'),
                                  color: isCurrentDevice ? AppColors.success : AppColors.gray700,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(deviceName)),
                                  if (isCurrentDevice)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.successLight,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Este dispositivo',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(location),
                                  if (lastActive != null)
                                    Text(
                                      'Última atividade: ${_formatLastActive(lastActive.toDate())}',
                                      style: AppTextStyles.caption,
                                    ),
                                ],
                              ),
                              trailing: isCurrentDevice
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.logout, color: AppColors.error),
                                      onPressed: () => _logoutDevice(sessions[index].id),
                                    ),
                            );
                          },
                        );
                      },
                    ),
            ),
            // Logout All Button
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimensions.md,
                AppDimensions.sm,
                AppDimensions.md,
                AppDimensions.md + MediaQuery.of(context).padding.bottom,
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _logoutAllDevices(),
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: const Text('Terminar sessão em todos os dispositivos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentDeviceOnly() {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.md),
      children: [
        ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.phone_android, color: AppColors.success),
          ),
          title: Row(
            children: [
              const Expanded(child: Text('Este Dispositivo')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Activo',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          subtitle: const Text('Sessão actual'),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.infoLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.info),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Apenas este dispositivo está conectado à sua conta.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.info),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'desktop':
      case 'web':
        return Icons.computer;
      case 'tablet':
        return Icons.tablet;
      default:
        return Icons.phone_android;
    }
  }

  String _formatLastActive(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 5) return 'Agora';
    if (diff.inHours < 1) return 'Há ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Há ${diff.inHours} horas';
    if (diff.inDays < 7) return 'Há ${diff.inDays} dias';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  Future<void> _logoutDevice(String sessionId) async {
    final confirmed = await _showConfirmDialog(
      context,
      title: 'Terminar Sessão',
      message: 'Deseja terminar a sessão neste dispositivo?',
    );

    if (confirmed) {
      try {
        final userId = ref.read(authProvider).firebaseUser?.uid;
        if (userId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('sessions')
              .doc(sessionId)
              .delete();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sessão terminada com sucesso'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _logoutAllDevices() async {
    final confirmed = await _showDangerDialog(
      context,
      title: 'Terminar Todas as Sessões',
      message: 'Isto irá desconectar todos os dispositivos, incluindo este. '
          'Terá que fazer login novamente.',
    );

    if (confirmed) {
      try {
        final userId = ref.read(authProvider).firebaseUser?.uid;
        if (userId != null) {
          // Delete all sessions
          final sessions = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('sessions')
              .get();

          for (final doc in sessions.docs) {
            await doc.reference.delete();
          }

          // Sign out
          await FirebaseAuth.instance.signOut();

          if (mounted) {
            context.go('/welcome');
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  // ==================== BLOCKED USERS ====================
  void _showBlockedUsersSheet() {
    final userId = ref.read(authProvider).firebaseUser?.uid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Row(
                children: [
                  const Icon(Icons.block, color: AppColors.error),
                  const SizedBox(width: 12),
                  Text(
                    'Utilizadores Bloqueados',
                    style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Blocked Users List
            Expanded(
              child: userId == null
                  ? const Center(child: Text('Não foi possível carregar'))
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('blockedUsers')
                          .orderBy('blockedAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final blockedUsers = snapshot.data?.docs ?? [];

                        if (blockedUsers.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'Nenhum utilizador bloqueado',
                                  style: AppTextStyles.body.copyWith(color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Quando bloquear alguém, aparecerá aqui',
                                  style: AppTextStyles.caption.copyWith(color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(AppDimensions.md),
                          itemCount: blockedUsers.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final blocked = blockedUsers[index].data() as Map<String, dynamic>;
                            final blockedUserId = blockedUsers[index].id;
                            final userName = blocked['userName'] ?? 'Utilizador';
                            final blockedAt = blocked['blockedAt'] as Timestamp?;
                            final reason = blocked['reason'] as String?;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.gray200,
                                child: Text(
                                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                                  style: const TextStyle(color: AppColors.gray700),
                                ),
                              ),
                              title: Text(userName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (reason != null && reason.isNotEmpty)
                                    Text('Motivo: $reason'),
                                  if (blockedAt != null)
                                    Text(
                                      'Bloqueado em ${_formatLastActive(blockedAt.toDate())}',
                                      style: AppTextStyles.caption,
                                    ),
                                ],
                              ),
                              trailing: TextButton(
                                onPressed: () => _unblockUser(blockedUserId, userName),
                                child: const Text('Desbloquear'),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unblockUser(String blockedUserId, String userName) async {
    final confirmed = await _showConfirmDialog(
      context,
      title: 'Desbloquear Utilizador',
      message: 'Deseja desbloquear $userName? Poderá enviar-lhe mensagens novamente.',
    );

    if (confirmed) {
      try {
        final userId = ref.read(authProvider).firebaseUser?.uid;
        if (userId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('blockedUsers')
              .doc(blockedUserId)
              .delete();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$userName foi desbloqueado'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  // ==================== ACCOUNT DELETION ====================
  Future<void> _deleteAccount() async {
    // Show final confirmation with password
    final passwordController = TextEditingController();
    bool isDeleting = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: AppColors.error),
              SizedBox(width: 8),
              Text('Confirmar Eliminação'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Por segurança, insira sua senha para confirmar a eliminação da conta.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Por favor, insira sua senha'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      setState(() => isDeleting = true);

                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null || user.email == null) {
                          throw Exception('Utilizador não autenticado');
                        }

                        // Re-authenticate
                        final credential = EmailAuthProvider.credential(
                          email: user.email!,
                          password: passwordController.text,
                        );
                        await user.reauthenticateWithCredential(credential);

                        // Mark user as deleted in Firestore
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .update({
                          'isDeleted': true,
                          'deletedAt': FieldValue.serverTimestamp(),
                          'isActive': false,
                        });

                        // Delete Firebase Auth user
                        await user.delete();

                        if (context.mounted) {
                          Navigator.pop(context, true);
                        }
                      } on FirebaseAuthException catch (e) {
                        String message = 'Erro ao eliminar conta';
                        if (e.code == 'wrong-password') {
                          message = 'Senha incorreta';
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message), backgroundColor: AppColors.error),
                          );
                          setState(() => isDeleting = false);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
                          );
                          setState(() => isDeleting = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Eliminar Conta'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      // Navigate to welcome screen
      context.go('/welcome');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sua conta foi eliminada com sucesso'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  // ==================== BIOMETRIC AUTHENTICATION ====================
  Future<void> _toggleBiometrics(bool enable) async {
    final userId = ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) return;

    try {
      final success = await _biometricService.setBiometricEnabled(userId, enable);

      if (success && mounted) {
        setState(() => _biometricsEnabled = enable);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enable
                  ? 'Autenticação biométrica activada'
                  : 'Autenticação biométrica desactivada',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ==================== TWO-FACTOR AUTHENTICATION ====================
  Future<void> _toggle2FA(bool enable) async {
    if (enable) {
      await _show2FASetupDialog();
    } else {
      await _show2FADisableDialog();
    }
  }

  Future<void> _show2FASetupDialog() async {
    final userId = ref.read(authProvider).firebaseUser?.uid;
    final userEmail = ref.read(authProvider).firebaseUser?.email;

    if (userId == null || userEmail == null) return;

    // Generate setup data
    Map<String, String>? setupData;
    try {
      setupData = await _totpService.setup2FA(userId, userEmail);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao configurar 2FA: $e'), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    if (!mounted || setupData == null) return;

    final codeController = TextEditingController();
    bool isVerifying = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security, color: AppColors.peach),
              SizedBox(width: 12),
              Text('Configurar 2FA'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Instale um app autenticador:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text('   • Google Authenticator\n   • Microsoft Authenticator\n   • Authy'),
                const SizedBox(height: 16),
                const Text(
                  '2. Escaneie o QR code:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: QrImageView(
                      data: setupData!['otpAuthUri']!,
                      version: QrVersions.auto,
                      size: 180,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ou insira manualmente:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    setupData['secret']!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '3. Insira o código de 6 dígitos:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    counterText: '',
                    errorText: errorMessage,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      final code = codeController.text.trim();
                      if (code.length != 6) {
                        setDialogState(() => errorMessage = 'Insira um código de 6 dígitos');
                        return;
                      }

                      setDialogState(() {
                        isVerifying = true;
                        errorMessage = null;
                      });

                      try {
                        final success = await _totpService.verify2FASetup(userId, code);
                        if (success) {
                          if (context.mounted) Navigator.pop(context, true);
                        } else {
                          setDialogState(() {
                            errorMessage = 'Código inválido. Tente novamente.';
                            isVerifying = false;
                          });
                        }
                      } catch (e) {
                        setDialogState(() {
                          errorMessage = 'Erro: $e';
                          isVerifying = false;
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach),
              child: isVerifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Verificar'),
            ),
          ],
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        setState(() => _twoFactorEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Autenticação de dois factores activada!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  Future<void> _show2FADisableDialog() async {
    final userId = ref.read(authProvider).firebaseUser?.uid;
    if (userId == null) return;

    final codeController = TextEditingController();
    bool isVerifying = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security, color: AppColors.warning),
              SizedBox(width: 12),
              Text('Desactivar 2FA'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para desactivar a autenticação de dois factores, insira o código atual do seu app autenticador:',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  errorText: errorMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      final code = codeController.text.trim();
                      if (code.length != 6) {
                        setDialogState(() => errorMessage = 'Insira um código de 6 dígitos');
                        return;
                      }

                      setDialogState(() {
                        isVerifying = true;
                        errorMessage = null;
                      });

                      try {
                        final success = await _totpService.disable2FA(userId, code);
                        if (success) {
                          if (context.mounted) Navigator.pop(context, true);
                        } else {
                          setDialogState(() {
                            errorMessage = 'Código inválido. Tente novamente.';
                            isVerifying = false;
                          });
                        }
                      } catch (e) {
                        setDialogState(() {
                          errorMessage = 'Erro: $e';
                          isVerifying = false;
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
              child: isVerifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Desactivar'),
            ),
          ],
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        setState(() => _twoFactorEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Autenticação de dois factores desactivada'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    });
  }
}
