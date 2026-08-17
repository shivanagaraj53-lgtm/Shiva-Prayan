import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../design/components/coaching_card.dart';
import '../../design/components/segmented_control.dart';
import '../../design/components/surfaces.dart';
import '../../design/format.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';

/// The psychology and behaviour journal (§13).
///
/// Everything here is phrased as observation, never diagnosis. Prayan reports
/// what the user's own data shows and stops there — it does not tell anyone
/// what they are, or suggest they get help, or use clinical vocabulary.
class PsychologyScreen extends ConsumerStatefulWidget {
  const PsychologyScreen({super.key});

  @override
  ConsumerState<PsychologyScreen> createState() => _PsychologyScreenState();
}

class _PsychologyScreenState extends ConsumerState<PsychologyScreen> {
  EmotionTag? _selected;
  int _intensity = 3;
  bool _preSession = true;
  final _noteController = TextEditingController();
  final _watchController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    _watchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final today = ref.watch(todayKeyProvider);
    final entries =
        ref.watch(psychologyForDayProvider(today)).value ?? const [];
    final userId = ref.watch(currentUserIdProvider);

    // Ninety days of trades, so an emotional pattern has enough sample to be
    // worth mentioning at all.
    final from = _shift(today, -90);
    final trades =
        ref.watch(tradesInRangeProvider(DayRange(from, today))).value ??
            const <Trade>[];
    final byEmotion = PerformanceCalculator.groupBy<EmotionTag>(
        trades, (t) => t.emotionBefore);

    return Scaffold(
      appBar: AppBar(title: const Text('Psychology')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.page,
          Spacing.md,
          Spacing.page,
          Spacing.xxxl,
        ),
        children: [
          const SectionHeader(
            title: 'How are you right now?',
            subtitle: 'One tap. It only takes a moment, and it is the input '
                'that makes the patterns below meaningful.',
          ),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (final emotion in EmotionTag.values)
                PrayanChoiceChip(
                  label: emotion.label,
                  selected: _selected == emotion,
                  selectedColor:
                      emotion.isElevatedRisk ? colors.warning : colors.accent,
                  onSelected: (selected) =>
                      setState(() => _selected = selected ? emotion : null),
                ),
            ],
          ),
          if (_selected != null) ...[
            const SizedBox(height: Spacing.lg),
            Text('How strongly? ($_intensity/5)', style: text.titleSmall),
            Slider(
              value: _intensity.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '$_intensity',
              onChanged: (value) => setState(() => _intensity = value.round()),
            ),
            PrayanSegmentedControl<bool>(
              compact: true,
              value: _preSession,
              onChanged: (value) => setState(() => _preSession = value),
              options: const [
                SegmentOption(value: true, label: 'Before trading'),
                SegmentOption(value: false, label: 'After trading'),
              ],
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _noteController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Anything worth noting? (optional)',
              ),
            ),
            const SizedBox(height: Spacing.md),
            FilledButton(
              onPressed:
                  userId == null ? null : () => _saveEntry(userId, today),
              child: const Text('Record'),
            ),
          ],

          if (entries.isNotEmpty) ...[
            const SizedBox(height: Spacing.section),
            const SectionHeader(title: 'Today'),
            PrayanCard(
              child: Column(
                children: [
                  for (final entry in entries)
                    DetailRow(
                      label: entry.isPreSession ? 'Before' : 'After',
                      value: '${entry.emotion.label} · ${entry.intensity}/5',
                    ),
                ],
              ),
            ),
          ],

          // --- Observed patterns ------------------------------------------
          const SizedBox(height: Spacing.section),
          const SectionHeader(
            title: 'What your own data shows',
            subtitle: 'Observations from your records over the last 90 days. '
                'One day is never a pattern.',
          ),
          if (byEmotion.values.every((m) => m.tradeCount < 3))
            PrayanCard(
              child: Text(
                'Not enough tagged trades yet. Once you have a few days of '
                'entries, patterns worth noticing will appear here.',
                style: text.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            )
          else
            PrayanCard(
              child: Column(
                children: [
                  for (final entry in _rankedEmotions(byEmotion))
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(entry.key.label,
                                    style: text.titleSmall),
                              ),
                              Text(
                                Fmt.r(entry.value.expectancyR),
                                style: PrayanType.figure(
                                  colors.forSign(entry.value.netPnl.signum),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Spacing.xxs),
                          Text(
                            '${entry.value.tradeCount} trades · '
                            '${Fmt.percent(entry.value.winRate, decimals: 0)} '
                            'win rate · expectancy per trade',
                            style: text.labelSmall?.copyWith(
                              color: colors.textTertiary,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // --- Personal warning conditions --------------------------------
          const SizedBox(height: Spacing.section),
          const SectionHeader(
            title: 'Things to watch for',
            subtitle:
                'Your own notes on situations where you tend to slip. Prayan '
                'shows them back to you; it does not judge them.',
          ),
          for (final watch in ref.watch(behaviourWatchesProvider).value ??
              const <BehaviourWatch>[])
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: PrayanCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(watch.description)),
                    IconButton(
                      onPressed: () => ref
                          .read(psychologyRepositoryProvider)
                          .deleteBehaviourWatch(watch.id),
                      icon: const Icon(Icons.close_rounded, size: Sizes.iconSm),
                      tooltip: 'Remove',
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _watchController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'After two losses I tend to size up',
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Add',
                onPressed: userId == null ? null : () => _addWatch(userId),
              ),
            ),
          ),

          const SizedBox(height: Spacing.section),
          const DisclaimerNote(
            text: 'These are self-reported journal notes, not a psychological '
                'assessment. Prayan makes no clinical claims of any kind.',
          ),
        ],
      ),
    );
  }

  Future<void> _saveEntry(String userId, String dayKey) async {
    final emotion = _selected;
    if (emotion == null) return;
    final now = ref.read(nowProvider)();
    await ref.read(psychologyRepositoryProvider).saveEntry(
          PsychologyEntry(
            id: 'psy_${now.microsecondsSinceEpoch}',
            userId: userId,
            dayKey: dayKey,
            emotion: emotion,
            intensity: _intensity,
            isPreSession: _preSession,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            recordedAtUtc: now,
          ),
        );
    if (!mounted) return;
    _noteController.clear();
    setState(() => _selected = null);
  }

  Future<void> _addWatch(String userId) async {
    final description = _watchController.text.trim();
    if (description.isEmpty) return;
    await ref.read(psychologyRepositoryProvider).saveBehaviourWatch(
          BehaviourWatch(
            id: 'watch_${DateTime.now().microsecondsSinceEpoch}',
            userId: userId,
            description: description,
          ),
        );
    if (mounted) _watchController.clear();
  }

  /// Emotions with enough trades to be worth reporting, worst first.
  static List<MapEntry<EmotionTag, PerformanceMetrics>> _rankedEmotions(
    Map<EmotionTag, PerformanceMetrics> byEmotion,
  ) {
    final entries =
        byEmotion.entries.where((entry) => entry.value.tradeCount >= 3).toList()
          ..sort((a, b) {
            final aR = a.value.expectancyR ?? Dec.zero;
            final bR = b.value.expectancyR ?? Dec.zero;
            return aR.compareTo(bR);
          });
    return entries;
  }

  static String _shift(String dayKey, int days) {
    final date = TradingDay.parseKey(dayKey);
    if (date == null) return dayKey;
    return TradingDay.format(date.add(Duration(days: days)));
  }
}
