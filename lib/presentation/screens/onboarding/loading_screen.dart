import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Side of the launcher mark on the loading screen, in logical pixels.
const double _logoExtent = 92;

/// Loading screen shown while the database is being seeded. Standalone
/// MaterialApp (renders before the themed router), so it carries the brand
/// theme itself for visual continuity with the redesign.
class LoadingScreen extends StatelessWidget {
  final String? error;
  final VoidCallback? onRetry;

  const LoadingScreen({super.key, this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: lightTheme(),
      darkTheme: darkTheme(),
      home: Scaffold(
        body: Center(
          child:
              error != null
                  ? SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.sizeOf(context).height - 64,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.cloud_off_rounded,
                              size: 64,
                              color: AppColors.heartsRed,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Course couldn’t load',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Bricolage Grotesque',
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(height: 1.45),
                            ),
                            if (onRetry != null) ...[
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: onRetry,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Try again'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                  : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration:
                            MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 850),
                        curve: Curves.elasticOut,
                        builder:
                            (context, value, child) => Transform.rotate(
                              angle: -.05 * (1 - value),
                              child: Transform.scale(
                                scale: .72 + (.28 * value),
                                child: Opacity(
                                  opacity: value.clamp(0, 1),
                                  child: child,
                                ),
                              ),
                            ),
                        child: const _LauncherMark(),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Czechify',
                        style: TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

/// The launcher icon, drawn the way the launcher draws it.
///
/// The first thing a learner sees on opening should be the mark they just
/// tapped. Getting that wrong is not subtle: Android 12 and later paint their
/// own splash from the adaptive icon and crop it to a circle, so a rounded
/// square here arrives a moment later and reads as a *second, different* logo
/// rather than the same one.
///
/// Android therefore gets the adaptive icon reassembled from its own two
/// layers, under the same geometry `ic_launcher.xml` declares — the foreground
/// inset by [_adaptiveInset], the canvas cropped to its safe zone — so the
/// shape, the padding and the size of the glyph all match what the system just
/// showed. iOS has no such splash and masks the single-image icon to a
/// superellipse, which a 24% corner radius approximates closely enough.
class _LauncherMark extends StatelessWidget {
  const _LauncherMark();

  /// The inset `mipmap-anydpi-v26/ic_launcher.xml` applies to the foreground.
  static const _adaptiveInset = .16;

  /// An adaptive icon is a 108dp canvas of which the launcher shows the middle
  /// 72dp; the rest is bleed for the system's mask and parallax.
  static const _safeZone = 72 / 108;

  @override
  Widget build(BuildContext context) {
    // Decoded at the size it is drawn. Without this the 1024px source is
    // resampled by the GPU on every frame of the entrance animation — wasteful,
    // and softer than a proper downscale.
    final decode =
        (_logoExtent / _safeZone * MediaQuery.devicePixelRatioOf(context))
            .round();

    if (defaultTargetPlatform != TargetPlatform.android) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_logoExtent * .24),
        child: Image.asset(
          'assets/images/app_icon.png',
          width: _logoExtent,
          height: _logoExtent,
          cacheWidth: decode,
          filterQuality: FilterQuality.medium,
        ),
      );
    }

    return ClipOval(
      child: SizedBox(
        width: _logoExtent,
        height: _logoExtent,
        // Scaling the full canvas up until its safe zone fills the circle is
        // what crops the bleed, exactly as the launcher's mask does.
        child: Transform.scale(
          scale: 1 / _safeZone,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/app_icon_background.png',
                fit: BoxFit.cover,
                cacheWidth: decode,
                filterQuality: FilterQuality.medium,
              ),
              FractionallySizedBox(
                widthFactor: 1 - (_adaptiveInset * 2),
                heightFactor: 1 - (_adaptiveInset * 2),
                child: Image.asset(
                  'assets/images/app_icon_foreground.png',
                  fit: BoxFit.contain,
                  cacheWidth: decode,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
