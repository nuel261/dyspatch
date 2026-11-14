import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Features/Home/widget/report_issue_sheet.dart';

import '../../Features/Home/Screen/view/scan_screen.dart';
import '../../Features/Home/widget/app_bottom_sheet.dart';
import '../../Features/Home/widget/app_popup.dart';
import '../../Features/onboarding/utils/snack.dart';
import '../api/order_view.dart';
import '../api/rider_api.dart';
import 'location_service.dart';
import 'rider_state.dart';

/// Moves an active order one step along, talking to the backend:
///
///   matched ──(pickup code)──▶ picked_up ──▶ en_route ──▶ arrived
///   ──(delivery code)──▶ delivered
class OrderActions {
  static final Set<int> _busy = {};

  /// Runs the next step for [order]. Returns the updated order, or null if
  /// the rider backed out or the step failed (an error is shown).
  static Future<Map<String, dynamic>?> advance(BuildContext context, Map<String, dynamic> order) async {
    final id = (order['id'] as num).toInt();
    if (_busy.contains(id)) return null;
    final status = order['status'] as String? ?? 'matched';

    String? code;
    if (status == 'matched' || status == 'arrived') {
      if (!context.mounted) return null;
      code = await askCode(context, delivery: status == 'arrived', order: order);
      if (code == null) return null;
    }
    // Stamp the step with where it happened, but never hold the rider up for a GPS fix.
    final pos = await LocationService.instance.current().timeout(const Duration(seconds: 3), onTimeout: () => null).catchError((_) => null);
    final lat = pos?.latitude, lng = pos?.longitude;

    _busy.add(id);
    try {
      final Map<String, dynamic> updated = switch (status) {
        'matched' => await RiderApi.pickup(id, code!, lat: lat, lng: lng),
        'picked_up' => await RiderApi.enRoute(id, lat: lat, lng: lng),
        'en_route' => await RiderApi.arrived(id, lat: lat, lng: lng),
        'arrived' => await RiderApi.deliver(id, code!, lat: lat, lng: lng),
        _ => order,
      };
      RiderState.instance.setActiveOrder(updated);
      if (context.mounted && updated['status'] == 'delivered') {
        AppPopup.delivered(
          context,
          route: OrderView.route(updated),
          merchant: (updated['recipient_name'] as String?)?.trim().isNotEmpty == true
              ? updated['recipient_name'] as String
              : 'Recipient',
          amount: OrderView.delivery(updated).amount,
        );
      }
      return updated;
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e), error: true);
      return null;
    } finally {
      _busy.remove(id);
    }
  }

  /// The active order whose track id is [trackId], if any.
  static Map<String, dynamic>? byTrack(String trackId) {
    final o = RiderState.instance.activeOrder;
    return o != null && (o['track_id'] ?? '').toString() == trackId ? o : null;
  }

  /// Sender before pickup, recipient after.
  static String? _contactPhone(Map<String, dynamic> o) {
    final beforePickup = (o['status'] as String? ?? 'matched') == 'matched';
    final p = (o[beforePickup ? 'sender_phone' : 'recipient_phone'] as String?)?.trim();
    return p == null || p.isEmpty ? null : p;
  }

  static Future<void> call(BuildContext context, Map<String, dynamic>? o) async {
    final p = o == null ? null : _contactPhone(o);
    if (p == null) return showSnack(context, 'No phone number on this order.', error: true);
    await launchUrl(Uri(scheme: 'tel', path: p));
  }

  static Future<void> message(BuildContext context, Map<String, dynamic>? o) async {
    final p = o == null ? null : _contactPhone(o);
    if (p == null) return showSnack(context, 'No phone number on this order.', error: true);
    await launchUrl(Uri(scheme: 'sms', path: p));
  }

  /// Report-issue sheet → reports it on the order, or (if the rider chose
  /// to cancel) marks the delivery as failed.
  static Future<void> reportIssue(BuildContext context, Map<String, dynamic>? o) async {
    if (o == null) return;
    final res = await showReportIssueSheet(context);
    if (res == null || !context.mounted) return;
    final id = (o['id'] as num).toInt();
    final reason = res.reason?.label ?? 'Cancelled by rider';
    try {
      if (res.reason?.name == 'contactSupport') {
        await RiderApi.sos('Rider needs support on order ${o['track_id']}');
        if (context.mounted) showSnack(context, 'Support has been alerted and will reach you shortly.');
        return;
      }
      if (res.cancelRide) {
        final updated = await RiderApi.fail(id, reason);
        RiderState.instance.setActiveOrder(updated);
        if (context.mounted) AppPopup.cancelled(context, status: 'Delivery cancelled: $reason');
      } else {
        await RiderApi.reportIssue(id, reason);
        if (context.mounted) AppPopup.issue(context, detail: 'Customer notified');
      }
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e), error: true);
    }
  }

  /// Bottom sheet asking for the 4-digit pickup or delivery code, with a
  /// QR-scan shortcut. Returns the code, or null if dismissed.
  static Future<String?> askCode(BuildContext context, {required bool delivery, Map<String, dynamic>? order}) {
    return showAppBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      title: delivery ? 'Confirm delivery' : 'Confirm pickup',
      child: _CodeSheet(delivery: delivery, order: order),
    );
  }
}

class _CodeSheet extends StatefulWidget {
  final bool delivery;
  final Map<String, dynamic>? order;
  const _CodeSheet({required this.delivery, this.order});

  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.length >= 4) Navigator.pop(context, v);
  }

  Future<void> _scan() async {
    final v = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScanScreen()));
    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (!mounted || digits.length < 4) return;
    Navigator.pop(context, digits.substring(digits.length - 4));
  }

  @override
  Widget build(BuildContext context) {
    final who = widget.delivery ? 'recipient' : 'sender';
    final name = widget.order?[widget.delivery ? 'recipient_name' : 'sender_name'] as String?;
    final cash = (widget.order?['collect_cash_kobo'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ask the $who${name != null && name.isNotEmpty ? ' ($name)' : ''} for the 4-digit '
            '${widget.delivery ? 'delivery' : 'pickup'} code and enter it below.',
            textAlign: TextAlign.center,
            style: AppBottomSheetStyle.subtitleStyle,
          ),
          if (widget.delivery && cash > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF4CC), borderRadius: BorderRadius.circular(8)),
              child: Text('Collect ${OrderView.delivery({'earning_kobo': cash}).amount} cash before handing over.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Montserrat', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8A6A00))),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'Montserrat', fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 10, color: Color(0xFF0E0F10)),
            decoration: InputDecoration(
              counterText: '',
              hintText: '• • • •',
              hintStyle: const TextStyle(color: Color(0xFFB8BCC2), letterSpacing: 6),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1A6B3C), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner, size: 18, color: Color(0xFF298341)),
                label: const Text('Scan code', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600, color: Color(0xFF298341))),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: Color(0xFF298341)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _ctrl.text.trim().length >= 4 ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34A853),
                  disabledBackgroundColor: const Color(0xFF2D6A3E),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(widget.delivery ? 'Mark as Delivered' : 'Confirm Pickup',
                    style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
