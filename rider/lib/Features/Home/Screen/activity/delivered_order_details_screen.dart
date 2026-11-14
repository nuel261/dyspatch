import 'package:dyspatch_rider/Features/Home/model/activity_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DeliveredOrderDetailsScreen extends StatelessWidget {
  final ActivityOrder order;

  const DeliveredOrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Activity details',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Montserrat',
                        color: Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.inverseSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.inverseSurface,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Delivered',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Montserrat',
                                color: Color(0xFF298341),
                              ),
                            ),
                          ),
                          Text(
                            order.orderId,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        order.route,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: _detailRow(
                              'assets/images/ph_user.svg',
                              order.pickupLocation,
                            ),
                          ),
                          if (order.eta != null)
                            _detailRow(
                              'assets/images/ph_clock.svg',
                              order.eta!,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (order.items != null)
                            Flexible(
                              child: _detailRow(
                                'assets/images/ph_package.svg',
                                order.items!,
                              ),
                            ),
                          if (order.amount.isNotEmpty)
                            Text(
                              order.amount,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                        ],
                      ),
                      if (order.trackId != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Track-ID',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Same tap-to-copy behaviour as DeliveryCard
                        _TrackIdRow(
                          trackId: order.trackId!,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            'Delivered successfully!',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ),
                      ],
                      if (order.timeline != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Order timeline',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Montserrat',
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...order.timeline!.map(
                          (event) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  'assets/images/ph_check-circle-fill.svg',
                                  width: 14,
                                  height: 14,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    event.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                ),
                                Text(
                                  event.time,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String iconPath, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          iconPath,
          width: 15,
          height: 15,
          colorFilter: ColorFilter.mode(Colors.grey.shade500, BlendMode.srcIn),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontFamily: 'Montserrat',
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Track-ID row — tap to copy. Swaps to "Copied successfully" + green
// check for 2 seconds, then reverts. Same behaviour as DeliveryCard.
// ─────────────────────────────────────────────────────────────────────
class _TrackIdRow extends StatefulWidget {
  final String trackId;
  final Color? backgroundColor;

  const _TrackIdRow({required this.trackId, this.backgroundColor});

  @override
  State<_TrackIdRow> createState() => _TrackIdRowState();
}

class _TrackIdRowState extends State<_TrackIdRow> {
  bool _copied = false;

  Future<void> _handleCopy() async {
    if (_copied) return;
    await Clipboard.setData(ClipboardData(text: widget.trackId));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.backgroundColor ?? Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _handleCopy,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _copied ? 'Copied successfully' : widget.trackId,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Montserrat',
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
              ),
              _copied
                  ? SvgPicture.asset(
                      'assets/images/ph_checks.svg',
                      height: 16,
                      width: 16,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF298341),
                        BlendMode.srcIn,
                      ),
                    )
                  : Icon(Icons.copy, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
