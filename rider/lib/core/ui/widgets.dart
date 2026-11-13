import 'package:flutter/material.dart';

import 'theme.dart';

/// Primary / outline button — same look as the customer app's Button.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool outline;
  final Color color;
  final IconData? icon;
  const AppButton(this.label, {super.key, this.onTap, this.loading = false, this.outline = false, this.color = brandGreen, this.icon});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    final fg = outline ? color : Colors.white;
    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: Material(
        color: outline ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? onTap : null,
          child: Container(
            height: 50,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: color, width: 2)),
            alignment: Alignment.center,
            child: loading
                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[Icon(icon, color: fg, size: 20), const SizedBox(width: 8)],
                    Text(label, style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w600)),
                  ]),
          ),
        ),
      ),
    );
  }
}

/// White rounded card used everywhere.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? context.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Outlined circular icon button (the customer app's notification bell style).
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool dot;
  final Color? color;
  const CircleIconButton(this.icon, {super.key, this.onTap, this.dot = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(shape: BoxShape.circle, color: context.card, border: Border.all(color: context.line, width: 1.5)),
          child: Icon(icon, size: 20, color: color ?? context.ink),
        ),
      ),
      if (dot)
        const Positioned(right: 3, top: 3, child: CircleAvatar(radius: 4.5, backgroundColor: Colors.red)),
    ]);
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Row(children: [
          Expanded(child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.ink))),
          if (trailing != null) trailing!,
        ]),
      );
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const StatusPill(this.label, {super.key, this.color = brandGreen});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: brandGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: brandGreen, size: 32),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.ink)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: inkGrey, height: 1.5)),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      );
}

/// Pickup ● → Drop-off ■ addresses, stacked with a connector line.
class RouteLines extends StatelessWidget {
  final String pickup;
  final String dropoff;
  final String? pickupLabel;
  final String? dropoffLabel;
  const RouteLines({super.key, required this.pickup, required this.dropoff, this.pickupLabel, this.dropoffLabel});

  @override
  Widget build(BuildContext context) {
    Widget row(Color c, bool square, String label, String text) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: square ? BoxShape.rectangle : BoxShape.circle, borderRadius: square ? BorderRadius.circular(2) : null)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 11, color: inkGrey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(text, style: TextStyle(fontSize: 14, color: context.ink, fontWeight: FontWeight.w600, height: 1.3)),
            ]),
          ),
        ]);
    return Column(children: [
      row(brandGreen, false, pickupLabel ?? 'PICKUP', pickup),
      Align(
        alignment: Alignment.centerLeft,
        child: Container(margin: const EdgeInsets.only(left: 5.5, top: 2, bottom: 2), width: 1.5, height: 18, color: context.line),
      ),
      row(dangerRed, true, dropoffLabel ?? 'DROP-OFF', dropoff),
    ]);
  }
}

/// Labelled text field in the app's style.
class AppField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboard;
  final int maxLines;
  final int? maxLength;
  final bool autofocus;
  final TextCapitalization caps;
  final ValueChanged<String>? onChanged;
  const AppField(this.label, this.controller, {super.key, this.hint, this.keyboard, this.maxLines = 1, this.maxLength, this.autofocus = false, this.caps = TextCapitalization.none, this.onChanged});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.ink)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: maxLines,
          maxLength: maxLength,
          autofocus: autofocus,
          textCapitalization: caps,
          onChanged: onChanged,
          style: TextStyle(fontSize: 15, color: context.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
            counterText: '',
            filled: true,
            fillColor: context.cs.secondary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: brandGreen, width: 1.5)),
          ),
        ),
      ]);
}

/// Simple top bar with a back button, matching the customer app's sub-screens.
PreferredSizeWidget appBar(BuildContext context, String title, {List<Widget>? actions}) => AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: context.ink,
      title: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.ink)),
      actions: actions,
    );
