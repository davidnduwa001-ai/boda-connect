import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/providers/platform_settings_provider.dart';
import '../../../../core/providers/admin_chat_provider.dart';
import '../../../../core/routing/route_names.dart';

class HelpCenterScreen extends ConsumerStatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  ConsumerState<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends ConsumerState<HelpCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  final List<FAQItem> _allFAQs = [
    // Todas as categorias
    FAQItem(
      category: 'Conta',
      question: 'Como criar uma conta no BODA CONNECT?',
      answer:
          '1. Abra o aplicativo BODA CONNECT\n2. Toque em "Criar Conta"\n3. Escolha entre Cliente ou Fornecedor\n4. Preencha seus dados pessoais\n5. Verifique seu email ou telefone\n6. Complete seu perfil',
    ),
    FAQItem(
      category: 'Conta',
      question: 'Como editar minhas informações pessoais?',
      answer:
          'Vá até o seu perfil, toque no ícone de editar (lápis) no canto superior direito. Você pode alterar seu nome, foto, telefone, email e outras informações. Não se esqueça de salvar as alterações.',
    ),
    FAQItem(
      category: 'Reservas',
      question: 'Como faço uma reserva com um fornecedor?',
      answer:
          '1. Pesquise o fornecedor desejado\n2. Veja seu perfil e pacotes\n3. Escolha o pacote ou serviço\n4. Selecione a data do evento\n5. Preencha os detalhes da reserva\n6. Confirme e faça o pagamento',
    ),
    FAQItem(
      category: 'Reservas',
      question: 'Posso cancelar ou alterar uma reserva?',
      answer:
          'Sim! Você pode cancelar ou alterar uma reserva até 48 horas antes do evento. Vá até "Minhas Reservas", selecione a reserva e escolha "Cancelar" ou "Alterar Data". Note que podem aplicar-se taxas de cancelamento dependendo da política do fornecedor.',
    ),
    FAQItem(
      category: 'Pagamentos',
      question: 'Quais formas de pagamento são aceites?',
      answer:
          'Aceitamos:\n• Cartões de crédito/débito (Visa, Mastercard)\n• Multicaixa Express\n• Transferência bancária (BAI, BFA, BIC, Atlântico)\n• Pagamento no local (depende do fornecedor)',
    ),
    FAQItem(
      category: 'Pagamentos',
      question: 'É seguro fazer pagamentos pelo app?',
      answer:
          'Sim! Todos os pagamentos são processados com criptografia de ponta a ponta. Usamos tecnologia AES-256 e nunca armazenamos os dados completos do seu cartão. Seus dados financeiros estão seguros.',
    ),
    FAQItem(
      category: 'Pagamentos',
      question: 'Preciso pagar o valor total antecipadamente?',
      answer:
          'Depende do fornecedor. Alguns exigem pagamento total antecipado, outros aceitam sinal (geralmente 30-50%) e o restante no dia do evento. Verifique a política de pagamento de cada fornecedor no seu perfil.',
    ),
    FAQItem(
      category: 'Fornecedores',
      question: 'Como escolher o melhor fornecedor?',
      answer:
          '1. Veja as avaliações e classificações de outros clientes\n2. Analise o portfólio de trabalhos anteriores\n3. Compare preços e pacotes\n4. Leia os comentários verificados\n5. Entre em contacto via chat para esclarecer dúvidas\n6. Verifique a disponibilidade para a sua data',
    ),
    FAQItem(
      category: 'Fornecedores',
      question: 'O que significa "Fornecedor Verificado"?',
      answer:
          'Fornecedores Verificados passaram por um processo de validação onde confirmamos:\n• Documentos de identificação\n• Certificações profissionais\n• Portfólio real de trabalhos\n• Avaliações positivas de clientes\nEste badge garante maior confiabilidade.',
    ),
    FAQItem(
      category: 'Fornecedores',
      question: 'Posso contratar vários fornecedores para o mesmo evento?',
      answer:
          'Sim! Você pode contratar quantos fornecedores precisar para o seu evento. Por exemplo: fotógrafo, DJ, catering e decoração. Cada fornecedor será uma reserva separada no seu histórico.',
    ),
    FAQItem(
      category: 'Suporte',
      question: 'Como entro em contacto com o suporte?',
      answer:
          'Você pode contactar-nos através de:\n• Chat ao vivo (ícone no canto inferior)\n• Email: suporte@bodaconnect.ao\n• Telefone: +244 923 456 789\n• WhatsApp Business: +244 923 456 789\n\nHorário de atendimento: Segunda a Sexta, 09:00 - 22:00',
    ),
    FAQItem(
      category: 'Suporte',
      question: 'Esqueci minha senha, o que faço?',
      answer:
          'Na tela de login, toque em "Esqueci minha senha". Insira seu email ou telefone registado e você receberá um código de verificação para criar uma nova senha.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<FAQItem> _getFilteredFAQs() {
    switch (_selectedTabIndex) {
      case 0:
        return _allFAQs; // Todas
      case 1:
        return _allFAQs.where((faq) => faq.category == 'Conta').toList();
      case 2:
        return _allFAQs.where((faq) => faq.category == 'Reservas').toList();
      case 3:
        return _allFAQs
            .where((faq) => faq.category == 'Pagamentos' || faq.category == 'Fornecedores')
            .toList();
      default:
        return _allFAQs;
    }
  }

  @override
  Widget build(BuildContext context) {
    final supportContactAsync = ref.watch(supportContactProvider);
    final supportContact = supportContactAsync.value ??
        const SupportContact(
          email: 'support@bodaconnect.ao',
          phone: '+244 923 456 789',
          whatsApp: '+244923456789',
          whatsAppLink: 'https://wa.me/244923456789',
          phoneLink: 'tel:+244923456789',
          emailLink: 'mailto:support@bodaconnect.ao',
        );
    final filteredFAQs = _getFilteredFAQs();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Central de Ajuda'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            color: AppColors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.peach,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: AppColors.peach,
              indicatorWeight: 3,
              labelStyle: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(icon: Icon(Icons.help_outline), text: 'Todas'),
                Tab(icon: Icon(Icons.person_outline), text: 'Conta'),
                Tab(icon: Icon(Icons.calendar_today), text: 'Reservas'),
                Tab(icon: Icon(Icons.more_horiz), text: 'Outros'),
              ],
            ),
          ),

          // Need immediate help banner
          Container(
            margin: const EdgeInsets.all(AppDimensions.md),
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRECISA DE AJUDA IMEDIATA?',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickContactButton(
                      icon: Icons.chat_bubble_outline,
                      label: 'Chat',
                      color: AppColors.peach,
                      onTap: () => _openSupportChat(),
                    ),
                    _buildQuickContactButton(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      color: Colors.blue,
                      onTap: () => _launchEmail(supportContact.email),
                    ),
                    _buildQuickContactButton(
                      icon: Icons.phone_outlined,
                      label: 'Ligar',
                      color: Colors.green,
                      onTap: () => _launchPhone(supportContact.phone),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // FAQ List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md),
              itemCount: filteredFAQs.length + 1,
              itemBuilder: (context, index) {
                if (index == filteredFAQs.length) {
                  return _buildNotFoundSection();
                }
                return _buildFAQCard(filteredFAQs[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickContactButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha((0.1 * 255).toInt()),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQCard(FAQItem faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md,
            vertical: 4,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppDimensions.md,
            0,
            AppDimensions.md,
            AppDimensions.md,
          ),
          leading: Icon(
            Icons.help_outline,
            color: AppColors.peach,
            size: 24,
          ),
          title: Text(
            faq.question,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          children: [
            Text(
              faq.answer,
              style: AppTextStyles.body.copyWith(
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 32),
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.lightbulb_outline, size: 48, color: Colors.amber.shade700),
          const SizedBox(height: 12),
          Text(
            'Não encontrou a resposta?',
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Entre em contacto conosco através do chat, email ou telefone. Estamos aqui para ajudar!',
            style: AppTextStyles.body.copyWith(color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openSupportChat(),
            icon: const Icon(Icons.chat_bubble),
            label: const Text('Falar com Suporte'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.peach,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _openSupportChat() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, faça login para contactar o suporte'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading indicator
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
        userRole: 'client', // Default to client for help center
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Navigate to chat with the conversation ID and support user info
        // admin_support is the system support account ID used by AdminChatService
        const supportUserId = 'admin_support';
        const supportUserName = 'Suporte Boda Connect';
        context.push(
          '${Routes.chatDetail}?conversationId=$conversationId&userId=$supportUserId&userName=${Uri.encodeComponent(supportUserName)}',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Preciso de Ajuda - BODA CONNECT',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o email')),
        );
      }
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível fazer a chamada')),
        );
      }
    }
  }
}

// ==================== FAQ ITEM MODEL ====================

class FAQItem {
  final String category;
  final String question;
  final String answer;

  const FAQItem({
    required this.category,
    required this.question,
    required this.answer,
  });
}
