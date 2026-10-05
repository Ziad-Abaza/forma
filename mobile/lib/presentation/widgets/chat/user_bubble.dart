import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/theme.dart';
import '../../../../modules/assistant/models/assistant_models.dart';

class UserBubble extends StatelessWidget {
  final AssistantChatMessage message;

  const UserBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isRtl = intl.Bidi.detectRtlDirectionality(message.content);
    final textDirection = isRtl ? TextDirection.rtl : TextDirection.ltr;

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
          margin: const EdgeInsetsDirectional.only(
            start: 48,
            end: 16,
            top: 6,
            bottom: 6,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: FormaTheme.surfaceCard,
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(FormaTheme.radiusBubble),
              topEnd: const Radius.circular(FormaTheme.radiusBubble),
              bottomStart: const Radius.circular(FormaTheme.radiusBubble),
              bottomEnd: const Radius.circular(FormaTheme.radiusBubbleTail),
            ).resolve(Directionality.of(context)),
            border: Border.all(
              color: FormaTheme.borderSubtle,
              width: 1,
            ),
          ),
          child: Directionality(
            textDirection: textDirection,
            child: SelectionArea(
              child: Text(
                message.content,
                style: const TextStyle(
                  color: FormaTheme.textPrimary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
