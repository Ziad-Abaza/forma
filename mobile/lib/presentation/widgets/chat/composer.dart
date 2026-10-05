import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/theme.dart';
import '../../../../l10n/app_localizations.dart';
import 'glass_surface.dart';

class Composer extends StatefulWidget {
  final bool isStreaming;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;
  final List<String> suggestions;
  final ValueChanged<String>? onSuggestionTap;

  const Composer({
    super.key,
    required this.isStreaming,
    required this.onSend,
    required this.onStop,
    this.suggestions = const [],
    this.onSuggestionTap,
  });

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _charCount = 0;
  TextDirection _textDirection = TextDirection.ltr;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    _textController.removeListener(_handleTextChange);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    final text = _textController.text;
    setState(() {
      _charCount = text.length;
      if (text.isNotEmpty) {
        final isRtl = intl.Bidi.detectRtlDirectionality(text);
        _textDirection = isRtl ? TextDirection.rtl : TextDirection.ltr;
      }
    });
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty || text.length > 2000) return;
    widget.onSend(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isTooLong = _charCount > 2000;
    final showCounter = _charCount >= 1600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.suggestions.isNotEmpty && _charCount == 0) ...[
          Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final suggestion = widget.suggestions[index];
                return ActionChip(
                  label: Text(
                    suggestion,
                    style: const TextStyle(
                      color: FormaTheme.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: FormaTheme.surfaceCard,
                  side: const BorderSide(color: FormaTheme.borderSubtle),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: () {
                    widget.onSuggestionTap?.call(suggestion);
                  },
                );
              },
            ),
          ),
        ],
        GlassSurface(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(FormaTheme.radiusCard)),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showCounter) ...[
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '$_charCount / 2000',
                        style: TextStyle(
                          color: isTooLong ? FormaTheme.alertCoral : FormaTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Directionality(
                        textDirection: _textDirection,
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 5,
                          style: const TextStyle(
                            color: FormaTheme.textPrimary,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            hintText: l10n.messageInputPlaceholder,
                            hintStyle: const TextStyle(color: FormaTheme.textSecondary),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            fillColor: FormaTheme.surfaceElevated,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.isStreaming)
                      IconButton(
                        onPressed: widget.onStop,
                        icon: const Icon(Icons.stop_circle_rounded, color: FormaTheme.alertCoral, size: 32),
                        tooltip: l10n.stopGeneration,
                      )
                    else
                      IconButton(
                        onPressed: (_charCount > 0 && !isTooLong) ? _submit : null,
                        icon: Icon(
                          Icons.arrow_circle_up_rounded,
                          color: (_charCount > 0 && !isTooLong)
                              ? FormaTheme.primaryTeal
                              : FormaTheme.textSecondary.withValues(alpha: 0.4),
                          size: 34,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
