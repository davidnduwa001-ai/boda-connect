import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/providers/admin_chat_provider.dart';
import '../../../../core/routing/route_names.dart';
import '../widgets/seed_categories_button.dart';
import '../widgets/database_reset_button.dart';

/// Tracks the save state for auto-save visual feedback
enum SaveState { idle, saving, saved }

/// Provider to track save state for settings
final _settingsSaveStateProvider = StateProvider<SaveState>((ref) => SaveState.idle);

class SettingsScreen extends ConsumerStatefulWidget {
  final bool isSupplier;

  const SettingsScreen({super.key, this.isSupplier = false});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Timer? _saveIndicatorTimer;

  @override
  void dispose() {
    _saveIndicatorTimer?.cancel();
    super.dispose();
  }

  /// Show saving indicator and auto-dismiss after save completes
  void _showSaveIndicator() {
    _saveIndicatorTimer?.cancel();
    ref.read(_settingsSaveStateProvider.notifier).state = SaveState.saving;

    // Simulate brief save delay then show "saved" state
    _saveIndicatorTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(_settingsSaveStateProvider.notifier).state = SaveState.saved;
        // Auto-hide after 2 seconds
        _saveIndicatorTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            ref.read(_settingsSaveStateProvider.notifier).state = SaveState.idle;
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch settings from provider
    final settings = ref.watch(appSettingsProvider);
    final saveState = ref.watch(_settingsSaveStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isSupplier ? 'Preferências' : 'Configurações'),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          // Auto-save indicator
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: saveState == SaveState.idle
                ? const SizedBox.shrink()
                : Container(
                    key: ValueKey(saveState),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: saveState == SaveState.saving
                          ? AppColors.gray100
                          : AppColors.successLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (saveState == SaveState.saving)
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.gray700,
                            ),
                          )
                        else
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: AppColors.success,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          saveState == SaveState.saving ? 'Salvando...' : 'Salvo',
                          style: AppTextStyles.caption.copyWith(
                            color: saveState == SaveState.saving
                                ? AppColors.gray700
                                : AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language & Region
            _buildSectionHeader('IDIOMA E REGIÃO'),
            _buildLanguageRegionSettings(context, ref, settings),

            // Appearance
            _buildSectionHeader('APARÊNCIA'),
            _buildAppearanceSettings(context, ref, settings),

            // Notifications
            _buildSectionHeader('NOTIFICAÇÕES'),
            _buildNotificationSettings(context, ref, settings),

            // App Preferences
            _buildSectionHeader('PREFERÊNCIAS DO APP'),
            _buildAppPreferences(context, ref, settings),

            // Account
            _buildSectionHeader('CONTA'),
            _buildAccountSettings(context),

            // Debug Tools (Development Only) - ONLY shown in debug mode
            if (kDebugMode) ...[
              _buildSectionHeader('FERRAMENTAS DE DEBUG'),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: SeedCategoriesButton(),
                ),
              ),
              const SizedBox(height: 8),
              const DatabaseResetButton(),
            ],

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

  Widget _buildLanguageRegionSettings(BuildContext context, WidgetRef ref, AppSettingsState settings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildDropdownTile(
            context: context,
            icon: Icons.language,
            title: 'Idioma',
            subtitle: settings.language,
            items: ['Português', 'English', 'Français', 'Español'],
            selectedValue: settings.language,
            onChanged: (value) {
              if (value != null) {
                ref.read(appSettingsProvider.notifier).setLanguage(value);
                _showSaveIndicator();
              }
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildDropdownTile(
            context: context,
            icon: Icons.location_on_outlined,
            title: 'Região',
            subtitle: settings.region,
            items: [
              'Luanda',
              'Benguela',
              'Huambo',
              'Lobito',
              'Cabinda',
              'Huíla',
              'Namibe',
              'Bié',
              'Moxico',
              'Uíge',
              'Zaire',
              'Cuanza Norte',
              'Cuanza Sul',
              'Lunda Norte',
              'Lunda Sul',
              'Malanje',
              'Cunene',
              'Cuando Cubango',
            ],
            selectedValue: settings.region,
            onChanged: (value) {
              if (value != null) {
                ref.read(appSettingsProvider.notifier).setRegion(value);
                _showSaveIndicator();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSettings(BuildContext context, WidgetRef ref, AppSettingsState settings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildDropdownTile(
            context: context,
            icon: Icons.brightness_6,
            title: 'Tema',
            subtitle: settings.themeMode.label,
            items: ThemeModeOption.values.map((e) => e.label).toList(),
            selectedValue: settings.themeMode.label,
            onChanged: (value) {
              if (value != null) {
                final themeMode = ThemeModeOption.fromLabel(value);
                ref.read(appSettingsProvider.notifier).setThemeMode(themeMode);
                _showSaveIndicator();
              }
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildDropdownTile(
            context: context,
            icon: Icons.text_fields,
            title: 'Tamanho da Fonte',
            subtitle: settings.fontSize.label,
            items: FontSizeOption.values.map((e) => e.label).toList(),
            selectedValue: settings.fontSize.label,
            onChanged: (value) {
              if (value != null) {
                final fontSize = FontSizeOption.fromLabel(value);
                ref.read(appSettingsProvider.notifier).setFontSize(fontSize);
                _showSaveIndicator();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings(BuildContext context, WidgetRef ref, AppSettingsState settings) {
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
            icon: Icons.notifications_outlined,
            title: 'Notificações',
            subtitle: 'Activar todas as notificações',
            value: settings.notificationsEnabled,
            onChanged: (value) {
              ref.read(appSettingsProvider.notifier).setNotificationsEnabled(value);
              _showSaveIndicator();
            },
          ),
          if (settings.notificationsEnabled) ...[
            const Divider(height: 1, indent: 56),
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: _buildSwitchTile(
                icon: Icons.smartphone,
                title: 'Notificações Push',
                subtitle: 'Alertas no dispositivo',
                value: settings.pushNotifications,
                onChanged: (value) {
                  ref.read(appSettingsProvider.notifier).setPushNotifications(value);
                  _showSaveIndicator();
                },
              ),
            ),
            const Divider(height: 1, indent: 56),
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: _buildSwitchTile(
                icon: Icons.email_outlined,
                title: 'Notificações por Email',
                subtitle: widget.isSupplier
                    ? 'Novas reservas e mensagens'
                    : 'Confirmações e actualizações',
                value: settings.emailNotifications,
                onChanged: (value) {
                  ref.read(appSettingsProvider.notifier).setEmailNotifications(value);
                  _showSaveIndicator();
                },
              ),
            ),
            const Divider(height: 1, indent: 56),
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: _buildSwitchTile(
                icon: Icons.sms_outlined,
                title: 'Notificações por SMS',
                subtitle: 'Alertas importantes',
                value: settings.smsNotifications,
                onChanged: (value) {
                  ref.read(appSettingsProvider.notifier).setSmsNotifications(value);
                  _showSaveIndicator();
                },
              ),
            ),
          ],
          const Divider(height: 1, indent: 56),
          _buildSwitchTile(
            icon: Icons.campaign_outlined,
            title: 'Emails de Marketing',
            subtitle: 'Novidades e promoções',
            value: settings.marketingEmails,
            onChanged: (value) {
              ref.read(appSettingsProvider.notifier).setMarketingEmails(value);
              _showSaveIndicator();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppPreferences(BuildContext context, WidgetRef ref, AppSettingsState settings) {
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
            icon: Icons.play_circle_outline,
            title: 'Reprodução Automática',
            subtitle: 'Vídeos em portfólios',
            value: settings.autoPlayVideos,
            onChanged: (value) {
              ref.read(appSettingsProvider.notifier).setAutoPlayVideos(value);
              _showSaveIndicator();
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildSwitchTile(
            icon: Icons.data_saver_on,
            title: 'Economizar Dados',
            subtitle: 'Reduzir uso de internet',
            value: settings.dataSaver,
            onChanged: (value) {
              ref.read(appSettingsProvider.notifier).setDataSaver(value);
              _showSaveIndicator();
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildSettingTile(
            icon: Icons.storage,
            title: 'Armazenamento e Cache',
            subtitle: 'Gerir dados locais',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _showCacheDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSettings(BuildContext context) {
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
            icon: Icons.policy_outlined,
            title: 'Violações & Avisos',
            subtitle: 'Ver histórico de violações',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => context.push(Routes.violations),
          ),
          const Divider(height: 1, indent: 56),
          _buildSettingTile(
            icon: Icons.shield_outlined,
            title: 'Segurança & Privacidade',
            subtitle: 'Protecção de dados',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => context.push(Routes.securityPrivacy),
          ),
          const Divider(height: 1, indent: 56),
          _buildSettingTile(
            icon: Icons.help_outline,
            title: 'Central de Ajuda',
            subtitle: 'FAQ e suporte',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => context.push(Routes.helpCenter),
          ),
          const Divider(height: 1, indent: 56),
          _buildSettingTile(
            icon: Icons.support_agent,
            title: 'Falar com Suporte',
            subtitle: 'Chat direto com nossa equipe',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            iconColor: AppColors.info,
            onTap: () => _openSupportChat(context),
          ),
          const Divider(height: 1, indent: 56),
          _buildSettingTile(
            icon: Icons.info_outline,
            title: 'Sobre o App',
            subtitle: 'Versão 1.0.0',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _showAboutDialog(context),
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
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
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
            onChanged: onChanged,
            activeColor: AppColors.peach,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> items,
    required String selectedValue,
    required ValueChanged<String?> onChanged,
  }) {
    return InkWell(
      onTap: () => _showSelectionDialog(context, title, items, selectedValue, onChanged),
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
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showSelectionDialog(
    BuildContext context,
    String title,
    List<String> items,
    String selectedValue,
    ValueChanged<String?> onChanged,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: items.map((item) {
            final isSelected = item == selectedValue;
            return RadioListTile<String>(
              title: Text(item),
              value: item,
              groupValue: selectedValue,
              activeColor: AppColors.peach,
              selected: isSelected,
              onChanged: (value) {
                Navigator.pop(context);
                onChanged(value);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Armazenamento e Cache'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cache de Imagens: 45 MB',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 8),
            Text(
              'Dados Temporários: 12 MB',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 8),
            Text(
              'Total: 57 MB',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache limpo com sucesso'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.peach),
            child: const Text('Limpar Cache'),
          ),
        ],
      ),
    );
  }

  /// Open support chat with admin
  void _openSupportChat(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, faça login para contactar o suporte'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.peach),
      ),
    );

    try {
      final adminChatNotifier = ref.read(adminChatNotifierProvider.notifier);
      final conversationId = await adminChatNotifier.getOrCreateSupportConversation(
        userId: currentUser.uid,
        userName: currentUser.displayName ?? 'Usuário',
        userPhoto: currentUser.photoURL,
        userRole: widget.isSupplier ? 'supplier' : 'client',
      );

      if (mounted) {
        Navigator.pop(context); // Close loading

        if (conversationId != null) {
          // Navigate to chat detail screen with support user info
          // admin_support is the system support account ID used by AdminChatService
          const supportUserId = 'admin_support';
          const supportUserName = 'Suporte Boda Connect';
          context.push(
            '${Routes.chatDetail}?conversationId=$conversationId&userId=$supportUserId&userName=${Uri.encodeComponent(supportUserName)}',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao criar conversa com suporte'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('BODA CONNECT'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.peach, AppColors.peachDark],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.favorite,
                  color: AppColors.white,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Versão 1.0.0',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'A plataforma que conecta sonhos a eventos perfeitos em Angola',
                style: AppTextStyles.caption.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '© 2024 BODA CONNECT',
                style: AppTextStyles.caption.copyWith(color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
