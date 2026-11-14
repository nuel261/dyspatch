import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// One line under the popup title: optional leading icon + text, and an
/// optional right-aligned detail (e.g. "18 mins", "₦ 4,200").
class PopupLine {
  final String? icon;
  final String text;
  final String? trailingIcon;
  final String? trailingText;

  const PopupLine(this.text, {this.icon, this.trailingIcon, this.trailingText});
}

/// Popup/Single/* — the heads-up card that slides down from the top for
/// order events. Shown on the root overlay so it survives navigation
/// (e.g. reporting an issue and leaving the Track screen).
///
///   AppPopup.issue(context, detail: 'Customer notified');
class AppPopup {
  AppPopup._();

  static const _green = Color(0xFF34A853);
  static const _red = Color(0xFFD92D20);

  static OverlayEntry? _current;

  /// Popup/Single/New
  static void newOrder(
    BuildContext context, {
    required String route,
    required String merchant,
    required String items,
    required String amount,
    String? eta,
    VoidCallback? onTap,
  }) {
    show(
      context,
      icon: 'assets/images/ph_package.svg',
      iconColor: const Color(0xFF5A5858),
      iconBg: const Color(0xFFE3E7EB),
      title: route,
      lines: [
        PopupLine(
          merchant,
          icon: 'assets/images/ph_user.svg',
          trailingIcon: eta == null ? null : 'assets/images/ph_clock.svg',
          trailingText: eta,
        ),
        PopupLine(
          items,
          icon: 'assets/images/ph_package.svg',
          trailingText: amount,
        ),
      ],
      onTap: onTap,
    );
  }

  /// Popup/Single/Delivered
  static void delivered(
    BuildContext context, {
    required String route,
    required String merchant,
    required String amount,
    VoidCallback? onTap,
  }) {
    show(
      context,
      icon: 'assets/images/ph_checks.svg',
      iconColor: _green,
      iconBg: const Color(0xFFEAF6ED),
      title: route,
      lines: [
        PopupLine(merchant, icon: 'assets/images/ph_user.svg'),
        PopupLine('$amount has been added to your wallet'),
      ],
      onTap: onTap,
    );
  }

  /// Popup/Single/Issue, or Popup/Fleet/Issue when [ride] is set.
  static void issue(
    BuildContext context, {
    String detail = 'Customer notified',
    String? ride,
    VoidCallback? onTap,
  }) {
    show(
      context,
      icon: 'assets/images/ph_warning.svg',
      iconColor: _red,
      iconBg: const Color(0xFFFDE8EA),
      title: ride == null ? 'Issue reported' : 'Issue reported • $ride',
      lines: [PopupLine(detail, icon: 'assets/images/ph_user.svg')],
      onTap: onTap,
    );
  }

  /// Popup/Single/Cancelled
  static void cancelled(
    BuildContext context, {
    String status = 'Cancelled by Sender!',
    String? compensation,
    VoidCallback? onTap,
  }) {
    show(
      context,
      icon: 'assets/images/ph_x.svg',
      iconColor: Colors.white,
      iconBg: const Color(0xFF5A5858),
      title: 'Delivery Cancelled',
      lines: [
        PopupLine('Status: $status'),
        if (compensation != null)
          PopupLine('$compensation compensation has been added to your wallet.'),
      ],
      onTap: onTap,
    );
  }

  /// Shows a popup, replacing any one already on screen.
  static void show(
    BuildContext context, {
    required String icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    List<PopupLine> lines = const [],
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    dismiss();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _PopupHost(
        duration: duration,
        onClosed: () {
          if (_current == entry) _current = null;
          entry.remove();
        },
        onTap: onTap,
        child: _PopupCard(
          icon: icon,
          iconColor: iconColor,
          iconBg: iconBg,
          title: title,
          lines: lines,
        ),
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  /// Removes the popup on screen right away (no exit animation).
  static void dismiss() {
    _current?.remove();
    _current = null;
  }
}

/// Slides the card in from the top, waits, slides it out. Tap runs
/// [onTap]; swiping up dismisses early.
class _PopupHost extends StatefulWidget {
  final Duration duration;
  final VoidCallback onClosed;
  final VoidCallback? onTap;
  final Widget child;

  const _PopupHost({
    required this.duration,
    required this.onClosed,
    required this.onTap,
    required this.child,
  });

  @override
  State<_PopupHost> createState() => _PopupHostState();
}

class _PopupHostState extends State<_PopupHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, -1.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    await _controller.reverse();
    widget.onClosed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: () {
            widget.onTap?.call();
            _close();
          },
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < 0) _close();
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class _PopupCard extends StatelessWidget {
  final String icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final List<PopupLine> lines;

  const _PopupCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Same card colours as the snackbar theme.
    final cardBg = isDark ? const Color(0xFF2E3238) : Colors.white;
    final textColor = isDark ? const Color(0xFFE0E0E0) : const Color(0xFF0E0F10);
    final muted = isDark ? Colors.grey.shade400 : const Color(0xFF5A5858);

    return Material(
      color: cardBg,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: SvgPicture.asset(
                icon,
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'now',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                  for (final line in lines) ...[
                    const SizedBox(height: 6),
                    _line(line, textColor),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(PopupLine line, Color color) {
    final style = TextStyle(
      fontFamily: 'Montserrat',
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: color,
    );
    Widget icon(String path) => Padding(
      padding: const EdgeInsets.only(right: 4),
      child: SvgPicture.asset(
        path,
        width: 12,
        height: 12,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );

    return Row(
      children: [
        if (line.icon != null) icon(line.icon!),
        Expanded(
          child: Text(
            line.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (line.trailingIcon != null) icon(line.trailingIcon!),
        if (line.trailingText != null) Text(line.trailingText!, style: style),
      ],
    );
  }
}
