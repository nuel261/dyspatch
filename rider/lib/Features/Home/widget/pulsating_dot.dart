import 'package:flutter/material.dart';

/// A small circular dot that gently pulses (scale + fade) to signal an
/// "active/ongoing" state — used on the Online pill and active delivery
/// status pills (Heading to Pickup, At Pickup, Picked-up, In-transit,
/// Arrived, and Issue-while-active). Pass [isActive] = false for terminal
/// states (Offline, Delivered, Cancelled, Issue-on-completed-order) to
/// render a plain static dot instead.
class PulsatingDot extends StatefulWidget {
  final Color color;
  final double size;
  final bool isActive;

  const PulsatingDot({
    super.key,
    required this.color,
    this.size = 8,
    this.isActive = true,
  });

  @override
  State<PulsatingDot> createState() => _PulsatingDotState();
}

class _PulsatingDotState extends State<PulsatingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacity = Tween<double>(
      begin: 0.55,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant PulsatingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.2,
      height: widget.size * 2.2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding, fading ring — only shown while active.
          if (widget.isActive)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
          // Solid core dot — always visible, active or not.
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Delivery statuses that should pulsate — i.e. still "in motion" on the
/// order timeline. Delivered and Cancelled are terminal, so they're
/// intentionally excluded. "Issue" is handled separately by the caller
/// since whether it pulsates depends on whether the underlying order is
/// still active, not on the status string alone.
const Set<String> activePulsingStatuses = {
  'Heading to Pickup',
  'At Pickup',
  'Picked-up',
  'In Transit',
  'Arrived',
};

/// Call this from wherever a status pill is rendered to decide if its dot
/// should pulse. [isOrderActive] should be false once an order reaches a
/// terminal state (Delivered/Cancelled) — pass it in from whatever flag
/// your DeliveryModel already tracks for that.
bool shouldPulse(String status, {required bool isOrderActive}) {
  if (status == 'Issue') return isOrderActive;
  return isOrderActive && activePulsingStatuses.contains(status);
}
