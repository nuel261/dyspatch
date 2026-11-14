import 'package:dyspatch_rider/Features/Home/Screen/Profile/Settings/terms_and_privacy.dart';
import 'package:dyspatch_rider/Features/onboarding/screen/account_details_screen.dart';
import 'package:dyspatch_rider/Features/onboarding/screen/otp_screen.dart';
import 'package:dyspatch_rider/Features/onboarding/utils/snack.dart';
import 'package:dyspatch_rider/core/api/rider_api.dart';
import 'package:dyspatch_rider/Features/onboarding/screen/register.dart';
import 'package:dyspatch_rider/Features/onboarding/utils/button.dart';
import 'package:dyspatch_rider/Features/onboarding/utils/phone_input.dart';
import 'package:flutter/material.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool isPhoneValid = false;
  String phoneNumber = '';
  bool _sending = false;

  Future<void> _continue() async {
    setState(() => _sending = true);
    try {
      final res = await RiderApi.requestOtp(phoneNumber);
      if (!mounted) return;
      if (res['is_registered'] == false) {
        // New number: collect the sign-up details first, then verify.
        showSnack(context, "There's no rider account for this number yet. Let's create one.");
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AccountDetailsScreen(phoneNumber: phoneNumber)),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OtpScreen(phoneNumber: phoneNumber, start: res)),
      );
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
                SizedBox(height: 15),
                Text(
                  "Welcome back!",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.inversePrimary,
                    height: 32 / 24, // 1.333
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: 10),

                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      "Don’t have an account? ",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 22 / 14, // 1.571
                        letterSpacing: 0,
                        color: Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),

                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => Register()),
                        );
                      },
                      child: Text(
                        "Sign up Here",
                        style: TextStyle(
                          color: Color(0xFF34A853),
                          fontSize: 14,
                          fontFamily: "Montserrat",
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFF34A853),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 60),

                CustomPhoneInput(
                  onPhoneChanged: (phone, isValid) {
                    setState(() {
                      phoneNumber = phone;
                      isPhoneValid = isValid;
                    });
                  },
                ),
                Spacer(),
                Button(
                  onTap: isPhoneValid ? _continue : null, // blocks tap when invalid
                  loading: _sending,
                  button_text: "Continue",
                  textColor: Theme.of(context).colorScheme.primary,
                  color: isPhoneValid
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.surface,
                ),

                SizedBox(height: 16),

                SizedBox(height: 16),

                Text(
                  "By clicking “continue” you agree with",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                ),

                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      "our ",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const TermsAndPrivacyScreen(initialTab: 0),
                        ),
                      ),
                      child: Text(
                        "Terms and Conditions",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 12,
                          color: Color(0xFF34A853),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),

                    Text(
                      " and ",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),

                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const TermsAndPrivacyScreen(initialTab: 1),
                        ),
                      ),
                      child: Text(
                        "Privacy Policy",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 12,
                          color: Color(0xFF34A853),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
