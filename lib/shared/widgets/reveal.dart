import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/splash/splash_overlay.dart' show splashDoneProvider;

/// Fades and slides [child] up once, the first time it appears (after the
/// opening animation). It never replays while scrolling, and it shows
/// instantly when the phone asks for reduced motion or [enabled] is false.
class Reveal extends ConsumerStatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.enabled = true,
    this.startScale = 1.0,
  });

  final Widget child;
  final Duration delay;
  final bool enabled;

  /// Below 1.0 the child also grows slightly while it appears.
  final double startScale;

  @override
  ConsumerState<Reveal> createState() => _RevealState();
}

class _RevealState extends ConsumerState<Reveal>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 450);

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;
  ProviderSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    final total = _duration + widget.delay;
    _controller = AnimationController(vsync: this, duration: total);
    final begin = widget.delay.inMilliseconds / total.inMilliseconds;
    final eased = _controller.drive(
      CurveTween(curve: Interval(begin, 1.0, curve: Curves.easeOutCubic)),
    );
    _fade = eased;
    _slide = eased.drive(
      Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero),
    );
    _scale = eased.drive(Tween<double>(begin: widget.startScale, end: 1.0));

    final reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (!widget.enabled || reduceMotion) {
      _controller.value = 1;
      return;
    }
    _sub = ref.listenManual<bool>(splashDoneProvider, (previous, next) {
      if (next) _play();
    }, fireImmediately: true);
  }

  void _play() {
    _sub?.close();
    _sub = null;
    if (_controller.value == 0 && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _sub?.close();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget result = widget.child;
    if (widget.startScale != 1.0) {
      result = ScaleTransition(scale: _scale, child: result);
    }
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: result),
    );
  }
}
