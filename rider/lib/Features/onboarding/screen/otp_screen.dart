import 'dart:async';
import 'package:dyspatch_rider/Features/Home/Screen/home_screen.dart';
import 'package:dyspatch_rider/Features/onboarding/screen/verification_sucess.dart';
import 'package:dyspatch_rider/Features/onboarding/utils/snack.dart';
import 'package:dyspatch_rider/core/api/rider_api.dart';
import 'package:dyspatch_rider/core/api/session.dart';
import 'package:dyspatch_rider/core/services/app_router.dart';
import 'package:dyspatch_rider/core/services/push_service.dart';
import 'package:dyspatch_rider/core/services/rider_state.dart';
import 'package:dyspatch_rider/core/utils/rider_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;

  /// Response of POST /auth/otp/request: code length, resend cooldown and,
  /// on test servers, the code itself.
  final Map<String, dynamic> start;

  /// True when coming from sign-up (names/email/join type to save).
  final bool isSignup;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    this.start = const {},
    this.isSignup = false,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // The server says how long its codes are (4 by default); the boxes, the
  // label and the validation all follow.
  late final int _otpLength = (widget.start['length'] as num?)?.toInt() ?? 4;
  bool _verifying = false;

  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  Timer? _timer;
  int _secondsRemaining = 30;
  bool _canResend = false;
  bool _otpComplete = false;

  static const double _screenPadding = 20;
  static const double _boxGap = 12;

  // Back button = padding(10) * 2 + icon(20). The right-hand spacer
  // mirrors it exactly, so the title is centered on any screen.
  static const double _backIconSize = 20;
  static const double _backPadding = 10;
  static const double _backButtonSize = _backIconSize + (_backPadding * 2);

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    _startTimer((widget.start['resend_in'] as num?)?.toInt() ?? 60);
    _fillDebugCode(widget.start);
  }

  /// Test servers (SMS not live) return the code so testing doesn't need a phone.
  void _fillDebugCode(Map<String, dynamic> r) {
    final code = r['debug_code']?.toString();
    if (code == null || code.length != _otpLength) return;
    for (var i = 0; i < _otpLength; i++) {
      _controllers[i].text = code[i];
    }
    _otpComplete = true;
  }

  Future<void> _resend() async {
    try {
      final r = await RiderApi.requestOtp(widget.phoneNumber);
      if (!mounted) return;
      for (final c in _controllers) {
        c.clear();
      }
      setState(() => _otpComplete = false);
      _fillDebugCode(r);
      _startTimer((r['resend_in'] as num?)?.toInt() ?? 60);
      showSnack(context, 'A new code is on its way.');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  Future<void> _verify() async {
    final otp = _controllers.map((c) => c.text).join();
    setState(() => _verifying = true);
    try {
      final r = await RiderApi.verifyOtp(
        widget.phoneNumber,
        otp,
        firstName: widget.isSignup ? RiderSession.signupFirstName : null,
        lastName: widget.isSignup ? RiderSession.signupLastName : null,
      );
      await Session.instance.save(r['token'] as String, Map<String, dynamic>.from(r['rider'] as Map));
      if (widget.isSignup) {
        final fields = <String, dynamic>{'join_type': RiderSession.joinTypeApi};
        if (RiderSession.signupFirstName.isNotEmpty) fields['first_name'] = RiderSession.signupFirstName;
        if (RiderSession.signupLastName.isNotEmpty) fields['last_name'] = RiderSession.signupLastName;
        if (RiderSession.signupEmail.isNotEmpty) fields['email'] = RiderSession.signupEmail;
        try {
          await Session.instance.updateRider(await RiderApi.updateMe(fields));
        } catch (_) {/* saved later from the profile screen */}
      }
      RiderSession.syncFrom(Session.instance.rider);
      PushService.instance.syncToken();
      RiderState.instance.start();
      if (!mounted) return;
      if (widget.isSignup) {
        AppRouter.goTo(context, const VerficationSucess());
      } else {
        AppRouter.goTo(context, const HomeScreen());
      }
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorText(e), error: true);
      for (final c in _controllers) {
        c.clear();
      }
      setState(() => _otpComplete = false);
      _focusNodes.first.requestFocus();
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _startTimer([int seconds = 60]) {
    setState(() {
      _secondsRemaining = seconds;
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

  /// +2348012345678 → "+234 ••• ••• 7791"
  /// Non-breaking spaces keep the mask together as one unit.
  /// Guarded so a short national number (some countries use 8–9 digits)
  /// can't throw a RangeError on substring.
  String _maskPhone(String phone) {
    if (phone.length < 8) return phone;
    final last4 = phone.substring(phone.length - 4);
    final cutoff = phone.length - 10;
    final countryCode = cutoff > 0 ? phone.substring(0, cutoff) : '';
    const nbsp = '\u00A0';
    return countryCode.isEmpty
        ? '•••$nbsp•••$nbsp$last4'
        : '$countryCode$nbsp•••$nbsp•••$nbsp$last4';
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

  int get _firstEmptyIndex {
    for (int i = 0; i < _otpLength; i++) {
      if (_controllers[i].text.isEmpty) return i;
    }
    return _otpLength - 1;
  }

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {
      _otpComplete = _controllers.every((c) => c.text.isNotEmpty);
    });
  }

  // Redirects focus to the first empty box so the user can't type
  // out of order by tapping a box in the middle.
  void _onBoxTap(int index) {
    final target = _firstEmptyIndex;
    if (target != index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FocusScope.of(context).requestFocus(_focusNodes[target]);
        }
      });
    }
  }

  // ── "Didn't get a Code?" flow ────────────────────────────────────
  void _showWrongNumberDialog() {
    bool dialogHandled = false;
    Timer? autoCloseTimer;

    void goBackToRegister() {
      if (dialogHandled) return;
      dialogHandled = true;
      autoCloseTimer?.cancel();
      Navigator.of(context).pop(); // close the dialog
      Navigator.of(context).pop(); // back to Register screen
    }

    showGeneralDialog(
      context: context,
      barrierLabel: "Didn't get a code",
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        autoCloseTimer ??= Timer(const Duration(seconds: 15), () {
          if (mounted && Navigator.of(context).canPop()) {
            goBackToRegister();
          }
        });

        return Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Wrong number?",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "If the number is incorrect, go back and re-enter your phone number to get a new code.",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 22 / 14,
                        color: Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: goBackToRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF298341),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          "Re-enter Number",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    ).then((_) {
      dialogHandled = true;
      autoCloseTimer?.cancel();
    });
  }

  Widget _buildOtpBox(BuildContext context, int index, double boxWidth) {
    // A box that already holds a digit keeps a green border instead of
    // falling back to grey once focus moves on.
    final isFilled = _controllers[index].text.isNotEmpty;

    return SizedBox(
      width: boxWidth,
      height: (boxWidth * 1.05).clamp(46.0, 60.0),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        enableInteractiveSelection: false,
        showCursor: true,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: "Montserrat",
          color: Theme.of(context).colorScheme.inversePrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isFilled ? const Color(0xFF1A6B3C) : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A6B3C), width: 2),
          ),
        ),
        onTap: () => _onBoxTap(index),
        onChanged: (value) => _onChanged(value, index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.inversePrimary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final available =
                constraints.maxWidth -
                (_screenPadding * 2) -
                (_boxGap * (_otpLength - 1));
            final boxWidth = available / _otpLength;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: _screenPadding,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ────────────────────────────────────
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.tertiaryContainer,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(_backPadding),
                          child: Icon(
                            Icons.arrow_back,
                            size: _backIconSize,
                            color: onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            "Enter OTP",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              fontFamily: "Montserrat",
                            ),
                          ),
                        ),
                      ),
                      // Mirrors the back button so the title sits dead
                      // center regardless of screen width.
                      const SizedBox(width: _backButtonSize),
                    ],
                  ),

                  const SizedBox(height: 36),

                  Text(
                    "Verify your identity",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 24 / 17,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Sentence AND number on one line. FittedBox scales the
                  // whole line down on a narrow screen instead of wrapping,
                  // so the masked number never breaks.
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "We've sent a One-time Password to ${_maskPhone(widget.phoneNumber)}",
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 20 / 13,
                          color: onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Enter the $_otpLength-digit code below.",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 20 / 13,
                      color: onSurface,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── OTP boxes ─────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      _otpLength,
                      (i) => _buildOtpBox(context, i, boxWidth),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Resend row ────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: _showWrongNumberDialog,
                          child: Text(
                            "Didn't get a Code?",
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              height: 20 / 13,
                              color: onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _canResend ? _resend : null,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(
                              0xFF34A853,
                            ).withValues(alpha: 0.1),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Text(
                            _canResend
                                ? "Resend Code"
                                : "Resend Code $_timerText",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFamily: "Montserrat",
                              height: 20 / 13,
                              color: _canResend
                                  ? const Color(0xFF1A6B3C)
                                  : const Color(0xFFB8BCC2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // ── Verify button — centered, content width ───────
                  Center(
                    child: SizedBox(
                      width: 200,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _otpComplete && !_verifying ? _verify : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF34A853),
                          disabledBackgroundColor: const Color(0xFF2D6A3E),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _verifying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                              )
                            : const Text(
                          "Verify",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: "Montserrat",
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
