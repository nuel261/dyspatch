import 'dart:async';

import 'package:dyspatch_app/Features/Home/Screen/home_screen.dart';
import 'package:dyspatch_app/Features/onboarding/Screen/verfication_sucess.dart';
import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Phone verification. Codes are 4 digits, expire after 30 minutes and lock
/// after 3 wrong attempts (rules enforced by the backend).
class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final int length;
  final int resendSeconds;
  final String? debugCode;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    this.length = 4,
    this.resendSeconds = 60,
    this.debugCode,
  });

  /// Requests a code for [phone] and opens the OTP screen. Shows errors as a toast.
  static Future<void> start(BuildContext context, String phone) async {
    try {
      final r = await DyspatchApi.requestOtp(phone);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            phoneNumber: r['phone'] ?? phone,
            length: (r['length'] as num?)?.toInt() ?? 4,
            resendSeconds: (r['resend_in'] as num?)?.toInt() ?? 60,
            debugCode: r['debug_code'] as String?,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) toast(context, e.toString(), error: true);
    }
  }

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  late final int _otpLength = widget.length;
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  Timer? _timer;
  int _secondsRemaining = 60;
  bool _canResend = false;
  bool _otpComplete = false;
  bool _verifying = false;
  String? _error;
  String? _debugCode;

  @override
  void initState() {
    super.initState();
    _debugCode = widget.debugCode;
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    _startTimer(widget.resendSeconds);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes.first.requestFocus();
      if (_debugCode != null && mounted) {
        toast(context, 'Test mode — your code is $_debugCode');
      }
    });
  }

  void _startTimer(int seconds) {
    setState(() {
      _secondsRemaining = seconds;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 0) {
        timer.cancel();
        setState(() => _canResend = true);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _resend() async {
    try {
      final r = await DyspatchApi.requestOtp(widget.phoneNumber);
      for (final c in _controllers) {
        c.clear();
      }
      setState(() {
        _error = null;
        _otpComplete = false;
        _debugCode = r['debug_code'] as String?;
      });
      _focusNodes.first.requestFocus();
      _startTimer((r['resend_in'] as num?)?.toInt() ?? 60);
      if (mounted) toast(context, _debugCode != null ? 'New code sent — test code $_debugCode' : 'A new code has been sent');
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    }
  }

  Future<void> _verify() async {
    if (!_otpComplete || _verifying) return;
    final otp = _controllers.map((c) => c.text).join();
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final r = await DyspatchApi.verifyOtp(widget.phoneNumber, otp);
      if (!mounted) return;
      final isNew = r['is_new'] == true;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => isNew ? const VerficationSucess() : const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      setState(() => _error = e.toString());
      for (final c in _controllers) {
        c.clear();
      }
      _otpComplete = false;
      _focusNodes.first.requestFocus();
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  String get _timerText {
    final mins = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secs = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String _maskPhone(String phone) {
    // e.g. +2348012345678 → +234 •••• 5678
    if (phone.length < 8) return phone;
    final last4 = phone.substring(phone.length - 4);
    final countryCode = phone.length > 10 ? phone.substring(0, phone.length - 10) : '';
    return '$countryCode •••• $last4';
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    // Support pasting the whole code into one box.
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < _otpLength; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      _focusNodes[digits.length.clamp(1, _otpLength).toInt() - 1].requestFocus();
    } else if (value.length == 1 && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    setState(() {
      _error = null;
      _otpComplete = _controllers.every((c) => c.text.isNotEmpty);
    });
    if (_otpComplete) _verify();
  }

  Widget _buildOtpBox(BuildContext context, int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final gaps = (_otpLength - 1) * 12;
    final boxWidth = ((screenWidth - 32 - gaps) / _otpLength).clamp(44.0, 72.0).toDouble();

    return SizedBox(
      width: boxWidth,
      height: boxWidth * 1.1,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        autofillHints: index == 0 ? const [AutofillHints.oneTimeCode] : null,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: "Montserrat",
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _error != null ? const Color(0xFFEA4335) : Colors.grey.shade300, width: 1.5),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: SvgPicture.asset('assets/images/Notification.svg', width: 50, height: 50),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Enter OTP",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.inversePrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          fontFamily: "Montserrat",
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 50),
                ],
              ),
              const SizedBox(height: 40),
              const Text(
                "Verify your identity",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: "Montserrat"),
              ),
              const SizedBox(height: 10),
              Text(
                "We've sent a One-time Password to ${_maskPhone(widget.phoneNumber)}",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: "Montserrat"),
              ),
              const SizedBox(height: 5),
              Text(
                "Enter the $_otpLength-digit code below. It expires in 30 minutes.",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: "Montserrat"),
              ),
              const SizedBox(height: 24),
              AutofillGroup(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_otpLength, (i) => _buildOtpBox(context, i)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFD33426), fontSize: 13, fontWeight: FontWeight.w600, fontFamily: "Montserrat"),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Didn't get a Code?",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: "Montserrat", color: Colors.grey.shade600),
                  ),
                  GestureDetector(
                    onTap: _canResend ? _resend : null,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFF34A853).withOpacity(0.1),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _canResend ? "Resend Code" : "Resend Code $_timerText",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: "Montserrat",
                          color: _canResend ? const Color(0xFF1A6B3C) : const Color(0xFFB8BCC2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 75),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _otpComplete && !_verifying ? _verify : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34A853),
                      disabledBackgroundColor: const Color(0xFF2D6A3E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _verifying
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : const Text(
                            "Verify",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: "Montserrat", color: Colors.white),
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
