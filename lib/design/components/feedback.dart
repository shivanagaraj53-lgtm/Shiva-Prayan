import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../palette.dart';
import '../tokens.dart';
import 'surfaces.dart';

/// An empty state: an illustration mark, a heading, an explanation and — where
/// it makes sense — one action.
///
/// The brief asks for "beautiful empty states" (§2) and enumerates the states
/// that must exist (§26). Every one of them routes through this widget so a
/// first-run screen never looks like a broken screen.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Spacing.xl,
        vertical: compact ? Spacing.xl : Spacing.xxxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 48 : 64,
            height: compact ? 48 : 64,
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: BorderRadius.circular(Radii.lg),
            ),
            child: Icon(
              icon,
              size: compact ? Sizes.iconLg : 30,
              color: colors.textTertiary,
            ),
          ),
          SizedBox(height: compact ? Spacing.md : Spacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: compact ? text.titleMedium : text.headlineSmall,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Spacing.xl),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// An inline error with a retry path.
///
/// Never renders a raw exception (§26). Callers map failures to a sentence a
/// trader would understand before they reach this widget.
class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return PrayanCard(
      borderColor: colors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: Sizes.iconMd, color: colors.warning),
              const SizedBox(width: Spacing.sm),
              Expanded(child: Text(title, style: text.titleMedium)),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            message,
            style: text.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: Spacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}

/// A shimmering placeholder block used while content loads.
///
/// Skeletons are preferred to spinners for content that has a known shape:
/// the page does not jump when data arrives.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(Radii.xs)),
  });

  /// A full card-sized placeholder.
  const Skeleton.card({super.key})
      : width = double.infinity,
        height = Sizes.cardMinHeight,
        borderRadius = Radii.card;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Loading.shimmerPeriod,
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // With reduced motion on, hold a static placeholder rather than pulsing.
    final animate = !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = animate ? _controller.value : 0.5;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Color.lerp(
                colors.surfaceSunken,
                colors.border,
                t * 0.6,
              ),
              borderRadius: widget.borderRadius,
            ),
          );
        },
      ),
    );
  }
}

/// A banner shown while offline or while writes are queued.
///
/// Deliberately calm: "shown clear sync status without alarming the user"
/// (§19). Offline is a normal state for a mobile journal, not an error.
class SyncBanner extends StatelessWidget {
  final int pendingCount;
  final bool isOffline;

  const SyncBanner({
    super.key,
    required this.pendingCount,
    required this.isOffline,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline && pendingCount == 0) return const SizedBox.shrink();

    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    final message = isOffline
        ? (pendingCount > 0
            ? 'Offline. $pendingCount ${pendingCount == 1 ? 'entry is' : 'entries are'} saved on this device and will sync automatically.'
            : 'Offline. Your journal is saved on this device.')
        : 'Syncing $pendingCount ${pendingCount == 1 ? 'entry' : 'entries'}…';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: Radii.field,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(
            isOffline ? Icons.cloud_off_rounded : Icons.sync_rounded,
            size: Sizes.iconSm,
            color: colors.textSecondary,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              message,
              style: text.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal confirmation for a destructive or irreversible action.
///
/// Returns `true` only on explicit confirmation. [destructive] paints the
/// action in the violation colour and is used for deleting a trade or an
/// account.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final colors = context.colors;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.page,
          Spacing.sm,
          Spacing.page,
          Spacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: Spacing.sm),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: Spacing.xl),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: colors.violation,
                      foregroundColor: colors.onAccent,
                    )
                  : null,
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop(true);
              },
              child: Text(confirmLabel),
            ),
            const SizedBox(height: Spacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
