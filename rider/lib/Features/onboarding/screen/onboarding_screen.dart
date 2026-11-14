import 'dart:async';

import 'package:dyspatch_rider/Features/onboarding/model/onboarding_model.dart';
import 'package:dyspatch_rider/Features/onboarding/screen/login.dart';
import 'package:dyspatch_rider/Features/onboarding/screen/register.dart';
import 'package:dyspatch_rider/Features/onboarding/utils/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Start far into a virtually infinite list so the user can swipe both
  // ways forever. The starting page is a multiple of the item count, so
  // it maps to the first slide.
  static final int _initialPage = 1000 * onboardingItems.length;
  final PageController _pageController = PageController(
    initialPage: _initialPage,
  );
  int _currentPage = 0;

  Timer? _autoScrollTimer;
  static const Duration _autoScrollInterval = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  // ── Auto-scroll handling ────────────────────────────────────────────
  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      if (!_pageController.hasClients) return;

      // Always slide forward; the PageView is infinite, so after the last
      // illustration the first one slides in next.
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  // Called when the user manually drags the PageView, so the auto-scroll
  // doesn't fight with their input — it just restarts the countdown.
  void _restartAutoScroll() {
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 32),

              // ── Pagination indicator (FIXED - does not slide) ────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  onboardingItems.length,
                  (index) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? const Color(0xFF34A853).withOpacity(0.6)
                            : const Color(0xFF34A853).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Title (FIXED - updates instantly, does not slide) ────
              Text(
                onboardingItems[_currentPage].title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.inversePrimary,
                  height: 32 / 24, // 1.333
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 22),

              // ── Description (FIXED - updates instantly, does not slide) ─
              Text(
                onboardingItems[_currentPage].description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.inversePrimary,
                  height: 22 / 12,
                  letterSpacing: 0,
                ),
              ),

              // ── Illustration only (THIS is what slides / auto-scrolls) ─
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    // Any user-driven drag restarts the auto-scroll timer
                    // so it doesn't jump the page right after they swipe.
                    if (notification is UserScrollNotification) {
                      _restartAutoScroll();
                    }
                    return false;
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    // No itemCount → infinite pages; map each to a real item.
                    onPageChanged: (index) => setState(
                      () => _currentPage = index % onboardingItems.length,
                    ),
                    itemBuilder: (context, index) {
                      return Center(
                        child: SvgPicture.asset(
                          onboardingItems[index % onboardingItems.length]
                              .imagePath,
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 46),

              // ── Sign up / Login buttons ───────────────────────────────
              Button(
                button_text: "Sign Up",
                textColor: Theme.of(context).colorScheme.primary,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                onTap: () {
                  _autoScrollTimer?.cancel();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Register()),
                  );
                },
              ),
              const SizedBox(height: 16),
              Button(
                onTap: () {
                  _autoScrollTimer?.cancel();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Login()),
                  );
                },
                button_text: "Login",
                color: Theme.of(
                  context,
                ).colorScheme.onSecondaryContainer.withOpacity(0.1),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
