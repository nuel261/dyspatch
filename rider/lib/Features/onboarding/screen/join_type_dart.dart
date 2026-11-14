import 'package:dyspatch_rider/Features/onboarding/utils/snack.dart';
import 'package:dyspatch_rider/core/api/rider_api.dart';
import 'package:dyspatch_rider/Features/Home/Screen/enable_notification.dart';
import 'package:dyspatch_rider/Features/onboarding/screen/otp_screen.dart';
import 'package:dyspatch_rider/Features/onboarding/utils/button.dart';
import 'package:dyspatch_rider/core/utils/rider_session.dart';
import 'package:flutter/material.dart';

class JoinTypeScreen extends StatefulWidget {
    final String phoneNumber;
  const JoinTypeScreen({super.key , required this.phoneNumber});

  @override
  State<JoinTypeScreen> createState() => _JoinTypeScreenState();
}

class _JoinTypeScreenState extends State<JoinTypeScreen> {
  bool _sending = false;

  Future<void> _continue() async {
    RiderSession.joinType = _selected!;
    setState(() => _sending = true);
    try {
      final res = await RiderApi.requestOtp(widget.phoneNumber);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpScreen(phoneNumber: widget.phoneNumber, start: res, isSignup: true),
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  JoinType? _selected;

  Widget _buildOption({required String label, required JoinType type}) {
    final bool isSelected = _selected == type;
    const green = Color(0xFF34A853);

    return GestureDetector(
      onTap: () => setState(() => _selected = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isSelected ? green : green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: "Montserrat",
            height: 20 / 16,
            color: isSelected ? Colors.white : green,
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 15),
                Text(
                  "How would you like to Join?",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    fontFamily: "Montserrat",
                    height: 32 / 24,
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  "Pick the option that fits your current setup.",
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w400,
                    height: 22 / 14,
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                ),

                const SizedBox(height: 60),

                _buildOption(
                  label: "Individual Rider",
                  type: JoinType.individualRider,
                ),
                _buildOption(
                  label: "Student Rider",
                  type: JoinType.studentRider,
                ),
                _buildOption(label: "Fleet Owner", type: JoinType.fleetOwner),

                const Spacer(),

                Button(
                  onTap: _selected != null ? _continue : null,
                  loading: _sending,
                  button_text: "Continue",
                  textColor: Theme.of(context).colorScheme.primary,
                  color: _selected != null
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.surfaceContainer,
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
