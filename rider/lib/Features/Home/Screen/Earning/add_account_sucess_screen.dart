import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AddAccountSuccessScreen extends StatefulWidget {
  const AddAccountSuccessScreen({super.key});

  @override
  State<AddAccountSuccessScreen> createState() =>
      _AddAccountSuccessScreenState();
}

class _AddAccountSuccessScreenState extends State<AddAccountSuccessScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-navigate back to Wallet/Earnings after a short delay
    Timer(const Duration(seconds: 10), () {
      if (mounted) {
        // Back to the wallet that opened "Add account" (no duplicate wallet page).
        Navigator.of(context).maybePop(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
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
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                      ),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Add Account',
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

            // ── Body ──
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset('assets/images/amico110.svg', height: 220),
                    const SizedBox(height: 28),
                    Text(
                      'SUBMISSION SUCCESSFUL',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Montserrat',
                        letterSpacing: 0.4,
                        color: Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Verification usually takes less than 2 hours',
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
        ),
      ),
    );
  }
}
