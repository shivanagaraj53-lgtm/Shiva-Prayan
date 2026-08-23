import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../design/components/feedback.dart';
import '../../design/components/rule_status_tile.dart';
import '../../design/components/segmented_control.dart';
import '../../design/components/surfaces.dart';
import '../../design/components/tag_editor.dart';
import '../../design/format.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../state/providers.dart';
import 'screenshot_strip.dart';
import 'stage_progress.dart';
import 'trade_form_controller.dart';

/// The Log Trade flow (§7).
///
/// Structured for the brief's 20–30 second target: the six fields that
/// determine risk are above the fold and nothing else is required. Everything
/// else — psychology, notes, tags, reflection — sits behind progressive
/// disclosure so a beginner is not confronted with twenty-five inputs.
class TradeLogScreen extends ConsumerStatefulWidget {
  /// When set, the screen edits an existing trade instead of creating one.
  final String? editTradeId;

  const TradeLogScreen({super.key, this.editTradeId});

  @override
  ConsumerState<TradeLogScreen> createState() => _TradeLogScreenState();
}

class _TradeLogScreenState extends ConsumerState<TradeLogScreen> {
  bool _saving = false;
  bool _loadedExisting = false;
  String? _saveError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final form = ref.watch(tradeFormProvider);
    final account = ref.watch(activeAccountProvider);
    final strategies = ref.watch(strategiesProvider).value ?? const [];
    final checklist = ref.watch(checklistProvider).value ?? const [];
    final rules = ref.watch(rulesProvider).value ?? const [];
    final dayKey = ref.watch(todayKeyProvider);

    _maybeLoadExisting();

    if (account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Log trade')),
        body: const EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'No account yet',
          message:
              'Finish setting up an account before logging trades, so risk '
              'can be measured against something.',
        ),
      );
    }

    final applicableChecklist = checklist
        .where((item) => item.appliesToStrategy(form.strategyId))
        .toList(growable: false);

    // The live preview runs the real engine on the real object, not a
    // simplified copy — what the user sees here is what gets saved.
    final previewTrade = form.toTrade(
      userId: account.userId,
      accountId: account.id,
      dayKey: dayKey,
      accountEquity:
          account.riskBaseEquity.isZero ? null : account.riskBaseEquity,
      presentedChecklistIds:
          applicableChecklist.map((i) => i.id).toList(growable: false),
      now: ref.read(nowProvider)(),
    );
    final metrics = TradeCalculator.compute(previewTrade);
    final issues = TradeCalculator.validate(previewTrade);
    final evaluations = RulesEngine.evaluateTrade(
      trade: previewTrade,
      rules: rules,
      context: DayContext(
        tradingDayKey: dayKey,
        account: account,
        strategiesById: {for (final s in strategies) s.id: s},
      ),
    );
    // Nothing is judged until the form is a trade. See `isJudgeable`: an empty
    // form breaks nearly every rule, and opening a screen to four red
    // violations you caused by tapping a button is not feedback.
    final liveViolations = form.isJudgeable
        ? evaluations.where((e) => e.isViolation).toList(growable: false)
        : const <RuleEvaluation>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editTradeId == null ? 'Log trade' : 'Edit trade'),
        actions: [
          TextButton(
            onPressed: form.canSave && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
          const SizedBox(width: Spacing.sm),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.page,
            Spacing.md,
            Spacing.page,
            Spacing.scrollBottom,
          ),
          children: [
            // --- The method ---------------------------------------------
            StageProgress(stage: form.stage),
            const SizedBox(height: Spacing.lg),
            _PlanOnlyToggle(form: form, onChanged: _update),
            const SizedBox(height: Spacing.lg),
            const SectionHeader(
              title: '1 · Trade entered',
              subtitle: 'What you committed to, and why.',
            ),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: form.symbol,
                    textCapitalization: TextCapitalization.characters,
                    autofocus: widget.editTradeId == null,
                    decoration: const InputDecoration(
                      labelText: 'Symbol',
                      hintText: 'RELIANCE',
                    ),
                    onChanged: (value) => _update(form.copyWith(symbol: value)),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  flex: 2,
                  child: PrayanSegmentedControl<TradeDirection>(
                    value: form.direction,
                    onChanged: (value) =>
                        _update(form.copyWith(direction: value)),
                    options: const [
                      SegmentOption(value: TradeDirection.long, label: 'Long'),
                      SegmentOption(
                          value: TradeDirection.short, label: 'Short'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),

            Row(
              children: [
                Expanded(
                  child: _NumberInput(
                    label: 'Entry',
                    hint: 'Price paid',
                    value: form.entryPrice,
                    onChanged: (v) => _update(form.copyWith(entryPrice: v)),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: _NumberInput(
                    label: 'Stop',
                    hint: 'Invalidation',
                    value: form.stopLoss,
                    onChanged: (v) => _update(form.copyWith(stopLoss: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            Row(
              children: [
                Expanded(
                  child: _NumberInput(
                    label: 'Target',
                    hint: 'Optional',
                    value: form.target,
                    onChanged: (v) => _update(form.copyWith(target: v)),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: _NumberInput(
                    label: 'Quantity',
                    hint: 'Shares / lots',
                    value: form.quantity,
                    onChanged: (v) => _update(form.copyWith(quantity: v)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: Spacing.lg),
            _RiskPreview(metrics: metrics, currency: account.currency),

            // Validation, shown as guidance not as failure.
            if (form.isDirty && issues.isNotEmpty) ...[
              const SizedBox(height: Spacing.md),
              _IssueList(issues: issues),
            ],

            // Live rule feedback — the point of the product, shown *before*
            // the trade is committed rather than as a post-mortem. Silent
            // until there is a trade to measure, and headed by what it
            // actually is: a warning that something is still open reads very
            // differently from a rule already broken.
            if (liveViolations.isNotEmpty) ...[
              const SizedBox(height: Spacing.md),
              _LiveRuleCheck(violations: liveViolations),
            ] else if (form.isJudgeable && rules.isNotEmpty) ...[
              const SizedBox(height: Spacing.md),
              _AllClear(
                  followed: evaluations
                      .where((e) => e.status == RuleStatus.passed)
                      .length),
            ],

            const SizedBox(height: Spacing.section),

            // --- Setup and checklist ------------------------------------
            const SectionHeader(title: 'Setup'),
            _StrategyPicker(form: form, strategies: strategies),
            if (applicableChecklist.isNotEmpty) ...[
              const SizedBox(height: Spacing.lg),
              _Checklist(
                items: applicableChecklist,
                completed: form.completedChecklistIds,
                onToggle: (id, selected) => ref
                    .read(tradeFormProvider.notifier)
                    .toggleChecklistItem(id, selected),
              ),
            ],

            const SizedBox(height: Spacing.section),

            // Tags and charts belong to the entry: they are what makes this
            // trade findable and readable later, and both were previously
            // folded away behind a toggle most people never opened.
            const SectionHeader(
              title: 'Tags',
              subtitle: 'Whatever you want to find these trades by later.',
            ),
            _TagSection(form: form),
            const SizedBox(height: Spacing.section),
            _AdvancedFields(form: form, onChanged: _update, part: 1),
            const SizedBox(height: Spacing.section),
            const SectionHeader(
              title: 'Charts',
              subtitle: 'The screenshot is what makes this readable in six '
                  'months.',
            ),
            ScreenshotStrip(
              attachmentIds: form.attachmentIds,
              onAdded: ref.read(tradeFormProvider.notifier).addAttachment,
              onRemoved: ref.read(tradeFormProvider.notifier).removeAttachment,
            ),

            const SizedBox(height: Spacing.section),

            // --- Part two: how it ended ---------------------------------
            const SectionHeader(
              title: '2 · Trade exited',
              subtitle: 'Fill this in when you are out. Until then the trade '
                  'stays open.',
            ),
            Row(
              children: [
                Expanded(
                  child: _NumberInput(
                    label: 'Exit',
                    hint: 'Price closed',
                    value: form.exitPrice,
                    onChanged: (v) => _update(form.copyWith(exitPrice: v)),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: _NumberInput(
                    label: 'Fees',
                    hint: 'Brokerage + taxes',
                    value: form.fees,
                    onChanged: (v) => _update(form.copyWith(fees: v)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: Spacing.section),

            // --- Part three: the part that makes it worth keeping -------
            const SectionHeader(
              title: '3 · Fully executed',
              subtitle: 'The reasoning at both ends and the verdict. This is '
                  'the part worth reading back.',
            ),
            _AdvancedFields(form: form, onChanged: _update, part: 3),

            if (_saveError != null) ...[
              const SizedBox(height: Spacing.lg),
              ErrorState(
                title: 'Could not save the trade',
                message: _saveError!,
                onRetry: _save,
              ),
            ],

            const SizedBox(height: Spacing.xl),
            FilledButton(
              onPressed: form.canSave && !_saving ? _save : null,
              child: Text(
                widget.editTradeId == null ? 'Save trade' : 'Save changes',
              ),
            ),
            if (!form.canSave) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                'A symbol, an entry price and a quantity are the minimum.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _update(TradeFormState next) =>
      ref.read(tradeFormProvider.notifier).set(next);

  /// Loads the trade being edited, once.
  void _maybeLoadExisting() {
    final id = widget.editTradeId;
    if (id == null || _loadedExisting) return;
    _loadedExisting = true;
    Future.microtask(() async {
      final trade = await ref.read(tradeRepositoryProvider).getTrade(id);
      if (trade != null && mounted) {
        ref.read(tradeFormProvider.notifier).load(trade);
      }
    });
  }

  Future<void> _save() async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final form = ref.read(tradeFormProvider);
      final checklist = (ref.read(checklistProvider).value ?? const [])
          .where((item) => item.appliesToStrategy(form.strategyId))
          .map((item) => item.id)
          .toList(growable: false);

      final existing = widget.editTradeId == null
          ? null
          : await ref
              .read(tradeRepositoryProvider)
              .getTrade(widget.editTradeId!);

      final trade = form.toTrade(
        userId: account.userId,
        accountId: account.id,
        dayKey: ref.read(todayKeyProvider),
        accountEquity:
            account.riskBaseEquity.isZero ? null : account.riskBaseEquity,
        presentedChecklistIds: checklist,
        now: ref.read(nowProvider)(),
        existingId: existing?.id,
        createdAtUtc: existing?.createdAtUtc,
        // Editing bumps the revision so downstream aggregates know to
        // recompute rather than trusting a cached figure (§17).
        revision: (existing?.revision ?? 0) + 1,
      );

      final blocking =
          TradeCalculator.validate(trade).where((i) => i.isBlocking);
      if (blocking.isNotEmpty) {
        setState(() => _saveError = blocking.first.message);
        return;
      }

      await ref.read(tradeRepositoryProvider).saveTrade(trade);

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      context.pop();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _saveError =
            'The trade could not be saved just now. It is still here — try '
                'again. ($error)');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// What the rules say about the trade as it stands.
///
/// Headed by severity rather than by a fixed accusation. "Against your rules"
/// is true of a trade that breaks a risk limit; it is not true of one that
/// simply has not had a stop typed in yet, and using the same words for both
/// is how a coaching tool turns into a nag people learn to ignore.
class _LiveRuleCheck extends StatelessWidget {
  final List<RuleEvaluation> violations;
  const _LiveRuleCheck({required this.violations});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final major = violations.any((v) => v.isMajorViolation);
    final tone = major ? colors.violation : colors.warning;

    return PrayanCard(
      borderColor: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                major
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded,
                size: Sizes.iconMd,
                color: tone,
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  major ? 'Against your rules' : 'Before you commit',
                  style: text.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          for (final violation in violations)
            RuleStatusTile(evaluation: violation, dense: true),
        ],
      ),
    );
  }
}

/// The other half of the same feedback: a trade that is inside the rules
/// should be told so. A tool that only ever speaks up to complain teaches
/// people to dread opening it.
class _AllClear extends StatelessWidget {
  final int followed;
  const _AllClear({required this.followed});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return PrayanCard(
      lift: CardLift.flat,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.md,
      ),
      child: Row(
        children: [
          Icon(Icons.verified_outlined,
              size: Sizes.iconMd, color: colors.compliant),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              followed == 0
                  ? 'Nothing broken so far.'
                  : 'Inside your rules — $followed checked.',
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The one part of a trade's status that cannot be inferred.
///
/// Everything else is derived: an exit price means the trade is closed, its
/// absence means it is open. But an empty entry price is equally "this is a
/// plan I have not acted on" and "I have not typed it yet", and only the user
/// knows which. So this is the single switch left, rather than the three-way
/// control that used to let the journal disagree with itself — a trade marked
/// Closed with no exit, or an exit typed under one still marked Open.
class _PlanOnlyToggle extends StatelessWidget {
  final TradeFormState form;
  final ValueChanged<TradeFormState> onChanged;

  const _PlanOnlyToggle({required this.form, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PrayanCard(
      lift: CardLift.flat,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.xs,
      ),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: form.isPlanOnly,
        onChanged: (value) => onChanged(form.copyWith(isPlanOnly: value)),
        title: const Text('This is a plan I have not taken'),
        subtitle: Text(
          'Kept out of your daily counts. Declining a setup is discipline, '
          'not activity.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colors.textSecondary),
        ),
      ),
    );
  }
}

class _NumberInput extends StatelessWidget {
  final String label;
  final String value;
  final String? helper;

  /// An example of the shape of the answer, shown until there is a real one.
  final String? hint;
  final ValueChanged<String> onChanged;

  const _NumberInput({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.hint,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        initialValue: value,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          // Six numeric boxes whose labels vanish the moment you type in them
          // is a form you have to remember rather than read. The label stays
          // put and an example sits inside until it is replaced.
          floatingLabelBehavior: FloatingLabelBehavior.always,
          hintText: hint,
          helperText: helper,
        ),
        onChanged: onChanged,
      );
}

/// The live risk readout: the numbers that decide whether to take the trade.
class _RiskPreview extends StatelessWidget {
  final TradeMetrics metrics;
  final Currency currency;

  const _RiskPreview({required this.metrics, required this.currency});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    // Three em-dashes in a box is not a readout, it is furniture. Until one of
    // these numbers exists, the card says what would make it exist instead.
    final hasAnything = metrics.plannedRisk != null ||
        metrics.plannedRewardRisk != null ||
        metrics.netPnl != null;
    if (!hasAnything) {
      return PrayanCard(
        lift: CardLift.flat,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        child: Row(
          children: [
            Icon(Icons.calculate_outlined,
                size: Sizes.iconMd, color: colors.textTertiary),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                'Entry, stop and quantity give you risk and R:R here.',
                style: text.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return PrayanCard(
      child: Row(
        children: [
          Expanded(
            child: _PreviewValue(
              label: 'Risk',
              value: Fmt.money(metrics.plannedRisk, currency),
              support: Fmt.percent(metrics.plannedRiskPercent),
            ),
          ),
          _Divider(color: colors.border),
          Expanded(
            child: _PreviewValue(
              label: 'Planned R:R',
              value: Fmt.rewardRisk(metrics.plannedRewardRisk),
              support: metrics.plannedRewardRisk == null
                  ? 'Needs a target'
                  : 'Planned',
            ),
          ),
          _Divider(color: colors.border),
          Expanded(
            child: _PreviewValue(
              label: 'Result',
              value: Fmt.r(metrics.realizedR),
              support: Fmt.money(metrics.netPnl, currency, showSign: true),
              valueColor: metrics.netPnl == null
                  ? null
                  : colors.forSign(metrics.netPnl!.signum),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: color);
}

class _PreviewValue extends StatelessWidget {
  final String label;
  final String value;
  final String support;
  final Color? valueColor;

  const _PreviewValue({
    required this.label,
    required this.value,
    required this.support,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Text(label.toUpperCase(),
            style: PrayanType.metricLabel(colors.textTertiary)),
        const SizedBox(height: Spacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style:
                PrayanType.metric(valueColor ?? colors.textPrimary, size: 18),
          ),
        ),
        const SizedBox(height: Spacing.xxs),
        Text(
          support,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: colors.textTertiary, letterSpacing: 0),
        ),
      ],
    );
  }
}

class _IssueList extends StatelessWidget {
  final List<ValidationIssue> issues;
  const _IssueList({required this.issues});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final blocking = issues.where((i) => i.isBlocking).toList();
    final cautions = issues.where((i) => !i.isBlocking).toList();

    return PrayanCard(
      borderColor: blocking.isEmpty ? colors.warning : colors.violation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final issue in [...blocking, ...cautions])
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    issue.isBlocking
                        ? Icons.error_outline_rounded
                        : Icons.info_outline_rounded,
                    size: Sizes.iconSm,
                    color: issue.isBlocking ? colors.violation : colors.warning,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      issue.message,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StrategyPicker extends ConsumerWidget {
  final TradeFormState form;
  final List<Strategy> strategies;

  const _StrategyPicker({required this.form, required this.strategies});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    if (strategies.isEmpty) {
      return Text(
        'No setups defined yet. Add them in Settings to use approved-setup '
        'rules.',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: colors.textTertiary),
      );
    }

    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final strategy in strategies)
          PrayanChoiceChip(
            label: strategy.name,
            selected: form.strategyId == strategy.id,
            icon: strategy.isApproved ? Icons.verified_outlined : null,
            onSelected: (selected) => ref.read(tradeFormProvider.notifier).set(
                  form.copyWith(strategyId: selected ? strategy.id : null),
                ),
          ),
      ],
    );
  }
}

class _Checklist extends StatelessWidget {
  final List<ChecklistItem> items;
  final Set<String> completed;
  final void Function(String id, bool selected) onToggle;

  const _Checklist({
    required this.items,
    required this.completed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final done = items.where((i) => completed.contains(i.id)).length;

    return PrayanCard(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.sm,
              Spacing.lg,
              Spacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Pre-trade checklist',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '$done/${items.length}',
                  style: PrayanType.figure(
                    done == items.length ? colors.compliant : colors.warning,
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
          for (final item in items)
            CheckboxListTile(
              value: completed.contains(item.id),
              onChanged: (value) => onToggle(item.id, value ?? false),
              title: Text(
                item.prompt,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: Spacing.sm),
            ),
        ],
      ),
    );
  }
}

class _TagSection extends ConsumerWidget {
  final TradeFormState form;
  const _TagSection({required this.form});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(tradeFormProvider.notifier);
    return TagEditor(
      tags: form.tags,
      suggestions: ref.watch(knownTagsProvider),
      onAdd: notifier.addTag,
      onRemove: notifier.removeTag,
    );
  }
}

/// The written half of a trade, rendered for one part of the method.
///
/// These fields used to sit together behind a "More details" toggle, which is
/// where they went to be ignored — and they are the half that turns a closed
/// position into something worth reading back. Split by part so each is asked
/// for at the moment it can be answered: how you felt and why you took it
/// belong to the entry, why you left and whether you would repeat it cannot be
/// answered until you are out.
class _AdvancedFields extends StatelessWidget {
  final TradeFormState form;
  final ValueChanged<TradeFormState> onChanged;

  /// 1 for the entry, 3 for the review.
  final int part;

  const _AdvancedFields({
    required this.form,
    required this.onChanged,
    required this.part,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Spacing.md),
        // First in the section, because it is the field most likely to be
        // filled in and the one the journal's search and filters already
        // depend on — they have been searching tags nothing could set.
        if (part == 1) ...[
          const SectionHeader(title: 'How did you feel before entering?'),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (final emotion in EmotionTag.values)
                PrayanChoiceChip(
                  label: emotion.label,
                  selected: form.emotionBefore == emotion,
                  selectedColor:
                      emotion.isElevatedRisk ? colors.warning : colors.accent,
                  onSelected: (_) =>
                      onChanged(form.copyWith(emotionBefore: emotion)),
                ),
            ],
          ),
          const SizedBox(height: Spacing.section),
          const SectionHeader(
            title: 'Why this trade?',
            subtitle: 'The single most useful thing you can record.',
          ),
          TextFormField(
            initialValue: form.entryReason,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'The setup, the level, why now.',
            ),
            onChanged: (value) => onChanged(form.copyWith(entryReason: value)),
          ),
        ],
        if (part == 3) ...[
          const SizedBox(height: Spacing.lg),
          TextFormField(
            initialValue: form.exitReason,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Why did you exit?',
            ),
            onChanged: (value) => onChanged(form.copyWith(exitReason: value)),
          ),
          const SizedBox(height: Spacing.lg),
          TextFormField(
            initialValue: form.managementNotes,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Trade management notes',
            ),
            onChanged: (value) =>
                onChanged(form.copyWith(managementNotes: value)),
          ),
          const SizedBox(height: Spacing.section),
          const SectionHeader(title: 'Instrument'),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<AssetClass>(
                  initialValue: form.assetClass,
                  decoration: const InputDecoration(labelText: 'Asset class'),
                  items: [
                    for (final asset in AssetClass.values)
                      DropdownMenuItem(value: asset, child: Text(asset.label)),
                  ],
                  onChanged: (value) => onChanged(
                      form.copyWith(assetClass: value ?? form.assetClass)),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: _NumberInput(
                  label: 'Multiplier',
                  value: form.multiplier,
                  helper: form.assetClass.usesContractMultiplier
                      ? 'Lot or contract size'
                      : null,
                  onChanged: (v) => onChanged(form.copyWith(multiplier: v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          DropdownButtonFormField<MarketSession>(
            initialValue: form.session,
            decoration: const InputDecoration(labelText: 'Session'),
            items: [
              for (final session in MarketSession.values)
                DropdownMenuItem(value: session, child: Text(session.label)),
            ],
            onChanged: (value) =>
                onChanged(form.copyWith(session: value ?? form.session)),
          ),
          const SizedBox(height: Spacing.section),
          const SectionHeader(title: 'Reflection'),
          Text(
            'Confidence: ${form.confidence ?? '—'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Slider(
            value: (form.confidence ?? 5).toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '${form.confidence ?? 5}',
            onChanged: (value) =>
                onChanged(form.copyWith(confidence: value.round())),
          ),
          const SizedBox(height: Spacing.md),
          DropdownButtonFormField<MistakeCategory>(
            initialValue: form.mistake,
            decoration: const InputDecoration(
              labelText: 'Was there a process mistake?',
            ),
            items: [
              for (final mistake in MistakeCategory.values)
                DropdownMenuItem(value: mistake, child: Text(mistake.label)),
            ],
            onChanged: (value) =>
                onChanged(form.copyWith(mistake: value ?? form.mistake)),
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            'Would you take this exact setup again?',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              PrayanChoiceChip(
                label: 'Yes',
                selected: form.wouldRepeat == true,
                onSelected: (_) => onChanged(form.copyWith(wouldRepeat: true)),
              ),
              const SizedBox(width: Spacing.sm),
              PrayanChoiceChip(
                label: 'No',
                selected: form.wouldRepeat == false,
                selectedColor: colors.warning,
                onSelected: (_) => onChanged(form.copyWith(wouldRepeat: false)),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          SwitchListTile(
            value: form.isImpulsive,
            onChanged: (value) => onChanged(form.copyWith(isImpulsive: value)),
            title: const Text('This was an impulsive entry'),
            subtitle: Text(
              'Honest self-reporting makes the analytics worth reading.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.textSecondary),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }
}
