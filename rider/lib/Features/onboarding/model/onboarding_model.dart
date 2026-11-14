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
    title: 'Turn your miles into money.',
    description:
        'Accept delivery requests in your area, navigate with ease, and get paid for every successful drop-off.',
    imagePath: 'assets/images/amico.svg',
  ),
  OnboardingModel(
    title: 'Manage your fleet.',
    description:
        'Track all your bikes in real-time, monitor rider performance, and grow your dispatch business.',
    imagePath: 'assets/images/amico_1.svg',
  ),
  OnboardingModel(
    title: 'Earn between classes.',
    description:
        'Flexible delivery hours that fit your school schedule. Go online, deliver, and get paid instantly.',
    imagePath: 'assets/images/amico_2.svg',
  ),
];
