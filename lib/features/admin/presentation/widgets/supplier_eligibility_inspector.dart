import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Admin Supplier Eligibility Inspector - READ-ONLY
///
/// Displays detailed eligibility breakdown for debugging purposes.
/// Does NOT allow any state modifications.
class SupplierEligibilityInspector extends StatefulWidget {
  final String? initialSupplierId;

  const SupplierEligibilityInspector({
    super.key,
    this.initialSupplierId,
  });

  @override
  State<SupplierEligibilityInspector> createState() =>
      _SupplierEligibilityInspectorState();
}

class _SupplierEligibilityInspectorState
    extends State<SupplierEligibilityInspector> {
  final _supplierIdController = TextEditingController();
  final _dateController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  EligibilityInspectResult? _result;

  @override
  void initState() {
    super.initState();
    if (widget.initialSupplierId != null) {
      _supplierIdController.text = widget.initialSupplierId!;
    }
    // Default to today
    _dateController.text = _formatDate(DateTime.now());
  }

  @override
  void dispose() {
    _supplierIdController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
        'eventDate': _dateController.text.isNotEmpty ? _dateController.text : null,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.search, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Supplier Eligibility Inspector',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'READ-ONLY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Input fields
            Row(
              children: [
                Expanded(
                  flex: 2,
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
                Expanded(
                  child: TextField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Event Date',
                      hintText: 'YYYY-MM-DD',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _inspectEligibility,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.visibility),
                  label: const Text('Inspect'),
                ),
              ],
            ),

            // Error display
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
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
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Results display
            if (_result != null) ...[
              const SizedBox(height: 24),
              _buildResultsDisplay(_result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsDisplay(EligibilityInspectResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall status
        _buildOverallStatus(result),
        const SizedBox(height: 16),

        // Lifecycle state
        _buildLifecycleState(result),
        const SizedBox(height: 16),

        // Checks grid
        _buildChecksGrid(result),
        const SizedBox(height: 16),

        // Blocking reasons
        if (result.blockingReasons.isNotEmpty) ...[
          _buildBlockingReasons(result),
          const SizedBox(height: 16),
        ],

        // Raw data info
        _buildRawDataInfo(result),

        // Inspection timestamp
        const SizedBox(height: 12),
        Text(
          'Inspected at: ${result.inspectedAt}',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildOverallStatus(EligibilityInspectResult result) {
    final isEligible = result.eligible;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEligible ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEligible ? Colors.green.shade300 : Colors.red.shade300,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isEligible ? Icons.check_circle : Icons.cancel,
            size: 48,
            color: isEligible ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEligible ? 'ELIGIBLE' : 'NOT ELIGIBLE',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isEligible ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
                Text(
                  isEligible
                      ? 'Supplier can accept bookings'
                      : '${result.blockingReasons.length} blocking reason(s)',
                  style: TextStyle(
                    color: isEligible ? Colors.green.shade600 : Colors.red.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLifecycleState(EligibilityInspectResult result) {
    return Row(
      children: [
        const Text(
          'Lifecycle State:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: result.lifecycleState == 'active'
                ? Colors.green.shade100
                : Colors.orange.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            result.lifecycleState ?? 'unknown',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: result.lifecycleState == 'active'
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChecksGrid(EligibilityInspectResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Eligibility Checks',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildCheckChip('Lifecycle', result.checks['lifecycle']),
            _buildCheckChip('Payouts', result.checks['compliance_payouts']),
            _buildCheckChip('KYC', result.checks['compliance_kyc']),
            _buildCheckChip('Visibility', result.checks['visibility']),
            _buildCheckChip('Global Block', result.checks['blocks_global']),
            _buildCheckChip('Date Block', result.checks['blocks_date']),
            _buildCheckChip('Rate Limit', result.checks['rate_limit']),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckChip(String label, CheckResult? check) {
    final isPassing = check?.status == 'pass';
    final isUnknown = check?.status == 'unknown';

    Color bgColor;
    Color textColor;
    IconData icon;

    if (isUnknown) {
      bgColor = Colors.grey.shade200;
      textColor = Colors.grey.shade700;
      icon = Icons.help_outline;
    } else if (isPassing) {
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade700;
      icon = Icons.check_circle;
    } else {
      bgColor = Colors.red.shade100;
      textColor = Colors.red.shade700;
      icon = Icons.cancel;
    }

    return Tooltip(
      message: check?.detail ?? 'No details',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockingReasons(EligibilityInspectResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Blocking Reasons',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: result.blockingReasons
                .map((reason) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.block, size: 16, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reason,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRawDataInfo(EligibilityInspectResult result) {
    final rawData = result.rawData;
    return ExpansionTile(
      title: const Text(
        'Raw Data Info',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      tilePadding: EdgeInsets.zero,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRawDataRow('has_lifecycle_state', rawData['has_lifecycle_state']),
              _buildRawDataRow('has_compliance', rawData['has_compliance']),
              _buildRawDataRow('has_visibility', rawData['has_visibility']),
              _buildRawDataRow('has_blocks', rawData['has_blocks']),
              _buildRawDataRow('has_rate_limit', rawData['has_rate_limit']),
              const Divider(),
              _buildRawDataRow(
                'used_legacy_fallback',
                rawData['used_legacy_fallback'],
                highlight: rawData['used_legacy_fallback'] == true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRawDataRow(String label, dynamic value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              color: highlight ? Colors.orange.shade700 : null,
            ),
          ),
          Text(
            value?.toString() ?? 'null',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: value == true
                  ? Colors.green.shade700
                  : (value == false ? Colors.red.shade700 : null),
            ),
          ),
        ],
      ),
    );
  }
}

/// Model class for eligibility inspection result
class EligibilityInspectResult {
  final bool eligible;
  final String? lifecycleState;
  final List<String> blockingReasons;
  final Map<String, CheckResult> checks;
  final Map<String, dynamic> rawData;
  final String inspectedAt;

  EligibilityInspectResult({
    required this.eligible,
    this.lifecycleState,
    required this.blockingReasons,
    required this.checks,
    required this.rawData,
    required this.inspectedAt,
  });

  factory EligibilityInspectResult.fromMap(Map<String, dynamic> map) {
    final checksMap = map['checks'] as Map<String, dynamic>? ?? {};
    final parsedChecks = <String, CheckResult>{};
    checksMap.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        parsedChecks[key] = CheckResult.fromMap(value);
      }
    });

    return EligibilityInspectResult(
      eligible: map['eligible'] as bool? ?? false,
      lifecycleState: map['lifecycle_state'] as String?,
      blockingReasons: List<String>.from(map['blocking_reasons'] ?? []),
      checks: parsedChecks,
      rawData: Map<String, dynamic>.from(map['raw_data'] ?? {}),
      inspectedAt: map['inspected_at'] as String? ?? '',
    );
  }
}

/// Model class for individual check result
class CheckResult {
  final String status;
  final String? detail;

  CheckResult({required this.status, this.detail});

  factory CheckResult.fromMap(Map<String, dynamic> map) {
    return CheckResult(
      status: map['status'] as String? ?? 'unknown',
      detail: map['detail'] as String?,
    );
  }
}
