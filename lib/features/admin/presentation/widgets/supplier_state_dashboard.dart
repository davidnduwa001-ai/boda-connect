import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

/// Supplier State Dashboard (Read-Only)
/// - Uses ONLY inspectSupplierEligibility Cloud Function
/// - No Firestore reads or writes
/// - No client-side eligibility computation
class SupplierStateDashboard extends StatefulWidget {
  final String? initialSupplierId;

  const SupplierStateDashboard({
    super.key,
    this.initialSupplierId,
  });

  @override
  State<SupplierStateDashboard> createState() => _SupplierStateDashboardState();
}

class _SupplierStateDashboardState extends State<SupplierStateDashboard> {
  final _supplierIdController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  EligibilityInspectResult? _result;

  @override
  void initState() {
    super.initState();
    if (widget.initialSupplierId != null) {
      _supplierIdController.text = widget.initialSupplierId!;
    }
  }

  @override
  void dispose() {
    _supplierIdController.dispose();
    super.dispose();
  }

  Future<void> _inspectEligibility() async {
    final supplierId = _supplierIdController.text.trim();
    if (supplierId.isEmpty) {
      setState(() => _error = 'Supplier ID is required');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('inspectSupplierEligibility');
      final response = await callable.call<Map<String, dynamic>>({
        'supplierId': supplierId,
      });

      setState(() {
        _result = EligibilityInspectResult.fromMap(response.data);
        _isLoading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _error = e.message ?? 'Failed to inspect eligibility';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier State Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputCard(context),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(_error!),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              _buildDashboard(_result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _supplierIdController,
                decoration: const InputDecoration(
                  labelText: 'Supplier ID',
                  hintText: 'Enter supplier document ID',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _inspectEligibility,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('Inspect'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(EligibilityInspectResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(result),
        const SizedBox(height: 12),
        if (result.lifecycleState != null && result.lifecycleState != 'active')
          _buildLifecycleBanner(result.lifecycleState!),
        if (result.rawFields?.hasCompliance == false)
          _buildOnboardingHint(),
        const SizedBox(height: 12),
        _buildEligibilityCard(result),
        const SizedBox(height: 16),
        _buildFailureReasons(result),
        const SizedBox(height: 16),
        _buildChecksTable(result),
      ],
    );
  }

  Widget _buildHeader(EligibilityInspectResult result) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: Icon(Icons.store, color: Colors.blue.shade700),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.supplierName ?? 'Fornecedor',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                result.supplierId,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        _buildLifecycleBadge(result.lifecycleState),
      ],
    );
  }

  Widget _buildLifecycleBadge(String? lifecycleState) {
    final state = lifecycleState ?? 'unknown';
    final color = _lifecycleColor(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        state,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildLifecycleBanner(String state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _lifecycleExplanation(state),
              style: TextStyle(color: Colors.orange.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingHint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.assignment_outlined, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Complete onboarding para habilitar pagamentos e reservas.',
              style: TextStyle(color: Colors.blue.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEligibilityCard(EligibilityInspectResult result) {
    final eligible = result.eligible;
    final color = eligible ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200, width: 2),
      ),
      child: Row(
        children: [
          Icon(
            eligible ? Icons.check_circle : Icons.cancel,
            size: 40,
            color: color.shade700,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Can accept bookings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color.shade700,
                  ),
                ),
                Text(
                  eligible ? 'YES' : 'NO',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: color.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Policy: ${result.policyVersion ?? "unknown"}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailureReasons(EligibilityInspectResult result) {
    if (result.eligible) {
      return const SizedBox.shrink();
    }

    final reasons = result.failedReasons;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Failure Reasons',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (reasons.isEmpty)
          Text(
            'No failure reasons provided.',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          ...reasons.map((reason) {
            final info = _mapReason(reason);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(info.icon, color: info.color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: info.color,
                          ),
                        ),
                        Text(
                          info.description,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildChecksTable(EligibilityInspectResult result) {
    final checks = result.checks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Checks Table',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: Colors.grey.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildCheckRow(
                  'Compliance - KYC',
                  checks?.compliance?.kycStatus ?? 'unknown',
                  checks?.compliance?.kycPass,
                ),
                _buildCheckRow(
                  'Compliance - Payouts',
                  _boolLabel(checks?.compliance?.payoutsReady),
                  checks?.compliance?.payoutsPass,
                ),
                _buildCheckRow(
                  'Visibility - Listed',
                  _boolLabel(checks?.visibility?.isListed),
                  checks?.visibility?.pass,
                ),
                _buildCheckRow(
                  'Blocks - Global',
                  _boolLabel(!(checks?.blocks?.bookingsGlobally == true)),
                  checks?.blocks?.globalBlockPass,
                ),
                _buildCheckRow(
                  'Blocks - Date',
                  checks?.blocks?.dateBlocked == true ? 'Blocked' : 'Clear',
                  checks?.blocks?.dateBlockPass,
                ),
                _buildCheckRow(
                  'Blocks - Scheduled',
                  _scheduledBlocksLabel(checks?.blocks?.scheduledBlocks),
                  checks?.blocks?.pass,
                ),
                _buildCheckRow(
                  'Rate Limit - Exceeded',
                  _boolLabel(checks?.rateLimit?.exceeded),
                  checks?.rateLimit?.pass,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckRow(String label, String value, bool? pass) {
    final statusColor = pass == null
        ? Colors.grey.shade600
        : (pass ? Colors.green.shade700 : Colors.red.shade700);
    final statusIcon = pass == null
        ? Icons.help_outline
        : (pass ? Icons.check_circle : Icons.cancel);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 8),
          Icon(statusIcon, size: 18, color: statusColor),
        ],
      ),
    );
  }

  ReasonDisplay _mapReason(String reason) {
    if (reason.startsWith('lifecycle_state=')) {
      return ReasonDisplay(
        icon: Icons.info_outline,
        color: Colors.orange.shade700,
        title: 'Supplier not active',
        description: _lifecycleExplanation(_extractValue(reason)),
      );
    }
    if (reason.startsWith('compliance.payouts_ready=')) {
      return ReasonDisplay(
        icon: Icons.payments_outlined,
        color: Colors.red.shade700,
        title: 'Payouts not ready',
        description: 'Payouts must be configured before accepting bookings.',
      );
    }
    if (reason.startsWith('compliance.kyc_status=')) {
      return ReasonDisplay(
        icon: Icons.verified_user_outlined,
        color: Colors.red.shade700,
        title: 'KYC not verified',
        description: 'Identity verification is required for bookings.',
      );
    }
    if (reason.startsWith('visibility.is_listed=')) {
      return ReasonDisplay(
        icon: Icons.visibility_off_outlined,
        color: Colors.red.shade700,
        title: 'Supplier not listed',
        description: 'Supplier listing is disabled or hidden.',
      );
    }
    if (reason.startsWith('blocks.bookings_globally=')) {
      return ReasonDisplay(
        icon: Icons.pause_circle_outline,
        color: Colors.orange.shade700,
        title: 'Bookings paused',
        description: 'Supplier has paused bookings globally.',
      );
    }
    if (reason.startsWith('blocks.date_blocked=')) {
      return ReasonDisplay(
        icon: Icons.event_busy,
        color: Colors.red.shade700,
        title: 'Date blocked',
        description: 'Selected date is unavailable for this supplier.',
      );
    }
    if (reason.startsWith('rate_limit.exceeded=')) {
      return ReasonDisplay(
        icon: Icons.speed_outlined,
        color: Colors.red.shade700,
        title: 'Rate limit exceeded',
        description: 'Supplier is temporarily rate-limited.',
      );
    }
    if (reason.startsWith('POLICY_VIOLATION')) {
      return ReasonDisplay(
        icon: Icons.shield_outlined,
        color: Colors.red.shade700,
        title: 'Policy violation',
        description: reason,
      );
    }
    return ReasonDisplay(
      icon: Icons.error_outline,
      color: Colors.red.shade700,
      title: 'Unknown restriction',
      description: reason,
    );
  }

  String _extractValue(String reason) {
    final parts = reason.split('=');
    return parts.length > 1 ? parts.last.trim() : reason;
  }

  String _lifecycleExplanation(String state) {
    switch (state) {
      case 'draft':
        return 'Cadastro incompleto. Finalize o perfil para ativar reservas.';
      case 'pending_review':
        return 'Fornecedor aguardando aprovação administrativa.';
      case 'paused_by_supplier':
        return 'Reservas pausadas pelo fornecedor.';
      case 'suspended':
        return 'Fornecedor suspenso temporariamente.';
      case 'disabled':
        return 'Fornecedor desativado e indisponível.';
      case 'archived':
        return 'Fornecedor arquivado.';
      case 'active':
        return 'Fornecedor ativo.';
      default:
        return 'Estado do fornecedor indisponível.';
    }
  }

  Color _lifecycleColor(String state) {
    switch (state) {
      case 'active':
        return Colors.green.shade700;
      case 'pending_review':
        return Colors.orange.shade700;
      case 'paused_by_supplier':
        return Colors.grey.shade700;
      case 'suspended':
        return Colors.red.shade700;
      case 'disabled':
        return Colors.black87;
      case 'archived':
        return Colors.blueGrey.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  String _boolLabel(bool? value) {
    if (value == null) return 'unknown';
    return value ? 'true' : 'false';
  }

  String _scheduledBlocksLabel(List<String>? blocks) {
    if (blocks == null || blocks.isEmpty) return 'none';
    if (blocks.length == 1) return '1 date';
    return '${blocks.length} dates';
  }
}

class ReasonDisplay {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const ReasonDisplay({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}

class EligibilityInspectResult {
  final bool eligible;
  final String? lifecycleState;
  final List<String> failedReasons;
  final EligibilityChecks? checks;
  final RawFields? rawFields;
  final bool usedLegacyFallback;
  final String? policyVersion;
  final String evaluatedAt;
  final String supplierId;
  final String? supplierName;

  EligibilityInspectResult({
    required this.eligible,
    this.lifecycleState,
    required this.failedReasons,
    this.checks,
    this.rawFields,
    required this.usedLegacyFallback,
    required this.policyVersion,
    required this.evaluatedAt,
    required this.supplierId,
    this.supplierName,
  });

  factory EligibilityInspectResult.fromMap(Map<String, dynamic> map) {
    return EligibilityInspectResult(
      eligible: map['eligible'] as bool? ?? false,
      lifecycleState: map['lifecycle_state'] as String?,
      failedReasons: List<String>.from(map['failedReasons'] ?? []),
      checks: EligibilityChecks.fromMap(map['checks'] as Map<String, dynamic>?),
      rawFields: RawFields.fromMap(map['rawFields'] as Map<String, dynamic>?),
      usedLegacyFallback: map['usedLegacyFallback'] as bool? ?? false,
      policyVersion: map['policyVersion'] as String?,
      evaluatedAt: map['evaluatedAt'] as String? ?? '',
      supplierId: map['supplierId'] as String? ?? '',
      supplierName: map['supplierName'] as String?,
    );
  }
}

class EligibilityChecks {
  final LifecycleCheck? lifecycle;
  final ComplianceCheck? compliance;
  final VisibilityCheck? visibility;
  final BlocksCheck? blocks;
  final RateLimitCheck? rateLimit;

  EligibilityChecks({
    this.lifecycle,
    this.compliance,
    this.visibility,
    this.blocks,
    this.rateLimit,
  });

  factory EligibilityChecks.fromMap(Map<String, dynamic>? map) {
    if (map == null) return EligibilityChecks();
    return EligibilityChecks(
      lifecycle: LifecycleCheck.fromMap(map['lifecycle'] as Map<String, dynamic>?),
      compliance: ComplianceCheck.fromMap(map['compliance'] as Map<String, dynamic>?),
      visibility: VisibilityCheck.fromMap(map['visibility'] as Map<String, dynamic>?),
      blocks: BlocksCheck.fromMap(map['blocks'] as Map<String, dynamic>?),
      rateLimit: RateLimitCheck.fromMap(map['rate_limit'] as Map<String, dynamic>?),
    );
  }
}

class RawFields {
  final bool? hasCompliance;

  RawFields({this.hasCompliance});

  factory RawFields.fromMap(Map<String, dynamic>? map) {
    if (map == null) return RawFields();
    return RawFields(
      hasCompliance: map['has_compliance'] as bool?,
    );
  }
}

class LifecycleCheck {
  final bool? pass;
  final String? state;

  LifecycleCheck({this.pass, this.state});

  factory LifecycleCheck.fromMap(Map<String, dynamic>? map) {
    if (map == null) return LifecycleCheck();
    return LifecycleCheck(
      pass: map['pass'] as bool?,
      state: map['state'] as String?,
    );
  }
}

class ComplianceCheck {
  final bool? pass;
  final String? kycStatus;
  final bool? payoutsReady;
  final bool? kycPass;
  final bool? payoutsPass;

  ComplianceCheck({
    this.pass,
    this.kycStatus,
    this.payoutsReady,
    this.kycPass,
    this.payoutsPass,
  });

  factory ComplianceCheck.fromMap(Map<String, dynamic>? map) {
    if (map == null) return ComplianceCheck();
    return ComplianceCheck(
      pass: map['pass'] as bool?,
      kycStatus: map['kyc_status'] as String?,
      payoutsReady: map['payouts_ready'] as bool?,
      kycPass: map['kyc_pass'] as bool?,
      payoutsPass: map['payouts_pass'] as bool?,
    );
  }
}

class VisibilityCheck {
  final bool? pass;
  final bool? isListed;

  VisibilityCheck({this.pass, this.isListed});

  factory VisibilityCheck.fromMap(Map<String, dynamic>? map) {
    if (map == null) return VisibilityCheck();
    return VisibilityCheck(
      pass: map['pass'] as bool?,
      isListed: map['is_listed'] as bool?,
    );
  }
}

class BlocksCheck {
  final bool? pass;
  final bool? bookingsGlobally;
  final bool? globalBlockPass;
  final bool? dateBlocked;
  final bool? dateBlockPass;
  final List<String> scheduledBlocks;

  BlocksCheck({
    this.pass,
    this.bookingsGlobally,
    this.globalBlockPass,
    this.dateBlocked,
    this.dateBlockPass,
    required this.scheduledBlocks,
  });

  factory BlocksCheck.fromMap(Map<String, dynamic>? map) {
    if (map == null) return BlocksCheck(scheduledBlocks: const []);
    return BlocksCheck(
      pass: map['pass'] as bool?,
      bookingsGlobally: map['bookings_globally'] as bool?,
      globalBlockPass: map['global_block_pass'] as bool?,
      dateBlocked: map['date_blocked'] as bool?,
      dateBlockPass: map['date_block_pass'] as bool?,
      scheduledBlocks: List<String>.from(map['scheduled_blocks'] ?? []),
    );
  }
}

class RateLimitCheck {
  final bool? pass;
  final bool? exceeded;

  RateLimitCheck({this.pass, this.exceeded});

  factory RateLimitCheck.fromMap(Map<String, dynamic>? map) {
    if (map == null) return RateLimitCheck();
    return RateLimitCheck(
      pass: map['pass'] as bool?,
      exceeded: map['exceeded'] as bool?,
    );
  }
}
