import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Everything a rider can report mid-delivery (Issues_After_Array).
/// `fallbackIcon` is drawn until `icon` is exported into assets/images.
enum IssueReason {
  wrongPickupAddress('Wrong pickup address', 'ph_map-pin-user', 'ph_map-pin'),
  recipientNotReachable('Recipient not reachable', 'ph_phone-x', 'ph_phone-call'),
  recipientUnavailable('Recipient unavailable', 'ph_x'),
  heavyTraffic('Heavy traffic', 'ph_traffic-signal', 'ph_clock'),
  navigationProblem('Navigation problem', 'ph_map-trifold'),
  vehicleIssues('Vehicle issues', 'ph_traffic-cone', 'ph_warning'),
  packageIssues('Package issues', 'ph_package'),
  deliveryRefused('Delivery refused', 'ph_warning'),
  cannotAccessLocation('Cannot access location', 'ph_map-pin-slash', 'ph_map-pin'),
  timeout('Timeout', 'ph_clock'),
  emergency('Emergency / Safety issues', 'ph_warning-circle'),
  appMalfunction('App malfunction', 'ph_gear-six', 'ph_gear'),
  wrongOrderAssigned('Wrong order assigned', 'ph_shopping-cart', 'ph_package'),
  contactSupport('Contact support', 'ph_headset');

  final String label;
  final String icon;
  final String? fallbackIcon;

  const IssueReason(this.label, this.icon, [this.fallbackIcon]);

  /// The sections of the sheet, top to bottom.
  static const List<List<IssueReason>> groups = [
    [wrongPickupAddress, recipientNotReachable, recipientUnavailable],
    [heavyTraffic, navigationProblem, vehicleIssues],
    [packageIssues, deliveryRefused],
    [cannotAccessLocation, timeout],
    [emergency, appMalfunction, wrongOrderAssigned, contactSupport],
  ];
}

/// What the rider chose: a [reason], or Cancel Ride ([cancelRide] true).
class IssueSheetResult {
  final IssueReason? reason;
  final bool cancelRide;

  const IssueSheetResult.reason(IssueReason this.reason) : cancelRide = false;
  const IssueSheetResult.cancel() : reason = null, cancelRide = true;
}

/// Opens the report-an-issue sheet. Resolves to null if dismissed.
Future<IssueSheetResult?> showReportIssueSheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<IssueSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? const Color(0xFF23262B) : const Color(0xFFF5F5F5),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    builder: (_) => const _ReportIssueSheet(),
  );
}

class _ReportIssueSheet extends StatelessWidget {
  const _ReportIssueSheet();

  static const _red = Color(0xFFE5202E);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFE0E0E0) : const Color(0xFF0E0F10);
    final dividerColor = isDark
        ? const Color(0xFF2E3238)
        : const Color(0xFFE3E7EB);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Container(
              width: 120,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2E3238)
                    : const Color(0xFFD6DADE),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                children: [
                  for (final group in IssueReason.groups) ...[
                    for (var i = 0; i < group.length; i++)
                      _reasonRow(
                        context,
                        group[i],
                        textColor: textColor,
                        // Lines sit between rows, not under a section's last.
                        divider: i < group.length - 1 ? dividerColor : null,
                      ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  _cancelRideButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reasonRow(
    BuildContext context,
    IssueReason reason, {
    required Color textColor,
    Color? divider,
  }) {
    final filter = ColorFilter.mode(textColor, BlendMode.srcIn);
    Widget icon(String name) => SvgPicture.asset(
      'assets/images/$name.svg',
      width: 16,
      height: 16,
      colorFilter: filter,
    );

    return InkWell(
      onTap: () => Navigator.pop(context, IssueSheetResult.reason(reason)),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: divider == null
              ? null
              : Border(bottom: BorderSide(color: divider, width: 1)),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/images/${reason.icon}.svg',
              width: 16,
              height: 16,
              colorFilter: filter,
              errorBuilder: reason.fallbackIcon == null
                  ? null
                  : (_, _, _) => icon(reason.fallbackIcon!),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reason.label,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cancelRideButton(BuildContext context) {
    return Material(
      color: const Color(0xFFEDB6BA),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.pop(context, const IssueSheetResult.cancel()),
        child: const SizedBox(
          width: 136,
          height: 32,
          child: Center(
            child: Text(
              'Cancel Ride',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _red,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
