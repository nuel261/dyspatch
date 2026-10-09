import 'package:dyspatch_app/Features/Home/Screen/home_screen.dart';
import 'package:dyspatch_app/Features/Home/Screen/track_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DeliveryCreated extends StatelessWidget {
  /// The order returned by POST /orders.
  final Map<String, dynamic> order;
  const DeliveryCreated({super.key, this.order = const {}});

  String get _trackId => (order['track_id'] ?? '') as String;

  void _home(BuildContext context) {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
  }

  Widget _codeBox(BuildContext context, String label, String value, {bool mono = true}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: const Color(0XFFE3E7EB)), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, fontFamily: 'Montserrat', color: Color(0xFF5F6368))),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: mono ? 1.5 : 0, fontFamily: 'Montserrat', color: Theme.of(context).colorScheme.inversePrimary)),
          ]),
        ),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
          },
          child: Icon(Icons.copy_outlined, size: 18, color: Colors.grey.shade500),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
          children: [
            // ── Back button ──
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => _home(context),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // ── Title ──
            Text(
              'DELIVERY CREATED',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                fontFamily: 'Montserrat',
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
            ),

            const SizedBox(height: 24),

            // ── Success check SVG ──
            SvgPicture.asset(
              'assets/images/success.svg',
              width: 110,
              height: 110,
            ),

            const SizedBox(height: 32),

            // ── Description text ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  Text(
                    'Your delivery request has been\nsent to nearby riders.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w500,
                      height: 1.6,
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A rider will be assigned shortly',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Montserrat',
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            if (_trackId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(children: [
                  _codeBox(context, 'Track ID', _trackId),
                  const SizedBox(height: 10),
                  if (order['pickup_code'] != null) _codeBox(context, 'Pickup code — give this to the rider at pickup', order['pickup_code'] as String),
                  if (order['fee'] != null) ...[
                    const SizedBox(height: 10),
                    Text('Delivery fee ${order['fee']} · ${order['payment_method'] == 'cash' ? 'pay rider in cash' : 'paid from wallet'}',
                        style: TextStyle(fontSize: 12, fontFamily: 'Montserrat', color: Colors.grey.shade600)),
                  ],
                ]),
              ),
            const SizedBox(height: 24),
            if (_trackId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TrackScreen(initialTrackId: _trackId))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF298341)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Track delivery', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Montserrat', color: Color(0xFF298341))),
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // ── Back to home button ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _home(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF298341),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Back to home',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Montserrat',
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
        ),
      ),
    );
  }
}
