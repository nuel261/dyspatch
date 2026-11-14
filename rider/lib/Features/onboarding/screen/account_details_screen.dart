import 'package:dyspatch_rider/core/utils/rider_session.dart';
import 'package:dyspatch_rider/Features/Home/Screen/Profile/Settings/terms_and_privacy.dart';
import 'package:dyspatch_rider/Features/onboarding/screen/join_type_dart.dart';
import 'package:dyspatch_rider/Features/onboarding/screen/login.dart';
import 'package:dyspatch_rider/Features/onboarding/utils/button.dart';
import 'package:flutter/material.dart';

class AccountDetailsScreen extends StatefulWidget {
  final String phoneNumber;

  const AccountDetailsScreen({super.key, required this.phoneNumber});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  bool get _isFormValid =>
      _firstNameController.text.trim().isNotEmpty &&
      _lastNameController.text.trim().isNotEmpty &&
      _emailController.text.trim().contains('@');
  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_onFieldChanged);
    _lastNameController.removeListener(_onFieldChanged);
    _emailController.removeListener(_onFieldChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_isFormValid) return;
    FocusScope.of(context).unfocus();
    RiderSession.signupFirstName = _firstNameController.text.trim();
    RiderSession.signupLastName = _lastNameController.text.trim();
    RiderSession.signupEmail = _emailController.text.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            JoinTypeScreen(phoneNumber: widget.phoneNumber),
      ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w500,
            height: 22 / 14,
            color: Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          // When a field gains focus, scroll far enough to keep the
          // Continue button above the keyboard too, not half under it.
          scrollPadding: const EdgeInsets.only(bottom: 140),
          autocorrect: false,
          enableSuggestions: false,
          style: TextStyle(
            fontSize: 14,
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.inversePrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,

            hintStyle: const TextStyle(
              fontSize: 14,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w400,
              color: Color(0xFFBDBDBD),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),

            filled: true,
            fillColor: Theme.of(context).colorScheme.primary,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: controller.text.isNotEmpty
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onInverseSurface,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 15),
                        Text(
                          "Create your free account.",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: "Montserrat",
                            color: Theme.of(context).colorScheme.inversePrimary,
                          ),
                        ),
                        const SizedBox(height: 10),

                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              "Already have an account? ",
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: "Montserrat",
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                                  fontSize: 14,
                                  fontFamily: "Montserrat",
                                  decoration: TextDecoration.underline,
                                  decorationColor: Color(0xFF298341),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        _buildLabeledField(
                          label: "First name",
                          hint: "Ola",
                          controller: _firstNameController,
                        ),
                        const SizedBox(height: 16),
                        _buildLabeledField(
                          label: "Last name",
                          hint: "Daniel",
                          controller: _lastNameController,
                        ),
                        const SizedBox(height: 16),
                        _buildLabeledField(
                          label: "Email address",
                          hint: "dyspatch@gmail.com",
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _continue(),
                        ),

                        const Spacer(),

                        Button(
                          onTap: _isFormValid ? _continue : null,
                          button_text: "Continue",
                          textColor: Theme.of(context).colorScheme.primary,

                          color: _isFormValid
                              ? Color(0xFF34A853)
                              : Color(0xFF2D6A3E),
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          "By clicking “continue” you agree with",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 12,
                          ),
                        ),

                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              "our ",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 12,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TermsAndPrivacyScreen(
                                    initialTab: 0,
                                  ),
                                ),
                              ),
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
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TermsAndPrivacyScreen(
                                    initialTab: 1,
                                  ),
                                ),
                              ),
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

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
