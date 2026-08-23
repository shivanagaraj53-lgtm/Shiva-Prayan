import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../design/components/feedback.dart';
import '../../design/components/surfaces.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';

/// Your setups, and the questions each one asks you.
///
/// Setups could only ever be created during onboarding — after that there was
/// no way to add one, rename one or retire one, which is a strange thing to
/// tell someone whose trading changes. This is that screen, and it is also
/// where note templates live, because a template belongs to the setup it is
/// for rather than to a global list nobody maintains.
class SetupsScreen extends ConsumerWidget {
  const SetupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strategies =
        ref.watch(strategiesProvider).value ?? const <Strategy>[];
    final live = strategies.where((s) => !s.isArchived).toList();
    final retired = strategies.where((s) => s.isArchived).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Setups')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New setup'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.page,
          Spacing.lg,
          Spacing.page,
          Spacing.scrollBottom,
        ),
        children: [
          if (live.isEmpty && retired.isEmpty)
            const PrayanCard(
              padding: EdgeInsets.zero,
              child: EmptyState(
                compact: true,
                icon: Icons.category_outlined,
                title: 'No setups yet',
                message: 'A setup is the pattern you trade. Naming them is '
                    'what lets the journal tell you which one actually works.',
              ),
            ),
          for (final strategy in live)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: _SetupCard(
                strategy: strategy,
                onTap: () => _edit(context, ref, strategy),
              ),
            ),
          if (retired.isNotEmpty) ...[
            const SizedBox(height: Spacing.section),
            const SectionHeader(
              title: 'Retired',
              subtitle: 'Kept so old trades keep their history.',
            ),
            for (final strategy in retired)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: _SetupCard(
                  strategy: strategy,
                  onTap: () => _edit(context, ref, strategy),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Strategy? existing,
  ) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final result = await showModalBottomSheet<Strategy>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SetupEditor(
        strategy: existing ??
            Strategy(
              id: 'strategy_${DateTime.now().microsecondsSinceEpoch}',
              userId: userId,
              name: '',
            ),
        isNew: existing == null,
      ),
    );
    if (result != null) {
      await ref.read(strategyRepositoryProvider).saveStrategy(result);
    }
  }
}

class _SetupCard extends StatelessWidget {
  final Strategy strategy;
  final VoidCallback onTap;

  const _SetupCard({required this.strategy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final templates = [
      if ((strategy.entryPrompt ?? '').trim().isNotEmpty) 'entry',
      if ((strategy.exitPrompt ?? '').trim().isNotEmpty) 'exit',
    ];

    return PrayanCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(strategy.name, style: text.titleMedium),
                    ),
                    if (!strategy.isApproved) ...[
                      const SizedBox(width: Spacing.sm),
                      // Approval is what an `approvedStrategyOnly` rule
                      // measures, so it has to be visible here rather than
                      // discovered when a trade is marked as breaking it.
                      _Pill(label: 'Not approved', color: colors.warning),
                    ],
                  ],
                ),
                const SizedBox(height: Spacing.xxs),
                Text(
                  templates.isEmpty
                      ? 'No note template'
                      : 'Template for ${templates.join(' and ')}',
                  style: text.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xxs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: Radii.chip,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      );
}

class _SetupEditor extends StatefulWidget {
  final Strategy strategy;
  final bool isNew;

  const _SetupEditor({required this.strategy, required this.isNew});

  @override
  State<_SetupEditor> createState() => _SetupEditorState();
}

class _SetupEditorState extends State<_SetupEditor> {
  late final _name = TextEditingController(text: widget.strategy.name);
  late final _entry =
      TextEditingController(text: widget.strategy.entryPrompt ?? '');
  late final _exit =
      TextEditingController(text: widget.strategy.exitPrompt ?? '');
  late bool _approved = widget.strategy.isApproved;
  late bool _archived = widget.strategy.isArchived;

  @override
  void dispose() {
    _name.dispose();
    _entry.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: Spacing.page,
        right: Spacing.page,
        top: Spacing.lg,
        // Clears the keyboard, which otherwise sits on top of the field the
        // user is typing into.
        bottom: MediaQuery.viewInsetsOf(context).bottom + Spacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isNew ? 'New setup' : 'Edit setup',
              style: text.headlineSmall,
            ),
            const SizedBox(height: Spacing.lg),
            TextField(
              controller: _name,
              autofocus: widget.isNew,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Opening range break',
              ),
            ),
            const SizedBox(height: Spacing.section),
            Text('Note templates', style: text.titleMedium),
            const SizedBox(height: Spacing.xxs),
            Text(
              'These fill the notes on a new trade of this setup, so you '
              'answer the same questions every time instead of staring at an '
              'empty box.',
              style: text.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: Spacing.lg),
            TextField(
              controller: _entry,
              maxLines: 5,
              minLines: 3,
              decoration: const InputDecoration(
                labelText: 'Before entering',
                alignLabelWithHint: true,
                hintText: 'Trigger:\nInvalidation:\nWhy now:',
              ),
            ),
            const SizedBox(height: Spacing.lg),
            TextField(
              controller: _exit,
              maxLines: 5,
              minLines: 3,
              decoration: const InputDecoration(
                labelText: 'After exiting',
                alignLabelWithHint: true,
                hintText: 'What ended it:\nDid I follow the plan:',
              ),
            ),
            const SizedBox(height: Spacing.section),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _approved,
              onChanged: (v) => setState(() => _approved = v),
              title: const Text('Approved setup'),
              subtitle: Text(
                'Only approved setups satisfy an "approved setups only" rule.',
                style: text.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ),
            if (!widget.isNew)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _archived,
                onChanged: (v) => setState(() => _archived = v),
                title: const Text('Retired'),
                subtitle: Text(
                  'Hidden when logging. Old trades keep it, so your history '
                  'stays intact.',
                  style: text.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ),
            const SizedBox(height: Spacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: _name.text.trim().isEmpty ? null : _save,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    String? template(TextEditingController c) {
      final value = c.text.trim();
      return value.isEmpty ? null : value;
    }

    Navigator.of(context).pop(
      widget.strategy.copyWith(
        name: _name.text.trim(),
        isApproved: _approved,
        isArchived: _archived,
        entryPrompt: template(_entry),
        exitPrompt: template(_exit),
      ),
    );
  }
}
