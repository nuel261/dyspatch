import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:dyspatch_rider/Features/Home/widget/app_bottom_sheet.dart';

class CustomPhoneInput extends StatefulWidget {
  final Function(String phone, bool isValid) onPhoneChanged;
  const CustomPhoneInput({super.key, required this.onPhoneChanged});

  @override
  State<CustomPhoneInput> createState() => _CustomPhoneInputState();
}

class _CustomPhoneInputState extends State<CustomPhoneInput> {
  final TextEditingController phoneController = TextEditingController();

  Country selectedCountry = Country(
    phoneCode: '234',
    countryCode: 'NG',
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: 'Nigeria',
    example: 'Nigeria',
    displayName: 'Nigeria',
    displayNameNoCountryCode: 'Nigeria',
    e164Key: '',
  );

  String? _errorText;
  bool _hasInteracted = false;

  String _stripLeadingZero(String value) =>
      value.startsWith('0') ? value.substring(1) : value;

  /// Uses actual libphonenumber metadata (via phone_numbers_parser) to
  /// validate against the real conventional format for whatever country
  /// is selected — not a hand-maintained length guess.
  bool _isValidForSelectedCountry(String rawDigits) {
    if (rawDigits.isEmpty) return false;
    try {
      final phoneNumber = PhoneNumber.parse(
        rawDigits,
        callerCountry: IsoCode.values.byName(selectedCountry.countryCode),
      );
      return phoneNumber.isValid(type: PhoneNumberType.mobile);
    } catch (_) {
      return false;
    }
  }

  void _emitChange(String value) {
    final cleaned = _stripLeadingZero(value);
    final fullNumber = '+${selectedCountry.phoneCode}$cleaned';
    final isValid = value.isNotEmpty && _isValidForSelectedCountry(value);

    setState(() {
      _errorText = value.isEmpty || isValid ? null : 'Invalid phone number';
    });

    widget.onPhoneChanged(fullNumber, isValid);
  }

  void _onCountrySelected(Country country) {
    setState(() {
      selectedCountry = country;
    });
    // Recompute + revalidate immediately against the new country's format.
    _emitChange(phoneController.text);
  }

  void _openCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      onSelect: _onCountrySelected,
      countryListTheme: CountryListThemeData(
        backgroundColor: AppBottomSheetStyle.background,
        bottomSheetHeight: 400,
        borderRadius: AppBottomSheetStyle.borderRadius,
        inputDecoration: InputDecoration(
          hintText: "Search country",
          hintStyle: AppBottomSheetStyle.subtitleStyle,
          prefixIcon: const Icon(
            Icons.search,
            color: AppBottomSheetStyle.subtitleColor,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.primary,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        textStyle: AppBottomSheetStyle.optionStyle,
        searchTextStyle: AppBottomSheetStyle.optionStyle,
      ),
    );
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showError = _hasInteracted && _errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // IntrinsicHeight measures the tallest child (the TextField) and
        // gives that height to the stretched pill — no magic numbers.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Flag pill ─────────────────────────────────────────────
              GestureDetector(
                onTap: _openCountryPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34A853).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedCountry.flagEmoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        color: Theme.of(context).colorScheme.inversePrimary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // ── Phone input ───────────────────────────────────────────
              Expanded(
                child: TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    // Only digits allowed — no letters, dashes, spaces, etc.
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  onChanged: (value) {
                    if (!_hasInteracted) {
                      setState(() => _hasInteracted = true);
                    }
                    _emitChange(value);
                  },
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                  decoration: InputDecoration(
                    // The TextField sizes itself from this padding; the pill
                    // then matches it via IntrinsicHeight + stretch.
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    hintText: "Enter Mobile number",
                    hintStyle: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF8A8F98),
                      letterSpacing: 0,
                    ),
                    // prefixIcon with tight constraints: renders always
                    // (unlike `prefix`, which only shows on focus/text).
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      child: Text(
                        '+${selectedCountry.phoneCode}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.inversePrimary,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 0,
                      minHeight: 0,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.primary,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: showError
                            ? const Color(0xFFD32F2F)
                            : const Color(0xFFE0E0E0),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: showError
                            ? const Color(0xFFD32F2F)
                            : const Color(0xFF34A853),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (showError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _errorText!,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFFD32F2F),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
