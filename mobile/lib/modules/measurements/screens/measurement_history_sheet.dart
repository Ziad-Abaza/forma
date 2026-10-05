import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../analytics/repositories/analytics_repository.dart';
import '../models/measurement_model.dart';
import '../repositories/measurements_repository.dart';

class MeasurementHistorySheet extends ConsumerStatefulWidget {
  final String initialTypeCode;

  const MeasurementHistorySheet({
    super.key,
    required this.initialTypeCode,
  });

  @override
  ConsumerState<MeasurementHistorySheet> createState() => _MeasurementHistorySheetState();
}

class _MeasurementHistorySheetState extends ConsumerState<MeasurementHistorySheet> {
  late String _selectedType;
  bool _isLoading = true;
  String? _errorMessage;
  List<ObservationModel> _observations = [];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialTypeCode;
    _loadObservations();
  }

  Future<void> _loadObservations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await ref.read(measurementsRepositoryProvider).getObservations(
            typeCode: _selectedType,
            // 'all' so voided/superseded rows actually render (the list
            // already styles them); backend default is 'active' only.
            status: 'all',
            limit: 100,
          );
      if (mounted) {
        setState(() {
          _observations = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showSupersedeDialog(ObservationModel obs, AppLocalizations l10n) {
    final valueController = TextEditingController(text: obs.canonicalValue.toStringAsFixed(1));
    final unitController = TextEditingController(text: obs.canonicalUnit);
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FormaTheme.surfaceCard,
        title: Text(l10n.supersede),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Superseding preserves historical record integrity by writing an immutable correction.',
                style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitController,
                decoration: InputDecoration(labelText: l10n.unit),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Correction Reason',
                  hintText: 'e.g. Typo in manual entry',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final newVal = double.tryParse(valueController.text.trim());
              final reason = reasonController.text.trim();
              if (newVal == null || reason.isEmpty) return;

              Navigator.of(ctx).pop();
              try {
                await ref.read(measurementsRepositoryProvider).supersedeObservation(
                      observationId: obs.id,
                      newValue: newVal,
                      newUnit: unitController.text.trim(),
                      correctionReason: reason,
                    );
                ref.invalidate(dashboardSnapshotProvider);
                await _loadObservations();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.measurementCorrected),
                      backgroundColor: FormaTheme.successGreen,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.correctionFailed(e.toString())),
                      backgroundColor: FormaTheme.criticalCrimson,
                    ),
                  );
                }
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _showVoidDialog(ObservationModel obs, AppLocalizations l10n) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FormaTheme.surfaceCard,
        title: Text(l10n.voidRecord),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Voiding removes this observation from active calculation without destroying audit provenance.',
              style: TextStyle(color: FormaTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason for voiding'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: FormaTheme.criticalCrimson),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                await ref.read(measurementsRepositoryProvider).voidObservation(
                      obs.id,
                      reasonController.text.trim(),
                    );
                ref.invalidate(dashboardSnapshotProvider);
                await _loadObservations();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.observationVoided),
                      backgroundColor: FormaTheme.successGreen,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.voidFailed(e.toString())),
                      backgroundColor: FormaTheme.criticalCrimson,
                    ),
                  );
                }
              }
            },
            child: Text(l10n.voidRecord, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showProvenanceDetails(ObservationModel obs, AppLocalizations l10n) async {
    showDialog(
      context: context,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: FormaTheme.primaryTeal),
      ),
    );

    // The provenance endpoint expects the provenance record id, NOT the
    // observation id.
    Map<String, dynamic>? prov;
    try {
      final provenanceId = obs.provenanceId;
      if (provenanceId != null) {
        prov = await ref.read(measurementsRepositoryProvider).getProvenance(provenanceId);
      }
    } catch (_) {
      prov = null;
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loading

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FormaTheme.surfaceCard,
        title: Text(l10n.provenanceTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.observationIdLabel(obs.id.substring(0, 8))),
            const SizedBox(height: 6),
            Text(l10n.epistemicClassLabel(((prov?['epistemic_class'] as String?) ?? obs.epistemicClass ?? 'unknown').toUpperCase())),
            const SizedBox(height: 6),
            Text(l10n.originTypeLabel((prov?['origin_type'] as String?) ?? 'unknown')),
            const SizedBox(height: 6),
            Text('Actor: ${prov?['actor'] ?? 'unknown'}'),
            const SizedBox(height: 6),
            Text('Recorded At: ${obs.recordedAt.toLocal().toString().substring(0, 16)}'),
            if (obs.isVoided) ...[
              const SizedBox(height: 6),
              const Text('Status: VOIDED', style: TextStyle(color: FormaTheme.criticalCrimson, fontWeight: FontWeight.bold)),
            ],
            if (obs.supersededBy != null) ...[
              const SizedBox(height: 6),
              Text('Superseded By: ${obs.supersededBy!.substring(0, 8)}...', style: const TextStyle(color: FormaTheme.alertCoral)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final numeralSystem = ref.watch(numeralSystemProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: FormaTheme.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.history, color: FormaTheme.primaryTeal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, _) {
                          final typesAsync = ref.watch(measurementTypesProvider);
                          // Always include the currently selected type so the
                          // dropdown stays valid even if the catalog fails.
                          final catalog = typesAsync.valueOrNull ?? const [];
                          final codes = {
                            _selectedType,
                            ...catalog.map((t) => t.code),
                          }.toList();
                          String humanize(String code) => code
                              .split('_')
                              .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
                              .join(' ');
                          return DropdownButton<String>(
                            value: _selectedType,
                            isExpanded: true,
                            underline: const SizedBox(),
                            dropdownColor: FormaTheme.surfaceElevated,
                            style: const TextStyle(
                              color: FormaTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            items: codes
                                .map((c) => DropdownMenuItem(value: c, child: Text(humanize(c))))
                                .toList(),
                            onChanged: (val) {
                              if (val != null && val != _selectedType) {
                                setState(() => _selectedType = val);
                                _loadObservations();
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(),
          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: FormaTheme.primaryTeal),
              ),
            )
          else if (_errorMessage != null)
            Expanded(
              child: Center(
                child: Text(_errorMessage!, style: const TextStyle(color: FormaTheme.criticalCrimson)),
              ),
            )
          else if (_observations.isEmpty)
            Expanded(
              child: Center(
                child: Text(l10n.emptyMeasurementsTitle, style: const TextStyle(color: FormaTheme.textSecondary)),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _observations.length,
                separatorBuilder: (_, _) => const Divider(color: FormaTheme.borderSubtle, height: 1),
                itemBuilder: (ctx, idx) {
                  final obs = _observations[idx];
                  final formattedDate = obs.recordedAt.toLocal().toString().substring(0, 16);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        Text(
                          '${formatNumeralString(obs.canonicalValue.toStringAsFixed(1), numeralSystem)} ${obs.canonicalUnit}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            decoration: obs.isVoided ? TextDecoration.lineThrough : null,
                            color: obs.isVoided ? FormaTheme.textTertiary : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (obs.isVoided)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: FormaTheme.criticalCrimson.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(l10n.voided, style: const TextStyle(color: FormaTheme.criticalCrimson, fontSize: 10)),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      formattedDate,
                      style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l10n.provenanceTitle,
                          icon: const Icon(Icons.info_outline, size: 18, color: FormaTheme.textSecondary),
                          onPressed: () => _showProvenanceDetails(obs, l10n),
                        ),
                        // Backend rejects supersede/void on non-'active'
                        // observations.
                        if (obs.isActive) ...[
                          IconButton(
                            tooltip: l10n.supersede,
                            icon: const Icon(Icons.edit_outlined, size: 18, color: FormaTheme.primaryTeal),
                            onPressed: () => _showSupersedeDialog(obs, l10n),
                          ),
                          IconButton(
                            tooltip: l10n.voidRecord,
                            icon: const Icon(Icons.delete_outline, size: 18, color: FormaTheme.alertCoral),
                            onPressed: () => _showVoidDialog(obs, l10n),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
