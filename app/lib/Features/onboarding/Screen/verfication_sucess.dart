import 'package:dyspatch_app/Features/Home/Screen/enable_notification.dart';
import 'package:dyspatch_app/Features/onboarding/Screen/login.dart';
import 'package:dyspatch_app/Features/onboarding/utils/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class VerficationSucess extends StatelessWidget {
  const VerficationSucess({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: SvgPicture.asset(
                  'assets/images/Notification.svg',
                  width: 50,
                  height: 50,
                ),
              ),
            ),

            SizedBox(height: 40),

            Center(
              child: Text(
                "VERIFICATION SUCCESSFUL",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFamily: "Montserrat",
                ),
              ),
            ),
            SizedBox(height: 48),

            Center(
              child: SvgPicture.asset(
                "assets/images/success.svg",
                // height: size.height * 0.5,
                // fit: BoxFit.cover,
              ),
            ),

            SizedBox(height: 48),

            Center(
              child: Text(
                "Your Identity has been confirmed",
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w600,
                  color: Color(0XFF5A5858),
                ),
              ),
            ),
            SizedBox(height: 60),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 75),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EnableNotification(),
                      ),
                      (_) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF34A853),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Continue",
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
    );
  }
}
