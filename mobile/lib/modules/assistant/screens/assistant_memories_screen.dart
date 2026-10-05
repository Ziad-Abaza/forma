import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../models/assistant_models.dart';
import '../repositories/assistant_repository.dart';

/// Categories accepted by the backend SaveMemorySchema
/// (backend/src/modules/assistant/contracts.ts).
const List<String> _memoryCategories = [
  'preference',
  'fact',
  'routine',
  'constraint',
];

/// Lists the assistant's durable memories grouped by category, with
/// explicit add/delete. Deletion is a server-side soft delete.
class AssistantMemoriesScreen extends ConsumerStatefulWidget {
  const AssistantMemoriesScreen({super.key});

  @override
  ConsumerState<AssistantMemoriesScreen> createState() =>
      _AssistantMemoriesScreenState();
}

class _AssistantMemoriesScreenState
    extends ConsumerState<AssistantMemoriesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<AssistantMemory> _memories = [];

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list =
          await ref.read(assistantRepositoryProvider).listMemories();
      if (mounted) {
        setState(() {
          _memories = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = formatApiErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  String _categoryLabel(String category, AppLocalizations l10n) {
    switch (category) {
      case 'preference':
        return l10n.memoryCategoryPreference;
      case 'routine':
        return l10n.memoryCategoryRoutine;
      case 'constraint':
        return l10n.memoryCategoryConstraint;
      case 'fact':
      default:
        return l10n.memoryCategoryFact;
    }
  }

  Future<void> _confirmDelete(
      AssistantMemory memory, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FormaTheme.surfaceCard,
        title: Text(l10n.delete),
        content: Text(l10n.deleteMemoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: FormaTheme.criticalCrimson),
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                Text(l10n.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final success =
          await ref.read(assistantRepositoryProvider).deleteMemory(memory.id);
      if (!mounted) return;
      if (success) {
        setState(() {
          _memories.removeWhere((m) => m.id == memory.id);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.deleteFailed),
            backgroundColor: FormaTheme.criticalCrimson,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.deleteFailed),
            backgroundColor: FormaTheme.criticalCrimson,
          ),
        );
      }
    }
  }

  void _showAddMemoryDialog(AppLocalizations l10n) {
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    String selectedCategory = _memoryCategories.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: FormaTheme.surfaceCard,
          title: Text(l10n.addMemory),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(labelText: l10n.memoryCategory),
                  dropdownColor: FormaTheme.surfaceElevated,
                  items: _memoryCategories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(_categoryLabel(c, l10n)),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedCategory = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyController,
                  decoration: InputDecoration(
                    labelText: l10n.memoryKey,
                    hintText: l10n.memoryKeyHint,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueController,
                  decoration: InputDecoration(
                    labelText: l10n.value,
                    hintText: l10n.memoryValueHint,
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
                final key = keyController.text.trim();
                final value = valueController.text.trim();
                if (key.isEmpty || value.isEmpty) return;

                try {
                  final memory = await ref
                      .read(assistantRepositoryProvider)
                      .createMemory(
                        category: selectedCategory,
                        key: key,
                        value: value,
                      );
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  setState(() {
                    // Upsert semantics server-side: replace any existing row
                    // with the same category+key, then append.
                    _memories.removeWhere((m) =>
                        m.category == memory.category && m.key == memory.key);
                    _memories.add(memory);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.memorySaved),
                      backgroundColor: FormaTheme.successGreen,
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.memorySaveFailed(formatApiErrorMessage(e)),
                      ),
                      backgroundColor: FormaTheme.criticalCrimson,
                    ),
                  );
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.memoriesTitle),
        actions: [
          IconButton(
            tooltip: l10n.addMemory,
            icon: const Icon(Icons.add, color: FormaTheme.primaryTeal),
            onPressed: () => _showAddMemoryDialog(l10n),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(color: FormaTheme.primaryTeal),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                                color: FormaTheme.criticalCrimson),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _loadMemories,
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  )
                : _memories.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.psychology_outlined,
                                  size: 48, color: FormaTheme.textTertiary),
                              const SizedBox(height: 12),
                              Text(
                                l10n.memoriesEmpty,
                                style: const TextStyle(
                                    color: FormaTheme.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () => _showAddMemoryDialog(l10n),
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(l10n.addMemory),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildGroupedList(l10n),
      ),
    );
  }

  Widget _buildGroupedList(AppLocalizations l10n) {
    // Group memories by category, in a stable display order; unknown
    // categories sort last.
    final grouped = <String, List<AssistantMemory>>{};
    for (final m in _memories) {
      grouped.putIfAbsent(m.category, () => []).add(m);
    }
    final orderedCategories = [
      ..._memoryCategories.where(grouped.containsKey),
      ...grouped.keys.where((c) => !_memoryCategories.contains(c)),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: orderedCategories.length,
      itemBuilder: (context, sectionIndex) {
        final category = orderedCategories[sectionIndex];
        final items = grouped[category]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _categoryLabel(category, l10n).toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: FormaTheme.primaryTeal,
                ),
              ),
            ),
            ...items.map((memory) {
              final date = memory.createdAt;
              return ListTile(
                title: Text(
                  memory.key,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FormaTheme.textPrimary,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memory.value,
                      style: const TextStyle(
                        color: FormaTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (date != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          date.toLocal().toString().substring(0, 16),
                          style: const TextStyle(
                            color: FormaTheme.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: IconButton(
                  tooltip: l10n.delete,
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: FormaTheme.alertCoral),
                  onPressed: () => _confirmDelete(memory, l10n),
                ),
              );
            }),
            const Divider(color: FormaTheme.borderSubtle, height: 1),
          ],
        );
      },
    );
  }
}
