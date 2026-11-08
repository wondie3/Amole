import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/amole_wordmark.dart';

/// True once the opening animation has mostly finished. Home waits for this
/// before playing its own entrance, so the two never overlap.
class SplashDoneNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void finish() {
    if (!state) state = true;
  }
}

final splashDoneProvider = NotifierProvider<SplashDoneNotifier, bool>(
  SplashDoneNotifier.new,
);

/// Plays the opening animation on top of the app, once per launch. The app is
/// built underneath it from the first frame, so nothing is delayed.
///
/// The animation advances by at most [_maxStepMicros] per frame. If the phone
/// is slow at start-up (common in debug builds), a few long frames therefore
/// cannot skip the whole animation.
class SplashOverlay extends ConsumerStatefulWidget {
  const SplashOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends ConsumerState<SplashOverlay>
    with TickerProviderStateMixin {
  static const double _riderWidth = 280;
  static const double _laneHeight = 190;
  static const String _riderAsset = 'assets/images/splash/rider.png';
  static const int _totalMicros = 3400000;
  static const int _maxStepMicros = 50000;

  // Only holds the animation position. It is driven by [_ticker], never by
  // forward(), so the per-frame clamp always applies.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(microseconds: _totalMicros),
  );
  late final Ticker _ticker = createTicker(_onTick);
  late final Animation<double> _logo = _controller.drive(
    CurveTween(curve: const Interval(0.0, 0.2, curve: Curves.easeOutCubic)),
  );
  late final Animation<double> _logoScale = _logo.drive(
    Tween<double>(begin: 0.9, end: 1.0),
  );
  late final Animation<double> _tagline = _controller.drive(
    CurveTween(curve: const Interval(0.1, 0.3, curve: Curves.easeOut)),
  );
  late final Animation<double> _rider = _controller.drive(
    CurveTween(curve: const Interval(0.22, 0.88, curve: Curves.easeInOutSine)),
  );
  late final Animation<double> _fadeOut = _controller
      .drive(CurveTween(curve: const Interval(0.9, 1.0)))
      .drive(Tween<double>(begin: 1.0, end: 0.0));

  Duration _lastElapsed = Duration.zero;
  int _progressMicros = 0;
  bool _started = false;
  bool _signaled = false;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _done = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(splashDoneProvider.notifier).finish();
      });
      return;
    }
    _controller.addListener(_checkSignal);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && !_done) {
        ref.read(splashDoneProvider.notifier).finish();
        setState(() => _done = true);
      }
    });
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final step = (elapsed - _lastElapsed).inMicroseconds;
    _lastElapsed = elapsed;
    _progressMicros += math.min(step, _maxStepMicros);
    if (_progressMicros >= _totalMicros) {
      _ticker.stop();
      _controller.value = 1.0;
    } else {
      _controller.value = _progressMicros / _totalMicros;
    }
  }

  void _checkSignal() {
    if (!_signaled && _controller.value >= 0.85) {
      _signaled = true;
      ref.read(splashDoneProvider.notifier).finish();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _splash() {
    final riderImage = ExcludeSemantics(
      child: Image.asset(
        _riderAsset,
        width: _riderWidth,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stack) => const Icon(
          Icons.delivery_dining,
          size: 96,
          color: AppColors.forest,
        ),
      ),
    );
    return Material(
      key: const Key('splash_overlay'),
      color: AppColors.cream,
      child: Center(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _logo,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: const AmoleWordmark(fontSize: 56),
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _tagline,
                child: const Text(
                  'Good food, delivered.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: _laneHeight,
                child: ClipRect(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return AnimatedBuilder(
                        animation: _controller,
                        child: riderImage,
                        builder: (context, child) {
                          final x =
                              -_riderWidth +
                              (constraints.maxWidth + _riderWidth) *
                                  _rider.value;
                          final bob =
                              math.sin(_controller.value * 2 * math.pi * 14) *
                              1.5;
                          return Transform.translate(
                            offset: Offset(x, bob),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: child,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.expand,
      children: [
        // The app is always the first child, so it is never rebuilt from
        // scratch when the overlay goes away.
        widget.child,
        if (!_done) FadeTransition(opacity: _fadeOut, child: _splash()),
      ],
    );
  }
}
