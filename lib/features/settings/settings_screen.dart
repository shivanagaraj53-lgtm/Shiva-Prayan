import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../app/router.dart';
import '../../design/components/coaching_card.dart';
import '../../design/components/feedback.dart';
import '../../design/components/surfaces.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';
import '../onboarding/sample_journal.dart';

/// Profile, appearance, privacy and account management (§24, §32).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final profile = ref.watch(profileProvider).value;
    final preferences = ref.watch(preferencesProvider);
    final account = ref.watch(activeAccountProvider);
    final auth = ref.watch(authStateProvider).value;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.page,
            Spacing.lg,
            Spacing.page,
            Spacing.scrollBottom,
          ),
          children: [
            Text('Profile', style: text.headlineLarge),
            const SizedBox(height: Spacing.lg),
            PrayanCard(
              child: Column(
                children: [
                  DetailRow(
                    label: 'Signed in as',
                    value: auth?.email ?? 'Not signed in',
                  ),
                  DetailRow(
                    label: 'Timezone',
                    value: profile?.timezoneName ?? '—',
                  ),
                  DetailRow(
                    label: 'Experience',
                    value: profile?.experience.label ?? '—',
                  ),
                  DetailRow(
                    label: 'Style',
                    value: profile?.style.label ?? '—',
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.section),
            const SectionHeader(title: 'Account'),
            PrayanCard(
              child: Column(
                children: [
                  DetailRow(
                    label: 'Name',
                    value: account?.name ?? '—',
                  ),
                  DetailRow(
                    label: 'Currency',
                    value: account == null
                        ? '—'
                        : '${account.currency.name} '
                            '(${account.currency.code})',
                  ),
                  DetailRow(
                    label: 'Starting equity',
                    value: account == null
                        ? '—'
                        : Money(account.startingEquity, account.currency)
                            .format(),
                  ),
                  DetailRow(
                    label: 'Risk measured against',
                    value: account == null
                        ? '—'
                        : (account.useLiveEquityForRisk
                            ? 'Current equity'
                            : 'Starting equity'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.section),
            _NavRow(
              icon: Icons.rule_rounded,
              title: 'Rules',
              subtitle: 'Your discipline rules and their thresholds',
              onTap: () => context.push(Routes.rules),
            ),
            _NavRow(
              icon: Icons.category_outlined,
              title: 'Setups',
              subtitle: 'Your patterns, and the notes each one prompts for',
              onTap: () => context.push(Routes.setups),
            ),
            _NavRow(
              icon: Icons.psychology_outlined,
              title: 'Psychology',
              subtitle: 'Mood check-ins and the patterns in your own data',
              onTap: () => context.push(Routes.psychology),
            ),
            _NavRow(
              icon: Icons.calendar_view_week_rounded,
              title: 'Weekly review',
              subtitle: 'Discipline trend, weakest rule, one focus',
              onTap: () => context.push(Routes.weeklyReview),
            ),
            _NavRow(
              icon: Icons.calendar_month_rounded,
              title: 'Monthly review',
              subtitle: 'Process score, strategy breakdown, drawdown',
              onTap: () => context.push(Routes.monthlyReview),
            ),
            const SizedBox(height: Spacing.section),
            const SectionHeader(
              title: 'Appearance',
              subtitle: 'Four themes, two of each brightness.',
            ),
            PrayanCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: Spacing.sm,
                    runSpacing: Spacing.sm,
                    children: [
                      for (final theme in PrayanTheme.values)
                        _ThemeSwatch(
                          theme: theme,
                          selected: preferences.theme == theme,
                          onTap: () => ref
                              .read(preferencesProvider.notifier)
                              .update(preferences.copyWith(theme: theme)),
                        ),
                    ],
                  ),
                  const SizedBox(height: Spacing.lg),
                  SwitchListTile(
                    value: preferences.followSystemBrightness,
                    onChanged: (value) => ref
                        .read(preferencesProvider.notifier)
                        .update(
                          preferences.copyWith(followSystemBrightness: value),
                        ),
                    title: const Text('Follow system light and dark'),
                    subtitle: Text(
                      'Switches to the matching counterpart of your theme.',
                      style:
                          text.bodySmall?.copyWith(color: colors.textSecondary),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: preferences.reduceMotion,
                    onChanged: (value) =>
                        ref.read(preferencesProvider.notifier).update(
                              preferences.copyWith(reduceMotion: value),
                            ),
                    title: const Text('Reduce motion'),
                    subtitle: Text(
                      'On top of your device setting.',
                      style:
                          text.bodySmall?.copyWith(color: colors.textSecondary),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text('Text size', style: text.titleSmall),
                  Slider(
                    value: preferences.textScale,
                    min: 0.9,
                    max: 1.4,
                    divisions: 5,
                    label: '${(preferences.textScale * 100).round()}%',
                    onChanged: (value) =>
                        ref.read(preferencesProvider.notifier).update(
                              preferences.copyWith(textScale: value),
                            ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.section),
            const SectionHeader(
              title: 'Scoring',
              subtitle:
                  'How much each part of your process counts. Changing these '
                  'affects how future days are scored.',
            ),
            PrayanCard(
              child: Column(
                children: [
                  for (final category in RuleCategory.values)
                    _WeightSlider(
                      category: category,
                      weight: preferences.scoring.weightFor(category),
                      onChanged: (value) {
                        final weights = {
                          ...preferences.scoring.categoryWeights,
                          category: value,
                        };
                        ref.read(preferencesProvider.notifier).update(
                              preferences.copyWith(
                                scoring: ScoringConfig(
                                  categoryWeights: weights,
                                  majorViolationCap:
                                      preferences.scoring.majorViolationCap,
                                  majorViolationResetsStreak: preferences
                                      .scoring.majorViolationResetsStreak,
                                ),
                              ),
                            );
                      },
                    ),
                  const Divider(),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'A major violation caps the day at '
                    '${preferences.scoring.majorViolationCap}.',
                    style:
                        text.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                  Slider(
                    value: preferences.scoring.majorViolationCap.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${preferences.scoring.majorViolationCap}',
                    onChanged: (value) =>
                        ref.read(preferencesProvider.notifier).update(
                              preferences.copyWith(
                                scoring: ScoringConfig(
                                  categoryWeights:
                                      preferences.scoring.categoryWeights,
                                  majorViolationCap: value.round(),
                                  majorViolationResetsStreak: preferences
                                      .scoring.majorViolationResetsStreak,
                                ),
                              ),
                            ),
                  ),
                  SwitchListTile(
                    value: preferences.countNoTradeDaysInStreak,
                    onChanged: (value) => ref
                        .read(preferencesProvider.notifier)
                        .update(
                          preferences.copyWith(countNoTradeDaysInStreak: value),
                        ),
                    title: const Text('No-trade days extend the streak'),
                    subtitle: Text(
                      'Off by default: a quiet day never breaks a streak, but '
                      'it does not inflate one either.',
                      style:
                          text.bodySmall?.copyWith(color: colors.textSecondary),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.section),
            const SectionHeader(title: 'Privacy'),
            PrayanCard(
              child: Column(
                children: [
                  SwitchListTile(
                    value: preferences.privacyBlur,
                    onChanged: (value) =>
                        ref.read(preferencesProvider.notifier).update(
                              preferences.copyWith(privacyBlur: value),
                            ),
                    title: const Text('Hide money figures until tapped'),
                    subtitle: Text(
                      'For journalling somewhere public.',
                      style:
                          text.bodySmall?.copyWith(color: colors.textSecondary),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: preferences.biometricLock,
                    onChanged: (value) =>
                        ref.read(preferencesProvider.notifier).update(
                              preferences.copyWith(biometricLock: value),
                            ),
                    title: const Text('Require biometric unlock'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: preferences.analyticsConsent,
                    onChanged: (value) =>
                        ref.read(preferencesProvider.notifier).update(
                              preferences.copyWith(analyticsConsent: value),
                            ),
                    title: const Text('Share anonymous usage analytics'),
                    subtitle: Text(
                      'Off by default. Never includes symbols, prices, sizes '
                      'or balances.',
                      style:
                          text.bodySmall?.copyWith(color: colors.textSecondary),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: preferences.aiCoachingEnabled,
                    onChanged: (value) =>
                        ref.read(preferencesProvider.notifier).update(
                              preferences.copyWith(aiCoachingEnabled: value),
                            ),
                    title: const Text('AI-written coaching'),
                    subtitle: Text(
                      'Sends computed summary figures only — never your trades '
                      'or account balance. Off means Prayan uses its built-in '
                      'coaching instead, which works the same offline.',
                      style:
                          text.bodySmall?.copyWith(color: colors.textSecondary),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.section),
            const SectionHeader(title: 'Your data'),
            _NavRow(
              icon: Icons.download_outlined,
              title: 'Export my journal',
              subtitle: 'Everything you have logged, as a file you keep',
              onTap: () => _notYet(context, 'Export'),
            ),
            _NavRow(
              icon: Icons.science_outlined,
              title: 'Remove sample trades',
              subtitle: 'Delete the worked example, keep everything real',
              onTap: () => _removeSamples(context, ref),
            ),
            _NavRow(
              icon: Icons.logout_rounded,
              title: 'Sign out',
              onTap: () => ref.read(authRepositoryProvider).signOut(),
            ),
            _NavRow(
              icon: Icons.delete_forever_outlined,
              title: 'Delete my account',
              subtitle: 'Removes your account and every trade in it',
              destructive: true,
              onTap: () => _deleteAccount(context, ref),
            ),
            const SizedBox(height: Spacing.section),
            const DisclaimerNote(),
            const SizedBox(height: Spacing.sm),
            Center(
              child: Text(
                'Prayan Trading Journal · 0.1.0',
                style: text.labelSmall?.copyWith(color: colors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _notYet(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature arrives with the Firebase backend — see '
          'docs/FIREBASE_SETUP.md.',
        ),
      ),
    );
  }

  static Future<void> _removeSamples(
      BuildContext context, WidgetRef ref) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Remove the sample trades?',
      message: 'Only trades marked as samples are removed. Anything you '
          'logged yourself stays exactly as it is.',
      confirmLabel: 'Remove samples',
    );
    if (!confirmed) return;
    await SampleJournal.remove(
      trades: ref.read(tradeRepositoryProvider),
      userId: userId,
      todayKey: ref.read(todayKeyProvider),
    );
  }

  static Future<void> _deleteAccount(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete your account?',
      message:
          'This removes your profile, every trade, every rule and your whole '
          'discipline history. It cannot be undone, and there is no copy kept.',
      confirmLabel: 'Delete everything',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(authRepositoryProvider).deleteAccount();
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _NavRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = destructive ? colors.violation : colors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: PrayanCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: Sizes.iconMd, color: tint),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: tint),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: Spacing.xxs),
                    Text(
                      subtitle!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  final PrayanTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeSwatch({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = theme.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: '${theme.label} theme',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Container(
          width: 84,
          padding: const EdgeInsets.all(Spacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: selected ? palette.accent : context.colors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: palette.canvas,
                  borderRadius: BorderRadius.circular(Radii.xs),
                  border: Border.all(color: palette.border),
                ),
                child: Center(
                  child: Container(
                    width: 32,
                    height: 8,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(Radii.xs),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                theme.label,
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeightSlider extends StatelessWidget {
  final RuleCategory category;
  final int weight;
  final ValueChanged<int> onChanged;

  const _WeightSlider({
    required this.category,
    required this.weight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category.label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Text(
                '$weight',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          Slider(
            value: weight.toDouble(),
            min: 0,
            max: 40,
            divisions: 8,
            label: '$weight',
            onChanged: (value) => onChanged(value.round()),
          ),
        ],
      );
}
