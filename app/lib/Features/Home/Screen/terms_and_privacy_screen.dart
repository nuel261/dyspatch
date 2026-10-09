import 'package:flutter/material.dart';

class TermsAndPrivacyScreen extends StatefulWidget {
  const TermsAndPrivacyScreen({super.key});

  @override
  State<TermsAndPrivacyScreen> createState() => _TermsAndPrivacyScreenState();
}

class _TermsAndPrivacyScreenState extends State<TermsAndPrivacyScreen> {
  int _selectedTab = 0; // 0 = Terms of Service, 1 = Privacy Policy

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Terms & Privacy",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: "Montserrat",
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ── Tabs ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _Tab(
                    label: "Terms of Service",
                    isSelected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                  const SizedBox(width: 24),
                  _Tab(
                    label: "Privacy Policy",
                    isSelected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),

            // ── Content ───────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: _selectedTab == 0
                    ? const _TermsOfService()
                    : const _PrivacyPolicy(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab widget
// ─────────────────────────────────────────────────────────────────────────────

class _Tab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontFamily: "Montserrat",
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: isSelected ? 100 : 0,
            decoration: BoxDecoration(
              color: const Color(0xFF1D5E2E),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared section widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: "Montserrat",
          color: Color(0xFF1A1A1A),
        ),
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;
  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w400,
          color: Color(0xFF5F6368),
          height: 1.6,
        ),
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;
  const _BulletList(this.items);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 8),
                      child: CircleAvatar(
                        radius: 2.5,
                        backgroundColor: Color(0xFF5F6368),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF5F6368),
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_SectionTitle(title), ...children],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Terms of Service content
// ─────────────────────────────────────────────────────────────────────────────

class _TermsOfService extends StatelessWidget {
  const _TermsOfService();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: "1. Use of the platform",
          children: [
            const _BodyText(
              "The platform connects businesses that need deliveries with independent riders who fulfill those deliveries. Users may only use the service for lawful purposes and must not:",
            ),
            const _BulletList([
              "Provide false or misleading information",
              "Attempt to disrupt or interfere with the platform",
              "Use the platform for illegal delivery or transportation of prohibited goods",
              "Attempt to access accounts or systems without authorization",
            ]),
            const _BodyText(
              "We reserve the right to suspend or terminate accounts that violate these rules.",
            ),
          ],
        ),
        _Section(
          title: "2. Account Registration",
          children: [
            const _BodyText(
              "To use certain features of the platform, users must create an account. You agree to:",
            ),
            const _BulletList([
              "Provide accurate and complete information",
              "Keep your login credentials secure",
              "Notify us immediately if you suspect unauthorized use of your account",
            ]),
            const _BodyText(
              "You are responsible for all activity that occurs under your account.",
            ),
          ],
        ),
        _Section(
          title: "3. Delivery Requests",
          children: [
            const _BodyText(
              "Businesses may create delivery requests through the app. By creating a delivery request, the business agrees that:",
            ),
            const _BulletList([
              "All delivery details provided are accurate",
              "The package complies with applicable laws",
              "The package does not contain prohibited items",
            ]),
            const _BodyText(
              "Riders accept deliveries independently and are responsible for fulfilling them as agreed.",
            ),
          ],
        ),
        _Section(
          title: "4. Rider Responsibilities",
          children: [
            const _BodyText("Riders using the platform agree to:"),
            const _BulletList([
              "Fulfill accepted delivery requests responsibly",
              "Maintain accurate availability status",
              "Handle packages with care",
              "Follow all applicable traffic laws and regulations",
            ]),
            const _BodyText(
              "Riders operate as independent service providers and are not employees of the platform.",
            ),
          ],
        ),
        _Section(
          title: "5. Payments",
          children: [
            const _BodyText(
              "Riders receive earnings based on completed deliveries. The platform may deduct applicable service fees. Payments are processed within the timelines specified in the app. We are not liable for delays caused by third-party payment processors.",
            ),
          ],
        ),
        _Section(
          title: "6. Termination",
          children: [
            const _BodyText(
              "We reserve the right to suspend or terminate any account at our discretion, especially in cases of fraud, misconduct, or violation of these terms. Users may also delete their accounts at any time through the app settings.",
            ),
          ],
        ),
        _Section(
          title: "7. Changes to Terms",
          children: [
            const _BodyText(
              "We may update these terms from time to time. Continued use of the platform after changes are posted constitutes your acceptance of the updated terms.",
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Privacy Policy content
// ─────────────────────────────────────────────────────────────────────────────

class _PrivacyPolicy extends StatelessWidget {
  const _PrivacyPolicy();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: "1. Information We Collect",
          children: [
            const _BodyText(
              "We collect information you provide directly to us, including:",
            ),
            const _BulletList([
              "Name, email address, and phone number",
              "Business or rider profile details",
              "Delivery addresses and location data",
              "Payment information (processed securely by third parties)",
            ]),
          ],
        ),
        _Section(
          title: "2. How We Use Your Information",
          children: [
            const _BodyText("We use the information we collect to:"),
            const _BulletList([
              "Provide, maintain, and improve the platform",
              "Process deliveries and payments",
              "Send you updates and notifications",
              "Detect and prevent fraud or abuse",
              "Comply with legal obligations",
            ]),
          ],
        ),
        _Section(
          title: "3. Sharing Your Information",
          children: [
            const _BodyText(
              "We do not sell your personal information. We may share it with:",
            ),
            const _BulletList([
              "Riders or businesses as needed to complete deliveries",
              "Service providers who help us operate the platform",
              "Law enforcement when required by law",
            ]),
          ],
        ),
        _Section(
          title: "4. Data Retention",
          children: [
            const _BodyText(
              "We retain your data for as long as your account is active or as needed to provide our services. You may request deletion of your account and data at any time.",
            ),
          ],
        ),
        _Section(
          title: "5. Security",
          children: [
            const _BodyText(
              "We implement appropriate technical and organizational measures to protect your information. However, no system is completely secure and we cannot guarantee absolute security.",
            ),
          ],
        ),
        _Section(
          title: "6. Your Rights",
          children: [
            const _BodyText("You have the right to:"),
            const _BulletList([
              "Access the personal data we hold about you",
              "Request correction of inaccurate data",
              "Request deletion of your data",
              "Withdraw consent where processing is based on consent",
            ]),
            const _BodyText(
              "To exercise any of these rights, contact us through the Help Center.",
            ),
          ],
        ),
        _Section(
          title: "7. Contact Us",
          children: [
            const _BodyText(
              "If you have any questions about this Privacy Policy, please reach out to our support team via the Help Center in the app.",
            ),
          ],
        ),
      ],
    );
  }
}
