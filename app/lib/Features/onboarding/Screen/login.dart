import 'package:dyspatch_app/Features/onboarding/Screen/otp_screen.dart';
import 'package:dyspatch_app/Features/onboarding/Screen/register.dart';
import 'package:dyspatch_app/Features/onboarding/utils/button.dart';
import 'package:dyspatch_app/Features/onboarding/utils/phone_input.dart';
import 'package:dyspatch_app/Features/Home/Screen/terms_and_privacy_screen.dart';
import 'package:flutter/material.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool isPhoneValid = false;
  String phoneNumber = '';
  bool _loading = false;

  Future<void> _continue() async {
    setState(() => _loading = true);
    await OtpScreen.start(context, phoneNumber);
    if (mounted) setState(() => _loading = false);
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
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Montserrat",
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                ),
                SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don’t have an account? ",
                      style: TextStyle(fontSize: 14, fontFamily: "Montserrat"),
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
                          color: Color(0xFF298341),
                          fontSize: 14,
                          fontFamily: "Montserrat",
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFF298341),
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
                  loading: _loading,
                  button_text: "Continue",
                  color: isPhoneValid ? Color(0xFF298341) : Color(0xFF2D6A3E),
                ),

                SizedBox(height: 16),

                SizedBox(height: 16),

                Text(
                  "By clicking “continue” you agree with",
                  style: TextStyle(fontFamily: "Montserrat", fontSize: 12),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "our ",
                      style: TextStyle(fontFamily: "Montserrat", fontSize: 12),
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
                    )),

                    Text(
                      " and ",
                      style: TextStyle(fontFamily: "Montserrat", fontSize: 12),
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
                    )),
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
