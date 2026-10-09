import 'dart:async';
import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/api/session.dart';
import 'package:dyspatch_app/core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Autehtication extends StatefulWidget {
  const Autehtication({super.key});

  @override
  State<Autehtication> createState() => _Autehtication();
}

class _Autehtication extends State<Autehtication> {
  final int _otpLength = 4;
  bool _verifying = false;
  final bool _enabled = Session.instance.user?['two_factor'] == true;

  Future<void> _send() async {
    try {
      final r = await DyspatchApi.request2fa();
      if (!mounted) return;
      final dbg = r['debug_code'];
      toast(context, dbg != null ? 'Test mode — your code is $dbg' : 'Code sent to your phone');
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  Future<void> _verify() async {
    if (!_otpComplete || _verifying) return;
    setState(() => _verifying = true);
    try {
      await DyspatchApi.verify2fa(_controllers.map((c) => c.text).join(), enable: !_enabled);
      await Session.instance.updateUser({'two_factor': !_enabled});
      if (!mounted) return;
      toast(context, !_enabled ? 'Two-factor authentication is on' : 'Two-factor authentication is off');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
      for (final c in _controllers) {
        c.clear();
      }
      setState(() => _otpComplete = false);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  Timer? _timer;
  int _secondsRemaining = 30;
  bool _canResend = false;
  bool _otpComplete = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    _startTimer();
    _send();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 30;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0) {
        timer.cancel();
        setState(() => _canResend = true);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  String get _timerText {
    final mins = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secs = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    // Check if all boxes are filled
    setState(() {
      _otpComplete = _controllers.every((c) => c.text.isNotEmpty);
    });
  }

  Widget _buildOtpBox(BuildContext context, int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boxWidth =
        ((screenWidth - 32 - (3 * 16)) / 4).clamp(44.0, 72.0).toDouble(); // 4 boxes

    return SizedBox(
      width: boxWidth,
      height: boxWidth * 1.1,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: "Montserrat",
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1A6B3C), width: 2),
          ),
        ),
        onChanged: (value) => _onChanged(value, index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: SvgPicture.asset(
                      'assets/images/Notification.svg',
                      width: 60,
                      height: 60,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Authentication",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.inversePrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          fontFamily: "Montserrat",
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              const Text(
                "Verify your identity",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: "Montserrat",
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "We've sent a One-time Password to +234 ••• ••• 4821",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Montserrat",
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Enter the 4-digit code below to turn two-factor authentication ${_enabled ? "off" : "on"}.",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Montserrat",
                ),
              ),
              const SizedBox(height: 24),

              // OTP Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  _otpLength,
                  (i) => _buildOtpBox(context, i),
                ),
              ),

              const SizedBox(height: 24),

              // Resend row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Didn't get a Code?",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Montserrat",
                      color: Colors.grey.shade600,
                    ),
                  ),
                  GestureDetector(
                    onTap: _canResend ? () { _startTimer(); _send(); } : null,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _canResend
                            ? const Color(0xFF34A853).withOpacity(0.1)
                            : const Color(0xFF34A853).withOpacity(0.1),
                      ),
                      padding: EdgeInsets.all(12),
                      child: Text(
                        _canResend ? "Resend Code" : "Resend Code $_timerText",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: "Montserrat",
                          color: _canResend
                              ? const Color(0xFF1A6B3C)
                              : Color(0xFFB8BCC2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Verify button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 75),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _otpComplete
                          ? Color(0xFF34A853)
                          : const Color(0xFF2D6A3E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Verify",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: "Montserrat",
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
