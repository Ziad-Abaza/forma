import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';

class ExtractedFieldItem {
  final String typeCode;
  final String rawLabel;
  final double extractedValue;
  double? userEditedValue;
  final String unit;
  double canonicalValue;
  final String canonicalUnit;
  final double confidenceScore;
  final List<String> qualityFlags;
  final String epistemicClass;
  bool isApproved;
  final bool requiresFieldAttention;

  ExtractedFieldItem({
    required this.typeCode,
    required this.rawLabel,
    required this.extractedValue,
    this.userEditedValue,
    required this.unit,
    required this.canonicalValue,
    required this.canonicalUnit,
    required this.confidenceScore,
    this.qualityFlags = const [],
    required this.epistemicClass,
    this.isApproved = true,
    this.requiresFieldAttention = false,
  });

  double get displayValue => userEditedValue ?? extractedValue;

  ExtractedFieldItem copyWith({
    double? userEditedValue,
    double? canonicalValue,
    bool? isApproved,
  }) {
    return ExtractedFieldItem(
      typeCode: typeCode,
      rawLabel: rawLabel,
      extractedValue: extractedValue,
      userEditedValue: userEditedValue ?? this.userEditedValue,
      unit: unit,
      canonicalValue: canonicalValue ?? this.canonicalValue,
      canonicalUnit: canonicalUnit,
      confidenceScore: confidenceScore,
      qualityFlags: qualityFlags,
      epistemicClass: epistemicClass,
      isApproved: isApproved ?? this.isApproved,
      requiresFieldAttention: requiresFieldAttention,
    );
  }
}

class DraftReviewState {
  final String draftId;
  final String imageKind;
  final String status;
  final double overallConfidence;
  final List<ExtractedFieldItem> fields;
  final int unrecognizedCount;
  final bool deleteSourceImage;
  final bool isSubmitting;
  final String? committedReceipt;
  final bool isDiscarded;

  const DraftReviewState({
    required this.draftId,
    required this.imageKind,
    this.status = 'draft',
    required this.overallConfidence,
    required this.fields,
    this.unrecognizedCount = 0,
    this.deleteSourceImage = true,
    this.isSubmitting = false,
    this.committedReceipt,
    this.isDiscarded = false,
  });

  bool get hasAttentionFields => fields.any((f) => f.requiresFieldAttention);
  int get approvedCount => fields.where((f) => f.isApproved).length;

  DraftReviewState copyWith({
    String? status,
    List<ExtractedFieldItem>? fields,
    bool? deleteSourceImage,
    bool? isSubmitting,
    String? committedReceipt,
    bool? isDiscarded,
  }) {
    return DraftReviewState(
      draftId: draftId,
      imageKind: imageKind,
      status: status ?? this.status,
      overallConfidence: overallConfidence,
      fields: fields ?? this.fields,
      unrecognizedCount: unrecognizedCount,
      deleteSourceImage: deleteSourceImage ?? this.deleteSourceImage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      committedReceipt: committedReceipt ?? this.committedReceipt,
      isDiscarded: isDiscarded ?? this.isDiscarded,
    );
  }
}

class DraftReviewNotifier extends StateNotifier<DraftReviewState> {
  DraftReviewNotifier(super.initial);

  void toggleApproval(int index) {
    if (index < 0 || index >= state.fields.length) return;
    final updatedList = List<ExtractedFieldItem>.from(state.fields);
    updatedList[index] = updatedList[index].copyWith(
      isApproved: !updatedList[index].isApproved,
    );
    state = state.copyWith(fields: updatedList);
  }

  void editFieldValue(int index, double newValue) {
    if (index < 0 || index >= state.fields.length) return;
    final updatedList = List<ExtractedFieldItem>.from(state.fields);
    updatedList[index] = updatedList[index].copyWith(
      userEditedValue: newValue,
      canonicalValue: newValue,
      isApproved: true,
    );
    state = state.copyWith(fields: updatedList, status: 'reviewed');
  }

  void setDeleteSourceImage(bool value) {
    state = state.copyWith(deleteSourceImage: value);
  }

  Future<void> commitDraft({Future<String> Function(DraftReviewState)? onCommit}) async {
    if (state.approvedCount == 0) return;
    state = state.copyWith(isSubmitting: true);
    try {
      if (onCommit != null) {
        final receipt = await onCommit(state);
        state = state.copyWith(
          isSubmitting: false,
          status: 'committed',
          committedReceipt: receipt,
        );
      } else {
        state = state.copyWith(
          isSubmitting: false,
          status: 'committed',
          committedReceipt: 'rcpt_multimodal_${state.draftId.substring(0, 8)}',
        );
      }
    } catch (_) {
      state = state.copyWith(isSubmitting: false);
    }
  }

  void discardDraft() {
    state = state.copyWith(status: 'discarded', isDiscarded: true);
  }
}

final multimodalDraftProvider = StateNotifierProvider.family<DraftReviewNotifier, DraftReviewState, DraftReviewState>(
  (ref, initial) => DraftReviewNotifier(initial),
);

class MultimodalReviewScreen extends ConsumerWidget {
  final DraftReviewState initialDraft;
  final Future<String> Function(DraftReviewState)? onCommit;
  final VoidCallback? onDiscard;

  const MultimodalReviewScreen({
    super.key,
    required this.initialDraft,
    this.onCommit,
    this.onDiscard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(multimodalDraftProvider(initialDraft));
    final notifier = ref.read(multimodalDraftProvider(initialDraft).notifier);
    final l10n = AppLocalizations.of(context)!;
    final numeralSystem = ref.watch(numeralSystemProvider);

    if (state.isDiscarded) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.multimodalReviewTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_outline, size: 64, color: FormaTheme.textSecondary),
              const SizedBox(height: 16),
              Text(l10n.discardDraft, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (onDiscard != null) onDiscard!();
                  Navigator.of(context).maybePop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.committedReceipt != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.multimodalReviewTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, size: 64, color: FormaTheme.successGreen),
                const SizedBox(height: 16),
                Text(
                  l10n.actionConfirmed,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: FormaTheme.successGreen,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.actionReceiptId(state.committedReceipt!),
                  style: const TextStyle(fontFamily: 'monospace', color: FormaTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.multimodalReviewTitle),
        actions: [
          TextButton(
            onPressed: () {
              notifier.discardDraft();
              if (onDiscard != null) onDiscard!();
            },
            child: Text(
              l10n.discardDraft,
              style: const TextStyle(color: FormaTheme.alertCoral),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Confidence & Image Kind Overview
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: FormaTheme.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FormaTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.photo_camera_back_outlined, color: FormaTheme.primaryTeal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.imageKind.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          l10n.fieldConfidence((state.overallConfidence * 100).round()),
                          style: const TextStyle(fontSize: 12, color: FormaTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  _buildEpistemicBadge(state.fields.isNotEmpty ? state.fields.first.epistemicClass : 'measured', l10n),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Adaptive Review Intensity Banner
            if (state.hasAttentionFields) ...[
              Container(
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: FormaTheme.warningAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FormaTheme.warningAmber),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: FormaTheme.warningAmber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.adaptiveAttentionWarning,
                        style: const TextStyle(
                          color: FormaTheme.warningAmber,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Fields list
            Text(
              l10n.extractedMetricsTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            ...state.fields.asMap().entries.map((entry) {
              final idx = entry.key;
              final field = entry.value;
              return _buildFieldCard(context, ref, idx, field, notifier, l10n, numeralSystem);
            }),

            const SizedBox(height: 16),

            // Unrecognized fields notice if any
            if (state.unrecognizedCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: FormaTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: FormaTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      '${l10n.unrecognizedFields} (${state.unrecognizedCount})',
                      style: const TextStyle(fontSize: 12, color: FormaTheme.textSecondary),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Privacy & Retention Policy Toggle
            Card(
              margin: EdgeInsets.zero,
              color: FormaTheme.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: FormaTheme.borderSubtle),
              ),
              child: SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
                secondary: const Icon(Icons.privacy_tip_outlined, color: FormaTheme.primaryTeal),
                title: Text(
                  l10n.deleteSourceImage,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                value: state.deleteSourceImage,
                onChanged: (val) => notifier.setDeleteSourceImage(val),
              ),
            ),

            const SizedBox(height: 24),

            // Commit Button
            ElevatedButton.icon(
              key: const Key('commit_to_health_record_button'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: FormaTheme.primaryTeal,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: state.isSubmitting || state.approvedCount == 0
                  ? null
                  : () => notifier.commitDraft(onCommit: onCommit),
              icon: state.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.check),
              label: Text(
                l10n.commitToHealthRecord,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (state.approvedCount == 0) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  l10n.noFieldsToCommit,
                  style: const TextStyle(color: FormaTheme.alertCoral, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFieldCard(
    BuildContext context,
    WidgetRef ref,
    int index,
    ExtractedFieldItem field,
    DraftReviewNotifier notifier,
    AppLocalizations l10n,
    String numeralSystem,
  ) {
    final hasAttention = field.requiresFieldAttention;
    final isEdited = field.userEditedValue != null;
    final valStr = formatNumeralString(field.displayValue.toString(), numeralSystem);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasAttention
              ? FormaTheme.warningAmber
              : field.isApproved
                  ? FormaTheme.borderSubtle
                  : FormaTheme.borderSubtle.withValues(alpha: 0.4),
          width: hasAttention ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  key: Key('checkbox_field_$index'),
                  value: field.isApproved,
                  activeColor: FormaTheme.primaryTeal,
                  onChanged: (_) => notifier.toggleApproval(index),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.rawLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        '${field.typeCode} • ${field.canonicalUnit}',
                        style: const TextStyle(fontSize: 11, color: FormaTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$valStr ${field.unit}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isEdited ? FormaTheme.primaryTeal : FormaTheme.textPrimary,
                          ),
                        ),
                        IconButton(
                          key: Key('edit_field_$index'),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _showEditDialog(context, index, field, notifier, l10n),
                          tooltip: l10n.editField,
                        ),
                      ],
                    ),
                    if (isEdited)
                      const Text(
                        'Edited',
                        style: TextStyle(fontSize: 10, color: FormaTheme.primaryTeal, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ],
            ),
            if (hasAttention || field.qualityFlags.isNotEmpty) ...[
              const Divider(height: 12),
              Row(
                children: [
                  if (hasAttention)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: FormaTheme.warningAmber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.fieldRequiresAttention,
                        style: const TextStyle(
                          color: FormaTheme.warningAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ...field.qualityFlags.map((flag) => Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: Chip(
                          labelPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          label: Text(flag, style: const TextStyle(fontSize: 10)),
                        ),
                      )),
                  const Spacer(),
                  Text(
                    l10n.fieldConfidence((field.confidenceScore * 100).round()),
                    style: const TextStyle(fontSize: 11, color: FormaTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEpistemicBadge(String epistemicClass, AppLocalizations l10n) {
    final isMeasured = epistemicClass == 'measured';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMeasured
            ? FormaTheme.badgeMeasured.withValues(alpha: 0.15)
            : FormaTheme.badgeEstimated.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isMeasured ? FormaTheme.badgeMeasured : FormaTheme.badgeEstimated,
        ),
      ),
      child: Text(
        isMeasured ? l10n.evidenceBadgeRetrieved : l10n.evidenceBadgeEstimated,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isMeasured ? FormaTheme.badgeMeasured : FormaTheme.badgeEstimated,
        ),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    int index,
    ExtractedFieldItem field,
    DraftReviewNotifier notifier,
    AppLocalizations l10n,
  ) {
    final controller = TextEditingController(text: field.displayValue.toString());
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('${l10n.editField}: ${field.rawLabel}'),
          content: TextField(
            key: const Key('edit_field_input'),
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              suffixText: field.unit,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('save_field_button'),
              onPressed: () {
                final val = double.tryParse(controller.text.trim());
                if (val != null) {
                  notifier.editFieldValue(index, val);
                }
                Navigator.of(ctx).pop();
              },
              child: Text(l10n.saveChanges),
            ),
          ],
        );
      },
    );
  }
}
