import 'package:dyspatch_app/Features/onboarding/Screen/login.dart';
import 'package:dyspatch_app/Features/onboarding/Screen/register.dart';
import 'package:dyspatch_app/Features/onboarding/model/onboarding_model.dart';
import 'package:dyspatch_app/Features/onboarding/utils/button.dart';
import 'package:dyspatch_app/core/api/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _nextPage() {
    if (_currentPage < onboardingItems.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Session.instance.setOnboarded();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Register()),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Page content ──────────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: onboardingItems.length,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              onboardingItems.length,
                              (index) => Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  width: _currentPage == index ? 122 : 122,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _currentPage == index
                                        ? const Color(
                                            0xFF34A853,
                                          ).withOpacity(0.6)
                                        : const Color(
                                            0xFF34A853,
                                          ).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            onboardingItems[index].title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              color: Theme.of(
                                context,
                              ).colorScheme.inversePrimary,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            onboardingItems[index].description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w500,
                              color: Theme.of(
                                context,
                              ).colorScheme.inversePrimary,
                            ),
                          ),

                          Spacer(),

                          Center(
                            child: SvgPicture.asset(
                              onboardingItems[index].imagePath,
                              // height: size.height * 0.5,
                              // fit: BoxFit.cover,
                            ),
                          ),

                          Spacer(),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ── Dot indicators ────────────────────────────────────────
              const SizedBox(height: 70),

              // ── Next / Get Started button ─────────────────────────────
              Button(
                button_text: "Sign up",
                color: Color(0xFF298341),
                onTap: () {
                  Session.instance.setOnboarded();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Register()),
                  );
                },
              ),
              const SizedBox(height: 16),
              Button(
                onTap: () {
                  Session.instance.setOnboarded();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Login()),
                  );
                },
                button_text: "Login",
                color: Theme.of(
                  context,
                ).colorScheme.onSecondary.withOpacity(0.1),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
