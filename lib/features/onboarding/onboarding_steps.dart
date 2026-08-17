import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../design/components/segmented_control.dart';
import '../../design/components/surfaces.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../domain/models.dart';
import 'onboarding_controller.dart';
import 'onboarding_screen.dart';

/// Base for a step that edits the shared draft.
abstract class _DraftStep extends ConsumerWidget {
  final OnboardingDraft draft;
  const _DraftStep({super.key, required this.draft});

  OnboardingController controller(WidgetRef ref) =>
      ref.read(onboardingProvider.notifier);
}

/// Step 3 — experience level.
class OnboardingExperienceStep extends _DraftStep {
  const OnboardingExperienceStep({super.key, required super.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) => OnboardingStepScaffold(
        title: 'How long have you been trading?',
        subtitle:
            'This only changes how much explanation Prayan shows by default. '
            'Nothing is hidden from you either way.',
        child: OnboardingChoiceList<ExperienceLevel>(
          selected: draft.experience,
          onChanged: (value) =>
              controller(ref).update(draft.copyWith(experience: value)),
          options: [
            for (final level in ExperienceLevel.values)
              (level, level.label, level.description),
          ],
        ),
      );
}

/// Step 4 — markets traded. Multi-select.
class OnboardingMarketsStep extends _DraftStep {
  const OnboardingMarketsStep({super.key, required super.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) => OnboardingStepScaffold(
        title: 'What do you trade?',
        subtitle:
            'Pick everything that applies. Prayan is instrument-agnostic, so '
            'you can add more later.',
        child: Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            for (final asset in AssetClass.values)
              PrayanChoiceChip(
                label: asset.label,
                selected: draft.markets.contains(asset),
                onSelected: (selected) {
                  final markets = [...draft.markets];
                  if (selected) {
                    markets.add(asset);
                  } else {
                    markets.remove(asset);
                  }
                  // Never let the list empty out: the trade form needs a
                  // default asset class to pre-select.
                  controller(ref).update(draft.copyWith(
                    markets: markets.isEmpty ? [AssetClass.equity] : markets,
                  ));
                },
              ),
          ],
        ),
      );
}

/// Step 5 — trading style.
class OnboardingStyleStep extends _DraftStep {
  const OnboardingStyleStep({super.key, required super.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) => OnboardingStepScaffold(
        title: 'How long do you hold?',
        subtitle: 'Used to choose sensible defaults on the trade form.',
        child: OnboardingChoiceList<TradingStyle>(
          selected: draft.style,
          onChanged: (value) =>
              controller(ref).update(draft.copyWith(style: value)),
          options: [
            for (final style in TradingStyle.values)
              (style, style.label, style.description),
          ],
        ),
      );
}

/// Step 6 — currency.
class OnboardingCurrencyStep extends _DraftStep {
  const OnboardingCurrencyStep({super.key, required super.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return OnboardingStepScaffold(
      title: 'Which currency do you account in?',
      subtitle: 'Prayan records every trade in your account currency and never '
          'converts between currencies on its own.',
      child: Column(
        children: [
          for (final currency in Currency.supported)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: PrayanCard(
                onTap: () => controller(ref)
                    .update(draft.copyWith(currencyCode: currency.code)),
                emphasised: currency.code == draft.currencyCode,
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        currency.symbol,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        currency.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      currency.code,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: colors.textTertiary),
                    ),
                    if (currency.code == draft.currencyCode) ...[
                      const SizedBox(width: Spacing.sm),
                      Icon(Icons.check_rounded,
                          size: Sizes.iconMd, color: colors.accent),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Step 7 — timezone.
class OnboardingTimezoneStep extends _DraftStep {
  const OnboardingTimezoneStep({super.key, required super.draft});

  /// A short list covering the major trading centres. Settings offers the
  /// full IANA database; asking a new user to scroll 400 zones is hostile.
  static const _zones = <(String, String)>[
    ('Asia/Kolkata', 'India — NSE, BSE'),
    ('America/New_York', 'New York — NYSE, Nasdaq'),
    ('Europe/London', 'London — LSE'),
    ('Asia/Singapore', 'Singapore — SGX'),
    ('Asia/Dubai', 'Dubai — DFM'),
    ('Asia/Tokyo', 'Tokyo — TSE'),
    ('Australia/Sydney', 'Sydney — ASX'),
    ('Europe/Frankfurt', 'Frankfurt — XETRA'),
    ('UTC', 'UTC — crypto and 24-hour markets'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) => OnboardingStepScaffold(
        title: 'Which timezone is your trading day in?',
        subtitle:
            'This decides which calendar day a trade belongs to, so daily '
            'limits and streaks line up with the sessions you actually trade.',
        child: OnboardingChoiceList<String>(
          selected: draft.timezoneName,
          onChanged: (value) =>
              controller(ref).update(draft.copyWith(timezoneName: value)),
          options: [
            for (final zone in _zones) (zone.$1, zone.$1, zone.$2),
          ],
        ),
      );
}

/// Step 8 — optional starting equity.
class OnboardingEquityStep extends _DraftStep {
  const OnboardingEquityStep({super.key, required super.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = draft.currency;
    return OnboardingStepScaffold(
      title: 'What is your account size?',
      subtitle: 'Optional. Prayan needs it to express risk as a percentage — '
          'without it, percentage rules are reported as "needs data" rather '
          'than quietly passing.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            initialValue: draft.startingEquity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Account equity',
              prefixText: '${currency.symbol} ',
              helperText: 'You can change this at any time in Accounts.',
            ),
            onChanged: (value) =>
                controller(ref).update(draft.copyWith(startingEquity: value)),
          ),
          const SizedBox(height: Spacing.md),
          if (Dec.tryParse(draft.startingEquity) != null)
            Text(
              Money(Dec.parse(draft.startingEquity), currency).format(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
        ],
      ),
    );
  }
}

/// Step 9 — rule template.
class OnboardingTemplateStep extends _DraftStep {
  const OnboardingTemplateStep({super.key, required super.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return OnboardingStepScaffold(
      title: 'Choose a starting rule set',
      subtitle:
          'These are organisational templates, not financial recommendations. '
          'Every threshold is yours to change, and changing one never rewrites '
          'how past trades were judged.',
      child: Column(
        children: [
          for (final template in RuleTemplates.all)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: PrayanCard(
                onTap: () => controller(ref)
                    .update(draft.copyWith(templateId: template.id)),
                emphasised: template.id == draft.templateId,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          template.id == draft.templateId
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: Sizes.iconMd,
                          color: template.id == draft.templateId
                              ? colors.accent
                              : colors.textTertiary,
                        ),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                            child:
                                Text(template.name, style: text.titleMedium)),
                        Text(
                          '${template.entries.length} rules',
                          style: text.labelSmall
                              ?.copyWith(color: colors.textTertiary),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      template.description,
                      style:
                          text.bodySmall?.copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      template.disclaimer,
                      style: text.labelSmall?.copyWith(
                        color: colors.textTertiary,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Steps 10–12 collapsed into one screen: the four numbers that matter.
class OnboardingRiskStep extends _DraftStep {
  const OnboardingRiskStep({super.key, required super.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equity = Dec.tryParse(draft.startingEquity);
    final riskPercent = Dec.tryParse(draft.maxRiskPercent);
    final perTrade = (equity != null && riskPercent != null && !equity.isZero)
        ? Money(
            (equity * riskPercent).divide(Dec.hundred, scale: 2),
            draft.currency,
          )
        : null;

    return OnboardingStepScaffold(
      title: 'Set your limits',
      subtitle:
          'The four numbers Prayan measures every trade against. Conservative '
          'beats ambitious here — you can raise them once you have data.',
      child: Column(
        children: [
          _NumberField(
            label: 'Maximum risk per trade',
            suffix: '%',
            value: draft.maxRiskPercent,
            helper: perTrade == null
                ? 'Percentage of account equity.'
                : 'About ${perTrade.format()} per trade.',
            onChanged: (value) =>
                controller(ref).update(draft.copyWith(maxRiskPercent: value)),
          ),
          _NumberField(
            label: 'Minimum planned reward:risk',
            prefix: '1 : ',
            value: draft.minRewardRisk,
            helper: 'Only take setups planned at this ratio or better.',
            onChanged: (value) =>
                controller(ref).update(draft.copyWith(minRewardRisk: value)),
          ),
          _NumberField(
            label: 'Maximum trades per day',
            value: draft.maxTradesPerDay,
            helper: 'Taking fewer, better trades usually scores higher.',
            onChanged: (value) =>
                controller(ref).update(draft.copyWith(maxTradesPerDay: value)),
          ),
          _NumberField(
            label: 'Daily loss stop',
            suffix: 'R',
            value: draft.dailyLossR,
            helper: 'Finish for the day once you are down this many R.',
            onChanged: (value) =>
                controller(ref).update(draft.copyWith(dailyLossR: value)),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final String value;
  final String? helper;
  final String? prefix;
  final String? suffix;
  final ValueChanged<String> onChanged;

  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.prefix,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.lg),
        child: TextFormField(
          initialValue: value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            helperMaxLines: 2,
            prefixText: prefix,
            suffixText: suffix,
          ),
          onChanged: onChanged,
        ),
      );
}

/// Step 11 — notifications.
class OnboardingNotificationsStep extends _DraftStep {
  const OnboardingNotificationsStep({super.key, required super.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final notifications = draft.notifications;

    void set(NotificationPreferences value) =>
        controller(ref).update(draft.copyWith(notifications: value));

    return OnboardingStepScaffold(
      title: 'Reminders',
      subtitle:
          'Only about finishing your journal and your reviews. Prayan will '
          'never nudge you to take another trade.',
      child: Column(
        children: [
          _ToggleRow(
            title: 'Pre-market plan',
            subtitle: 'A prompt to set your intent before the session.',
            value: notifications.preMarketPlan,
            onChanged: (v) => set(notifications.copyWith(preMarketPlan: v)),
          ),
          _ToggleRow(
            title: 'Unfinished journal entry',
            subtitle: 'If a trade is missing its notes at the end of the day.',
            value: notifications.journalIncomplete,
            onChanged: (v) => set(notifications.copyWith(journalIncomplete: v)),
          ),
          _ToggleRow(
            title: 'End-of-day review',
            subtitle: 'One prompt to close the day properly.',
            value: notifications.endOfDayReview,
            onChanged: (v) => set(notifications.copyWith(endOfDayReview: v)),
          ),
          _ToggleRow(
            title: 'Weekly review',
            subtitle: 'A weekend look at the week.',
            value: notifications.weeklyReview,
            onChanged: (v) => set(notifications.copyWith(weeklyReview: v)),
          ),
          _ToggleRow(
            title: 'Quiet hours',
            subtitle: 'Nothing between 21:30 and 07:00.',
            value: notifications.quietHoursEnabled,
            onChanged: (v) => set(notifications.copyWith(quietHoursEnabled: v)),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'You can change all of this in Settings, and turn any of it off '
            'entirely.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: PrayanCard(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  const SizedBox(height: Spacing.xxs),
                  Text(
                    subtitle,
                    style:
                        text.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// Step 12 — the worked example, offered rather than imposed.
class OnboardingSampleStep extends _DraftStep {
  const OnboardingSampleStep({super.key, required super.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return OnboardingStepScaffold(
      title: 'Want a worked example first?',
      subtitle:
          'Prayan can load three sample trades — a disciplined loss, a clean '
          'winner, and a profitable trade that broke the rules — so you can '
          'see how the score reacts before logging anything real.',
      child: Column(
        children: [
          _ToggleRow(
            title: 'Load the sample journal',
            subtitle:
                'Clearly marked as samples, and removable in one tap from '
                'Settings.',
            value: draft.loadSampleJournal,
            onChanged: (v) =>
                controller(ref).update(draft.copyWith(loadSampleJournal: v)),
          ),
          const SizedBox(height: Spacing.lg),
          PrayanCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: Sizes.iconMd, color: colors.accent),
                    const SizedBox(width: Spacing.sm),
                    Text('One last thing', style: text.titleMedium),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  'Prayan is a journalling and reflection tool. It does not '
                  'give financial advice, does not predict returns, and cannot '
                  'place trades. What it does is measure whether you followed '
                  'the plan you set for yourself.',
                  style: text.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
