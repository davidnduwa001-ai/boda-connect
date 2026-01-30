import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';

class TermsPrivacyScreen extends ConsumerStatefulWidget {
  const TermsPrivacyScreen({super.key});

  @override
  ConsumerState<TermsPrivacyScreen> createState() => _TermsPrivacyScreenState();
}

class _TermsPrivacyScreenState extends ConsumerState<TermsPrivacyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Termos & Privacidade'),
        backgroundColor: AppColors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.peach,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: AppColors.peach,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Termos de Uso'),
            Tab(text: 'Privacidade'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTermsTab(),
          _buildPrivacyTab(),
        ],
      ),
    );
  }

  Widget _buildTermsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Last Updated
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.update, color: AppColors.info, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Última actualização: 20 de Janeiro de 2024',
                  style: AppTextStyles.caption.copyWith(color: AppColors.info),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Introduction
          Text(
            'Bem-vindo ao BODA CONNECT',
            style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Ao utilizar a plataforma BODA CONNECT, você concorda com os seguintes termos e condições. Por favor, leia atentamente.',
            style: AppTextStyles.body.copyWith(color: Colors.grey.shade700, height: 1.5),
          ),
          const SizedBox(height: 24),

          // Sections
          _buildTermSection(
            '1. Aceitação dos Termos',
            'Ao criar uma conta ou utilizar os serviços do BODA CONNECT, você confirma que leu, compreendeu e concorda em cumprir estes Termos de Uso. Se não concordar com qualquer parte destes termos, não deve utilizar a plataforma.',
          ),

          _buildTermSection(
            '2. Descrição dos Serviços',
            'O BODA CONNECT é uma plataforma digital que conecta clientes a fornecedores de serviços para eventos (casamentos, festas, eventos corporativos, etc.). A plataforma facilita:\n\n'
                '• Pesquisa e descoberta de fornecedores\n'
                '• Visualização de portfólios e avaliações\n'
                '• Comunicação directa entre clientes e fornecedores\n'
                '• Gestão de reservas e pagamentos\n'
                '• Sistema de avaliações e feedback',
          ),

          _buildTermSection(
            '3. Contas de Utilizador',
            '3.1. Você deve fornecer informações precisas e completas ao criar uma conta.\n\n'
                '3.2. É responsável por manter a confidencialidade das suas credenciais.\n\n'
                '3.3. Deve ter pelo menos 18 anos para criar uma conta.\n\n'
                '3.4. Uma pessoa ou entidade pode ter apenas uma conta activa.',
          ),

          _buildTermSection(
            '4. Responsabilidades dos Fornecedores',
            '4.1. Fornecer informações verídicas sobre serviços e preços.\n\n'
                '4.2. Manter portfólio actualizado com trabalhos reais.\n\n'
                '4.3. Responder a pedidos de clientes em tempo razoável.\n\n'
                '4.4. Cumprir com reservas confirmadas ou cancelar com antecedência adequada.\n\n'
                '4.5. Manter comportamento profissional em todas as interacções.',
          ),

          _buildTermSection(
            '5. Responsabilidades dos Clientes',
            '5.1. Fornecer informações precisas sobre o evento.\n\n'
                '5.2. Comunicar claramente suas necessidades e expectativas.\n\n'
                '5.3. Respeitar políticas de cancelamento dos fornecedores.\n\n'
                '5.4. Efectuar pagamentos conforme acordado.\n\n'
                '5.5. Deixar avaliações honestas e construtivas.',
          ),

          _buildTermSection(
            '6. Pagamentos e Taxas',
            '6.1. A plataforma cobra uma taxa de serviço de 10% sobre cada transacção.\n\n'
                '6.2. Pagamentos são processados através de parceiros seguros.\n\n'
                '6.3. Reembolsos seguem políticas específicas de cada fornecedor.\n\n'
                '6.4. Disputas de pagamento devem ser relatadas dentro de 48 horas.',
          ),

          _buildTermSection(
            '7. Cancelamentos e Reembolsos',
            '7.1. Cancelamentos com mais de 30 dias: Reembolso total\n\n'
                '7.2. Cancelamentos 15-30 dias antes: Reembolso de 75%\n\n'
                '7.3. Cancelamentos 7-14 dias antes: Reembolso de 50%\n\n'
                '7.4. Cancelamentos com menos de 7 dias: Reembolso de 25%\n\n'
                '7.5. Fornecedores podem ter políticas próprias mais restritivas.',
          ),

          _buildTermSection(
            '8. Conteúdo do Utilizador',
            '8.1. Você mantém direitos sobre o conteúdo que publica.\n\n'
                '8.2. Concede ao BODA CONNECT licença para usar, exibir e distribuir seu conteúdo.\n\n'
                '8.3. É proibido publicar conteúdo:\n'
                '  • Ofensivo, difamatório ou discriminatório\n'
                '  • Que viole direitos de terceiros\n'
                '  • Falso ou enganoso\n'
                '  • Que contenha vírus ou código malicioso',
          ),

          _buildTermSection(
            '9. Conduta Proibida',
            'É estritamente proibido:\n\n'
                '• Usar a plataforma para fins ilegais\n'
                '• Criar múltiplas contas falsas\n'
                '• Manipular avaliações ou classificações\n'
                '• Assediar outros utilizadores\n'
                '• Tentar contornar sistemas de pagamento\n'
                '• Fazer engenharia reversa da plataforma\n'
                '• Usar bots ou automação não autorizada',
          ),

          _buildTermSection(
            '10. Propriedade Intelectual',
            'Todo o conteúdo da plataforma (logótipos, design, código) é propriedade do BODA CONNECT e está protegido por leis de direitos autorais. Uso não autorizado é proibido.',
          ),

          _buildTermSection(
            '11. Limitação de Responsabilidade',
            'O BODA CONNECT actua como intermediário. Não somos responsáveis por:\n\n'
                '• Qualidade dos serviços prestados por fornecedores\n'
                '• Disputas entre clientes e fornecedores\n'
                '• Danos resultantes do uso da plataforma\n'
                '• Perda de dados ou interrupções de serviço\n\n'
                'Use a plataforma por sua conta e risco.',
          ),

          _buildTermSection(
            '12. Rescisão',
            'Podemos suspender ou encerrar sua conta se:\n\n'
                '• Violar estes termos\n'
                '• Envolver-se em fraude\n'
                '• Receber múltiplas reclamações\n'
                '• Por razões de segurança\n\n'
                'Você pode encerrar sua conta a qualquer momento através das configurações.',
          ),

          _buildTermSection(
            '13. Modificações',
            'Reservamos o direito de modificar estes termos a qualquer momento. Notificaremos sobre mudanças significativas. Continuar usando a plataforma após mudanças constitui aceitação.',
          ),

          _buildTermSection(
            '14. Lei Aplicável',
            'Estes termos são regidos pelas leis da República de Angola. Disputas serão resolvidas nos tribunais de Luanda.',
          ),

          _buildTermSection(
            '15. Contacto',
            'Para questões sobre estes termos:\n\n'
                'Email: legal@bodaconnect.ao\n'
                'Telefone: +244 923 456 789\n'
                'Endereço: Luanda, Angola',
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPrivacyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Last Updated
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield, color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Os seus dados estão protegidos com encriptação AES-256',
                    style: AppTextStyles.caption.copyWith(color: AppColors.success),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Introduction
          Text(
            'Política de Privacidade',
            style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'A sua privacidade é importante para nós. Esta política explica como coletamos, usamos e protegemos seus dados pessoais.',
            style: AppTextStyles.body.copyWith(color: Colors.grey.shade700, height: 1.5),
          ),
          const SizedBox(height: 24),

          // Sections
          _buildTermSection(
            '1. Dados que Coletamos',
            '1.1. Informações de Conta:\n'
                '• Nome completo\n'
                '• Email e telefone\n'
                '• Data de nascimento\n'
                '• Localização\n\n'
                '1.2. Informações de Perfil (Fornecedores):\n'
                '• Nome do negócio\n'
                '• Portfólio (fotos/vídeos)\n'
                '• Descrição de serviços\n'
                '• Preços e disponibilidade\n\n'
                '1.3. Dados de Uso:\n'
                '• Histórico de navegação\n'
                '• Interacções na plataforma\n'
                '• Dispositivo e IP\n'
                '• Cookies e dados de sessão',
          ),

          _buildTermSection(
            '2. Como Usamos Seus Dados',
            '• Fornecer e melhorar nossos serviços\n'
                '• Facilitar conexões entre clientes e fornecedores\n'
                '• Processar pagamentos e reservas\n'
                '• Enviar notificações relevantes\n'
                '• Prevenir fraude e abuso\n'
                '• Análise e pesquisa (dados anonimizados)\n'
                '• Cumprir obrigações legais',
          ),

          _buildTermSection(
            '3. Compartilhamento de Dados',
            'Compartilhamos dados apenas:\n\n'
                '3.1. Com a outra parte na transacção (cliente ↔ fornecedor)\n\n'
                '3.2. Com processadores de pagamento (dados criptografados)\n\n'
                '3.3. Com autoridades legais (quando legalmente obrigados)\n\n'
                '3.4. NUNCA vendemos seus dados a terceiros',
          ),

          _buildTermSection(
            '4. Segurança dos Dados',
            '• Encriptação AES-256 para dados sensíveis\n'
                '• Comunicação via HTTPS/TLS\n'
                '• Servidores seguros com firewalls\n'
                '• Autenticação de dois factores\n'
                '• Auditorias regulares de segurança\n'
                '• Acesso restrito por equipa autorizada\n'
                '• Backups encriptados',
          ),

          _buildTermSection(
            '5. Seus Direitos (RGPD)',
            '5.1. Acesso: Ver todos os seus dados\n\n'
                '5.2. Rectificação: Corrigir dados incorrectos\n\n'
                '5.3. Eliminação: Apagar sua conta e dados\n\n'
                '5.4. Portabilidade: Descarregar seus dados\n\n'
                '5.5. Oposição: Optar por não receber comunicações\n\n'
                '5.6. Limitação: Restringir processamento',
          ),

          _buildTermSection(
            '6. Retenção de Dados',
            '• Contas activas: Enquanto usar o serviço\n\n'
                '• Após eliminação de conta: 30 dias (backup)\n\n'
                '• Dados financeiros: 7 anos (lei angolana)\n\n'
                '• Logs de segurança: 1 ano\n\n'
                '• Dados anonimizados: Indefinidamente para análise',
          ),

          _buildTermSection(
            '7. Cookies',
            'Usamos cookies para:\n\n'
                '• Manter sua sessão activa\n'
                '• Lembrar preferências\n'
                '• Análise de uso (Google Analytics)\n'
                '• Publicidade direcionada (opcional)\n\n'
                'Você pode gerir cookies nas configurações do navegador.',
          ),

          _buildTermSection(
            '8. Dados de Menores',
            'O BODA CONNECT é para maiores de 18 anos. Não coletamos conscientemente dados de menores. Se descobrirmos dados de menores, eliminaremos imediatamente.',
          ),

          _buildTermSection(
            '9. Transferências Internacionais',
            'Seus dados podem ser processados em servidores fora de Angola (Europa/EUA) com garantias adequadas de protecção conforme leis internacionais.',
          ),

          _buildTermSection(
            '10. Mudanças nesta Política',
            'Podemos actualizar esta política periodicamente. Notificaremos sobre mudanças significativas via email ou notificação no app.',
          ),

          _buildTermSection(
            '11. Contacto sobre Privacidade',
            'Para exercer seus direitos ou questões sobre privacidade:\n\n'
                'Email: privacy@bodaconnect.ao\n'
                'Data Protection Officer: dpo@bodaconnect.ao\n'
                'Telefone: +244 923 456 789',
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTermSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: AppTextStyles.body.copyWith(
            color: Colors.grey.shade700,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
