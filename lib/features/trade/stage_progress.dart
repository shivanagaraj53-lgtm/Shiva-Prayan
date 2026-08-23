import 'package:flutter/material.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../design/palette.dart';
import '../../design/tokens.dart';

/// The three parts of the method, and which of them this entry has reached.
///
/// A trading journal is easy to half-fill: the numbers go in because they are
/// easy, and the reasoning does not because nobody is asking for it. Showing
/// the method as three steps asks for it — and makes the difference between a
/// closed position and a finished journal entry something the user can see
/// rather than something only the app knows.
class StageProgress extends StatelessWidget {
  final TradeStage stage;

  const StageProgress({super.key, required this.stage});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final reached = stage.step ?? 0;

    if (stage == TradeStage.planned || stage == TradeStage.cancelled) {
      return Row(
        children: [
          Icon(Icons.event_note_outlined,
              size: Sizes.iconMd, color: colors.textSecondary),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              'A plan. Nothing entered yet.',
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      );
    }

    return Semantics(
      label: 'Step $reached of 3: ${stage.label}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var step = 1; step <= 3; step++) ...[
            if (step > 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: Spacing.xs),
                  color: step <= reached ? colors.accent : colors.border,
                ),
              ),
            _Step(
              index: step,
              label: switch (step) {
                1 => 'Entered',
                2 => 'Exited',
                _ => 'Executed',
              },
              done: step < reached,
              current: step == reached,
            ),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int index;
  final String label;
  final bool done;
  final bool current;

  const _Step({
    required this.index,
    required this.label,
    required this.done,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final active = done || current;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: active ? colors.accent : colors.surfaceSunken,
            shape: BoxShape.circle,
            border: Border.all(
              color: current ? colors.accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: done
                ? Icon(Icons.check_rounded,
                    size: Sizes.iconSm, color: colors.onAccent)
                : Text(
                    '$index',
                    style: text.labelMedium?.copyWith(
                      color: active ? colors.onAccent : colors.textTertiary,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          label,
          style: text.labelSmall?.copyWith(
            color: active ? colors.textPrimary : colors.textTertiary,
          ),
        ),
      ],
    );
  }
}
