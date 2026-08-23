import 'package:flutter/material.dart';

import '../palette.dart';
import '../tokens.dart';

/// Free-text tags, entered as chips.
///
/// Tags are the part of a journal that decays fastest. Left as a plain text
/// field they become a graveyard of near-duplicates — "fomo", "FOMO", "fomo
/// entry" — and the filter meant to group them splits them instead. Two things
/// prevent that here: what the user types is normalised before it is stored,
/// and tags already used are offered rather than retyped.
class TagEditor extends StatefulWidget {
  final List<String> tags;

  /// Previously used tags, most-used first. Ones already applied are filtered
  /// out by this widget.
  final List<String> suggestions;

  /// Called with the raw text; returns false when nothing was added — a
  /// duplicate, or something that normalised away to nothing — so the field
  /// can keep the text instead of swallowing it.
  final bool Function(String) onAdd;
  final ValueChanged<String> onRemove;

  const TagEditor({
    super.key,
    required this.tags,
    required this.suggestions,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    // A comma is how people separate tags without thinking about it, so it
    // works as a terminator as well as the keyboard's own submit.
    for (final part in raw.split(',')) {
      widget.onAdd(part);
    }
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final unused = widget.suggestions
        .where((s) => !widget.tags.contains(s))
        .take(8)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.tags.isNotEmpty) ...[
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (final tag in widget.tags)
                InputChip(
                  label: Text(tag),
                  onDeleted: () => widget.onRemove(tag),
                  deleteIconColor: colors.textSecondary,
                  // Named for a screen reader, which otherwise announces a
                  // bare X with no idea what it removes.
                  deleteButtonTooltipMessage: 'Remove $tag',
                  backgroundColor: colors.accentMuted,
                  side: BorderSide(color: colors.border),
                ),
            ],
          ),
          const SizedBox(height: Spacing.md),
        ],
        TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          onSubmitted: _submit,
          decoration: InputDecoration(
            labelText: 'Tags',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintText: 'news, revenge, a-plus setup',
            prefixIcon: const Icon(Icons.label_outline_rounded),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add tag',
              onPressed: () => _submit(_controller.text),
            ),
          ),
        ),
        if (unused.isNotEmpty) ...[
          const SizedBox(height: Spacing.sm),
          Text(
            'USED BEFORE',
            style: text.labelSmall?.copyWith(color: colors.textTertiary),
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (final suggestion in unused)
                ActionChip(
                  label: Text(suggestion),
                  onPressed: () => widget.onAdd(suggestion),
                  backgroundColor: colors.surface,
                  side: BorderSide(color: colors.border),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
