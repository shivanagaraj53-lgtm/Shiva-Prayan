import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/surfaces.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../splash/splash_screen.dart';
import 'onboarding_controller.dart';
import 'onboarding_steps.dart';

/// The guided first run (§23).
///
/// Twelve questions, one decision per screen. Nothing here asks for brokerage
/// credentials, and every rule template is labelled as a starting structure
/// rather than a recommendation.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _saving = false;

  static const _stepCount = 12;

  void _next() {
    if (_index >= _stepCount - 1) {
      _finish();
      return;
    }
    setState(() => _index++);
    _controller.animateToPage(
      _index,
      duration: Motion.duration(context, Motion.standard),
      curve: Motion.emphasis,
    );
  }

  void _back() {
    if (_index == 0) return;
    setState(() => _index--);
    _controller.animateToPage(
      _index,
      duration: Motion.duration(context, Motion.standard),
      curve: Motion.emphasis,
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await ref.read(onboardingProvider.notifier).commit();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    // The router redirect moves to the dashboard once the profile is marked
    // complete, so there is nothing to push here.
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final draft = ref.watch(onboardingProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ProgressHeader(
              index: _index,
              total: _stepCount,
              onBack: _index == 0 ? null : _back,
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const OnboardingWelcomeStep(),
                  const OnboardingPromiseStep(),
                  OnboardingExperienceStep(draft: draft),
                  OnboardingMarketsStep(draft: draft),
                  OnboardingStyleStep(draft: draft),
                  OnboardingCurrencyStep(draft: draft),
                  OnboardingTimezoneStep(draft: draft),
                  OnboardingEquityStep(draft: draft),
                  OnboardingTemplateStep(draft: draft),
                  OnboardingRiskStep(draft: draft),
                  OnboardingNotificationsStep(draft: draft),
                  OnboardingSampleStep(draft: draft),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.page,
                Spacing.md,
                Spacing.page,
                Spacing.lg,
              ),
              child: Column(
                children: [
                  FilledButton(
                    onPressed: _saving ? null : _next,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_index == _stepCount - 1
                            ? 'Open my journal'
                            : 'Continue'),
                  ),
                  if (_index >= 2 && _index < _stepCount - 1) ...[
                    const SizedBox(height: Spacing.xs),
                    TextButton(
                      onPressed: _saving ? null : _next,
                      child: Text(
                        'Skip for now',
                        style: TextStyle(color: colors.textTertiary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int index;
  final int total;
  final VoidCallback? onBack;

  const _ProgressHeader({
    required this.index,
    required this.total,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.sm,
        Spacing.sm,
        Spacing.page,
        Spacing.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: Sizes.minTouchTarget,
            child: onBack == null
                ? null
                : IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                  ),
          ),
          Expanded(
            child: Semantics(
              label: 'Step ${index + 1} of $total',
              excludeSemantics: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.xs),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (index + 1) / total),
                  duration: Motion.duration(context, Motion.standard),
                  curve: Motion.enter,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    backgroundColor: colors.surfaceSunken,
                    valueColor: AlwaysStoppedAnimation(colors.accent),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Text(
            '${index + 1}/$total',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Shared frame for a step: title, supporting copy, then content.
class OnboardingStepScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? header;

  const OnboardingStepScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.page,
        vertical: Spacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[header!, const SizedBox(height: Spacing.xl)],
          Text(title, style: text.headlineLarge),
          if (subtitle != null) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              subtitle!,
              style: text.bodyMedium?.copyWith(
                color: colors.textSecondary,
                height: 1.55,
              ),
            ),
          ],
          const SizedBox(height: Spacing.xl),
          child,
          const SizedBox(height: Spacing.xxl),
        ],
      ),
    );
  }
}

/// Step 1 — brand.
class OnboardingWelcomeStep extends StatelessWidget {
  const OnboardingWelcomeStep({super.key});

  @override
  Widget build(BuildContext context) => const OnboardingStepScaffold(
        header: Center(child: PrayanMark(size: 88)),
        title: 'Welcome to Prayan',
        subtitle:
            'A journal for traders who want to improve the process, not chase '
            'the score. Setup takes about two minutes, and you can change any '
            'of it later.',
        child: SizedBox.shrink(),
      );
}

/// Step 2 — the product promise, stated plainly including what it is not.
class OnboardingPromiseStep extends StatelessWidget {
  const OnboardingPromiseStep({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return OnboardingStepScaffold(
      title: 'Plan the trade.\nFollow the rules.\nMeasure the discipline.',
      subtitle:
          'Prayan scores how well you followed your own plan — not how much '
          'you made. A losing trade that respected every rule scores higher '
          'than a winner that broke one.',
      child: Column(
        children: [
          for (final promise in const [
            (
              Icons.rule_rounded,
              'Your rules, your thresholds',
              'You define the limits. Prayan only measures them.',
            ),
            (
              Icons.insights_rounded,
              'An explainable score',
              'Every point is traceable to a specific rule on a specific '
                  'trade.',
            ),
            (
              Icons.lock_outline_rounded,
              'No brokerage credentials',
              'Prayan never connects to your broker and cannot place trades.',
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: PrayanCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(promise.$1, color: colors.accent, size: Sizes.iconLg),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(promise.$2, style: text.titleMedium),
                          const SizedBox(height: Spacing.xxs),
                          Text(
                            promise.$3,
                            style: text.bodySmall
                                ?.copyWith(color: colors.textSecondary),
                          ),
                        ],
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

/// A reusable single-choice list used by several steps.
class OnboardingChoiceList<T> extends StatelessWidget {
  final List<(T value, String label, String? description)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const OnboardingChoiceList({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: PrayanCard(
              onTap: () => onChanged(option.$1),
              emphasised: option.$1 == selected,
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                children: [
                  Icon(
                    option.$1 == selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: option.$1 == selected
                        ? colors.accent
                        : colors.textTertiary,
                    size: Sizes.iconMd,
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(option.$2, style: text.titleMedium),
                        if (option.$3 != null) ...[
                          const SizedBox(height: Spacing.xxs),
                          Text(
                            option.$3!,
                            style: text.bodySmall
                                ?.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
