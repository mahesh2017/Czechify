import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/entities/exercise.dart';

/// A lesson illustration that arrives rather than snaps.
///
/// The art runs to ~1 MB a file, which is a decode no widget can finish inside
/// the frame that asks for it: a bare [Image.asset] paints nothing until the
/// bytes land, then appears at full strength. Because exercises enter through
/// [MotionEntrance], the card would slide in with a hole where the picture goes
/// and the picture would land after it settled.
///
/// Two things close that. [precacheFor] warms the exercise ahead while the
/// learner is still reading the current one, so the common case is decoded
/// before it is asked for; anything that still misses fades up over a
/// placeholder instead of appearing out of nothing.
class LessonImage extends StatelessWidget {
  const LessonImage({
    super.key,
    required this.asset,
    this.aspectRatio,
    this.height,
    this.semanticLabel,
    this.borderRadius = 24,
  }) : assert(
         (aspectRatio == null) != (height == null),
         'Give the frame a shape exactly one way: an aspect ratio or a height.',
       );

  final String asset;

  /// Shape the frame by ratio. Mutually exclusive with [height].
  final double? aspectRatio;

  /// Shape the frame by a fixed height, full width. Mutually exclusive with
  /// [aspectRatio].
  final double? height;

  final String? semanticLabel;
  final double borderRadius;

  /// Decode width in physical pixels, shared by display and by [precacheFor].
  ///
  /// It has to be one number. [Image.asset] with a `cacheWidth` resolves
  /// through a [ResizeImage], whose cache key includes that width — warming
  /// 1024 and then displaying at 880 would decode the file twice and warm
  /// nothing. 1024 covers a full-bleed image on a 3x phone.
  static const decodeWidth = 1024;

  /// The illustration [exercise] will show, if it has one.
  ///
  /// Four exercise types carry it as `data['image']`; image-card teaching
  /// exercises carry one per item, and the first is what the learner meets on
  /// arrival.
  static String? assetFor(Exercise exercise) {
    final direct = (exercise.data['image'] as String?)?.trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final items = exercise.data['items'];
    if (items is List) {
      for (final item in items) {
        if (item is! Map) continue;
        final image = (item['image'] as String?)?.trim();
        if (image != null && image.isNotEmpty) return image;
      }
    }
    return null;
  }

  /// Decodes [exercise]'s illustration ahead of it being shown.
  ///
  /// Silent on failure by design: this is a head start, and a missing or
  /// malformed asset must surface where it is displayed — with the error
  /// builder the learner can actually see — not as an exception thrown from a
  /// warm-up the exercise never asked for.
  static Future<void> precacheFor(
    BuildContext context,
    Exercise? exercise,
  ) async {
    if (exercise == null) return;
    final asset = assetFor(exercise);
    if (asset == null) return;
    await precacheImage(
      ResizeImage(AssetImage(asset), width: decodeWidth),
      context,
      onError: (_, __) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final image = ColoredBox(
      // The frame below already fixes the size, so nothing moves when the
      // picture lands — only the hole fills in.
      color: t.priSoft,
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        cacheWidth: decodeWidth,
        semanticLabel: semanticLabel,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          // Warmed, or seen before: show it outright. Fading an image that
          // was ready would add a delay the learner did not have before.
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: context.motionDuration(AppMotion.content),
            curve: AppMotion.enter,
            child: child,
          );
        },
        errorBuilder:
            (context, error, stack) => Center(
              child: Icon(Icons.image_not_supported_outlined, color: t.faint),
            ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child:
          height != null
              ? SizedBox(height: height, width: double.infinity, child: image)
              : AspectRatio(aspectRatio: aspectRatio!, child: image),
    );
  }
}
