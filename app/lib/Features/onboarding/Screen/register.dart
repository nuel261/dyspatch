import 'package:dyspatch_app/Features/Home/Screen/terms_and_privacy_screen.dart';
import 'package:dyspatch_app/Features/Home/Screen/track_screen.dart';
import 'package:dyspatch_app/Features/onboarding/Screen/verfication_sucess.dart';
import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/utils/format.dart';
import 'package:dyspatch_app/Features/onboarding/Screen/login.dart';
import 'package:dyspatch_app/Features/onboarding/Screen/otp_screen.dart';
import 'package:dyspatch_app/Features/onboarding/utils/auth_service.dart';
import 'package:dyspatch_app/Features/onboarding/utils/button.dart';
import 'package:dyspatch_app/Features/onboarding/utils/phone_input.dart';
import 'package:dyspatch_app/Features/onboarding/utils/register_container.dart';
import 'package:flutter/material.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  bool isPhoneValid = false;
  String phoneNumber = '';
  final _authService = AuthService();
  bool _loading = false;
  bool _googleLoading = false;

  Future<void> _continue() async {
    setState(() => _loading = true);
    await OtpScreen.start(context, phoneNumber);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _handleGoogleSignIn() async {
    if (_googleLoading) return;
    setState(() => _googleLoading = true);
    try {
      final result = await _authService.signInWithGoogle();
      if (result == null) return; // cancelled
      final idToken = await _authService.getIdToken();
      if (idToken == null) throw Exception('Google sign-in failed');
      await DyspatchApi.googleSignIn(idToken);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const VerficationSucess()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _handleFacebookSignIn() async {
    toast(context, 'Facebook sign-in is coming soon. Use your phone number or Google.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      // resizeToAvoidBottomInset lets the form scroll up above the
      // keyboard instead of overflowing when the phone field is focused.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Cap the content width on tablets/large screens so the
            // form doesn't stretch edge-to-edge awkwardly.
            final maxWidth = constraints.maxWidth > 480
                ? 480.0
                : constraints.maxWidth;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    // Ensures short content still fills the screen height
                    // (so things look centered on tall phones) while
                    // letting long content scroll on short ones.
                    constraints: BoxConstraints(
                      minHeight:
                          constraints.maxHeight -
                          MediaQuery.of(context).padding.top -
                          MediaQuery.of(context).padding.bottom -
                          48, // account for vertical padding above
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Create your free account.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  "Already have an account? ",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Login(),
                                    ),
                                  );
                                },
                                child: Text(
                                  "Login here.",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF298341),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          RegisterContainer(
                            button_text: _googleLoading ? "Signing in…" : "Continue with Google",
                            icon: Icons.g_mobiledata,
                            onTap: _handleGoogleSignIn,
                          ),
                          const SizedBox(height: 16),
                          RegisterContainer(
                            button_text: "Continue with Facebook",
                            icon: Icons.facebook,
                            onTap: _handleFacebookSignIn,
                          ),

                          const SizedBox(height: 32),

                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Color(0xFF312C2D),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: Text(
                                    "Or continue with",
                                    style: TextStyle(color: Color(0xFF312C2D)),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Color(0xFF312C2D),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          CustomPhoneInput(
                            onPhoneChanged: (phone, isValid) {
                              setState(() {
                                phoneNumber = phone;
                                isPhoneValid = isValid;
                              });
                            },
                          ),

                          const SizedBox(height: 24),

                          Button(
                            onTap: isPhoneValid ? _continue : null,
                            loading: _loading,
                            button_text: "Continue",
                            color: isPhoneValid
                                ? Color(0xFF298341)
                                : Color(0xFF2D6A3E),
                          ),

                          const SizedBox(height: 16),

                          Button(
                            // Guests can track any package by its Track ID.
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TrackScreen()),
                            ),
                            button_text: "Track a package as guest",
                            color: Color(0xFF34A853).withOpacity(0.1),
                          ),

                          const SizedBox(height: 16),

                          Text(
                            "By clicking \u201ccontinue\u201d you agree with",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 12,
                            ),
                          ),

                          Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              Text(
                                "our ",
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  fontSize: 12,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsAndPrivacyScreen())),
                                child: Text(
                                  "Terms and Conditions",
                                  style: TextStyle(
                                    fontFamily: "Montserrat",
                                    fontSize: 12,
                                    color: Color(0xFF298341),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              Text(
                                " and ",
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  fontSize: 12,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsAndPrivacyScreen())),
                                child: Text(
                                  "Privacy Policy",
                                  style: TextStyle(
                                    fontFamily: "Montserrat",
                                    fontSize: 12,
                                    color: Color(0xFF298341),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
