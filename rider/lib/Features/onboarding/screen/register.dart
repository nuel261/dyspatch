import 'package:dyspatch_rider/Features/Home/Screen/Profile/Settings/terms_and_privacy.dart';
import 'package:dyspatch_rider/Features/onboarding/screen/account_details_screen.dart';
import 'package:dyspatch_rider/Features/onboarding/screen/login.dart';
import 'package:dyspatch_rider/Features/onboarding/screen/register.dart';
import 'package:dyspatch_rider/Features/onboarding/utils/button.dart';
import 'package:dyspatch_rider/Features/onboarding/utils/phone_input.dart';
import 'package:flutter/material.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  bool isPhoneValid = false;
  String phoneNumber = '';

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
                  "Create your account",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Montserrat",
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                ),
                SizedBox(height: 10),

                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: TextStyle(fontSize: 14, fontFamily: "Montserrat"),
                    ),

                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => Login()),
                        );
                      },
                      child: Text(
                        "Login Here",
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
                  onTap: isPhoneValid
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AccountDetailsScreen(
                                phoneNumber: phoneNumber,
                              ),
                            ),
                          );
                        }
                      : null, // blocks tap when invalid
                  button_text: "Continue",
                  textColor: isPhoneValid
                      ? Color(0xFFFFFFFF)
                      : Color(0xFFA0A4AB),
                  color: isPhoneValid
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.surface,
                ),

                SizedBox(height: 16),

                SizedBox(height: 16),

                Text(
                  "By clicking “continue” you agree with",
                  style: TextStyle(fontFamily: "Montserrat", fontSize: 12),
                ),

                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      "our ",
                      style: TextStyle(fontFamily: "Montserrat", fontSize: 12),
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
                      style: TextStyle(fontFamily: "Montserrat", fontSize: 12),
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
