import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

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

  void _emitChange(String value) {
    // Strip any leading zero so we don't end up with +2340801...
    final cleaned = value.startsWith('0') ? value.substring(1) : value;
    final fullNumber = '+${selectedCountry.phoneCode}$cleaned';
    widget.onPhoneChanged(fullNumber, value.length >= 10);
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Flag pill ─────────────────────────────────────────────
        GestureDetector(
          onTap: () {
            showCountryPicker(
              context: context,
              showPhoneCode: true,
              onSelect: (Country country) {
                setState(() {
                  selectedCountry = country;
                });
                // Recompute number with the new country code
                _emitChange(phoneController.text);
              },
              countryListTheme: CountryListThemeData(
                bottomSheetHeight: 400, // ← only takes up half the screen
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                inputDecoration: InputDecoration(
                  hintText: "Search country",
                  hintStyle: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    color: Color(0xFFBDBDBD),
                  ),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF5F6368)),
                  filled: true,
                  fillColor: Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                textStyle: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Color(0xFF1D5E2E).withOpacity(0.1),
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
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
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
            onChanged: _emitChange,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontFamily: 'Montserrat',
              fontSize: 14,
              color: Color(0xFF1A1A1A),
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              hintText: "Enter Mobile Number",
              hintStyle: const TextStyle(
                fontWeight: FontWeight.w400,
                fontFamily: 'Montserrat',
                fontSize: 14,
                color: Color(0xFFBDBDBD),
              ),
              prefixText: '+${selectedCountry.phoneCode}  ',
              prefixStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontFamily: 'Montserrat',
                fontSize: 14,
                color: Color(0xFF1A1A1A),
              ),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFFE0E0E0),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF1D5E2E),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}