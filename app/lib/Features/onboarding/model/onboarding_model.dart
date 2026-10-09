import 'package:flutter/material.dart';


class OnboardingModel {
  final String title;
  final String description;
  final String imagePath;

  OnboardingModel({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}



List<OnboardingModel> onboardingItems = [
  OnboardingModel(
    title: 'Deliver smarter. Not harder.',
    description: 'Dyspatch helps your business move packages faster, cheaper, and with full visibility all from one app.',
    imagePath: 'assets/images/pana.svg',
  ),
  OnboardingModel(
    title: 'See every delivery in real time.',
    description: 'Track riders live, get instant updates, and know exactly when packages are picked up and delivered.',
    imagePath: 'assets/images/pana_1.svg',
  ),
  OnboardingModel(
    title: 'Send more. Spend less.',
    description: 'Create multiple deliveries at once and let Dyspatch optimize routes and costs for you.',
    imagePath: 'assets/images/pana_2.svg',
  ),
];
