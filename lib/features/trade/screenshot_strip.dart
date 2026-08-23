import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../domain/repositories.dart';
import '../../state/providers.dart';

/// Chart screenshots attached to a trade.
///
/// A journal entry that says "broke out of the range" is worth a fraction of
/// one with the chart beside it — the screenshot is what makes a review months
/// later mean anything.
///
/// Images are downscaled and re-encoded before they are stored, and the count
/// is capped. Attachments live in the same local store as everything else,
/// which is a preferences file: a raw phone screenshot is two or three
/// megabytes, base64 inflates that by a third, and a handful of them would
/// turn every read of that file into a stall. What is kept is large enough to
/// read a chart and small enough that the journal stays quick.
class ScreenshotStrip extends ConsumerStatefulWidget {
  final List<String> attachmentIds;
  final ValueChanged<String> onAdded;
  final ValueChanged<String> onRemoved;

  /// More than this and the store is being used as a photo library.
  static const maxPerTrade = 6;

  /// Long edge, in pixels. A chart is still legible; the file is not huge.
  static const maxDimension = 1600.0;

  /// JPEG quality. Charts are flat colour and survive this well.
  static const quality = 72;

  const ScreenshotStrip({
    super.key,
    required this.attachmentIds,
    required this.onAdded,
    required this.onRemoved,
  });

  @override
  ConsumerState<ScreenshotStrip> createState() => _ScreenshotStripState();
}

class _ScreenshotStripState extends ConsumerState<ScreenshotStrip> {
  bool _busy = false;
  String? _error;

  Future<void> _add() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: ScreenshotStrip.maxDimension,
        maxHeight: ScreenshotStrip.maxDimension,
        imageQuality: ScreenshotStrip.quality,
      );
      if (picked == null) return; // Cancelled, which is not an error.

      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;

      final id = await ref.read(attachmentRepositoryProvider).upload(
            userId,
            await picked.readAsBytes(),
            filename: picked.name,
            contentType: picked.mimeType ?? 'image/jpeg',
          );
      widget.onAdded(id);
    } on RepositoryException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      // A picker that is unavailable or denied must not look like a crash.
      if (mounted) {
        setState(() => _error =
            'Could not open your photos. Check the app has permission.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String id) async {
    widget.onRemoved(id);
    // Drop the stored bytes too — an orphaned attachment is dead weight in a
    // store that is already the wrong shape for images.
    await ref.read(attachmentRepositoryProvider).delete(id);
    ref.invalidate(attachmentBytesProvider(id));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final full = widget.attachmentIds.length >= ScreenshotStrip.maxPerTrade;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final id in widget.attachmentIds)
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.sm),
                  child: _Thumbnail(
                    id: id,
                    onRemove: () => _remove(id),
                    onOpen: () => _open(context, id),
                  ),
                ),
              if (!full)
                _AddButton(busy: _busy, onPressed: _busy ? null : _add),
            ],
          ),
        ),
        if (full) ...[
          const SizedBox(height: Spacing.sm),
          Text(
            'That is ${ScreenshotStrip.maxPerTrade} images — enough for one '
            'trade. Remove one to add another.',
            style: text.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: Spacing.sm),
          Text(
            _error!,
            style: text.bodySmall?.copyWith(color: colors.violation),
          ),
        ],
      ],
    );
  }

  void _open(BuildContext context, String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenImage(id: id),
        fullscreenDialog: true,
      ),
    );
  }
}

class _Thumbnail extends ConsumerWidget {
  final String id;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  const _Thumbnail({
    required this.id,
    required this.onRemove,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final bytes = ref.watch(attachmentBytesProvider(id));

    return Stack(
      children: [
        InkWell(
          onTap: onOpen,
          borderRadius: Radii.field,
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: Radii.field,
              border: Border.all(color: colors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: bytes.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, __) =>
                  Icon(Icons.broken_image_outlined, color: colors.textTertiary),
              data: (data) => data == null
                  ? Icon(Icons.broken_image_outlined,
                      color: colors.textTertiary)
                  : Image.memory(data, fit: BoxFit.cover),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: Material(
            color: colors.scrim,
            shape: const CircleBorder(),
            child: IconButton(
              iconSize: Sizes.iconSm,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              tooltip: 'Remove screenshot',
              onPressed: onRemove,
            ),
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;

  const _AddButton({required this.busy, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onPressed,
      borderRadius: Radii.field,
      child: Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          color: colors.accentMuted,
          borderRadius: Radii.field,
          border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
        ),
        child: busy
            ? const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: colors.accent),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'Add chart',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: colors.accent),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A screenshot at full size, pinch-zoomable.
class _FullScreenImage extends ConsumerWidget {
  final String id;
  const _FullScreenImage({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(attachmentBytesProvider(id));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Screenshot'),
      ),
      body: Center(
        child: bytes.when(
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Text(
            'This screenshot could not be read.',
            style: TextStyle(color: Colors.white),
          ),
          data: (data) => data == null
              ? const Text(
                  'This screenshot could not be read.',
                  style: TextStyle(color: Colors.white),
                )
              : InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Image.memory(data),
                ),
        ),
      ),
    );
  }
}
