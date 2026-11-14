import 'dart:io';

import 'package:dyspatch_rider/Features/Home/Screen/Profile/Settings/document_capture_screen.dart';
import 'package:dyspatch_rider/Features/Home/widget/app_bottom_sheet.dart';
import 'package:dyspatch_rider/Features/onboarding/utils/snack.dart';
import 'package:dyspatch_rider/core/api/rider_api.dart';
import 'package:dyspatch_rider/core/api/session.dart';
import 'package:provider/provider.dart';
import 'package:dyspatch_rider/Features/Home/Screen/Profile/Settings/ride_details_screen.dart';
import 'package:dyspatch_rider/Features/Home/widget/menu_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class RideVerificationScreen extends StatelessWidget {
  const RideVerificationScreen({super.key});

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
                  Expanded(
                    child: Center(
                      child: Text(
                        "Ride verification",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: "Montserrat",
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.inversePrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _StatusBanner(status: context.watch<Session>().kycStatus),
                    const SizedBox(height: 16),
                    MenuCard(
                      // #F5F5F5 in light mode, #1A1A1A in dark mode.
                      color: Theme.of(context).colorScheme.secondary,
                      items: [
                        MenuItem(
                          icon: SvgPicture.asset(
                            'assets/images/ph_info.svg',
                            colorFilter: const ColorFilter.mode(
                              Color(0xFF5F6368),
                              BlendMode.srcIn,
                            ),
                          ),
                          label: "Ride Details",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RideDetailsScreen(),
                              ),
                            );
                          },
                        ),
                        MenuItem(
                          icon: SvgPicture.asset(
                            'assets/images/ph_camera.svg',
                            colorFilter: const ColorFilter.mode(
                              Color(0xFF5F6368),
                              BlendMode.srcIn,
                            ),
                          ),
                          label: "Ride Photos",
                          onTap: () => _uploadSet(context, 'Ride Photos', const {
                            'vehicle_front_photo': 'Front of your ride',
                            'vehicle_back_photo': 'Back of your ride',
                            'vehicle_side_photo': 'Side of your ride',
                          }),
                        ),
                        MenuItem(
                          icon: SvgPicture.asset(
                            'assets/images/ph_file.svg',
                            colorFilter: const ColorFilter.mode(
                              Color(0xFF5F6368),
                              BlendMode.srcIn,
                            ),
                          ),
                          label: "Ride Documents",
                          onTap: () => _uploadSet(context, 'Ride Documents', const {
                            'vehicle_papers_doc': 'Vehicle papers (registration)',
                            'drivers_licence_doc': "Driver's licence",
                            'insurance_doc': 'Insurance certificate',
                          }),
                          showDivider: false,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ── Register under a Fleet ───────────────────────
                    Center(
                      child: SizedBox(
                        width: 220,
                        child: ElevatedButton(
                          onPressed: () => showSnack(context, 'Registering under a fleet is coming soon.'),
                          style: ElevatedButton.styleFrom(
                            // #34A853 in both light and dark mode.
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Register under a Fleet",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: "Montserrat",
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row per photo/document: tap to capture, uploads straight away.
Future<void> _uploadSet(BuildContext context, String title, Map<String, String> items) async {
  await showAppBottomSheet<void>(
    context: context,
    title: title,
    child: _UploadList(items: items),
  );
}

class _UploadList extends StatefulWidget {
  final Map<String, String> items;
  const _UploadList({required this.items});

  @override
  State<_UploadList> createState() => _UploadListState();
}

class _UploadListState extends State<_UploadList> {
  String? _busy;

  Map<String, dynamic> get _extra => Map<String, dynamic>.from((Session.instance.rider?['extra'] as Map?) ?? {});

  Future<void> _capture(String key, String label) async {
    final file = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (_) => DocumentCaptureScreen(title: label, documentName: label)),
    );
    if (file == null || !mounted) return;
    setState(() => _busy = key);
    try {
      final updated = await RiderApi.updateMe({
        'extra': {key: RiderApi.dataUri(await file.readAsBytes())},
      });
      await Session.instance.updateRider(updated);
      if (mounted) showSnack(context, '$label uploaded');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final x = _extra;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in widget.items.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: x[e.key] != null
                ? const Icon(Icons.check_circle, color: Color(0xFF34A853))
                : const Icon(Icons.photo_camera_outlined, color: Color(0xFF5F6368)),
            title: Text(e.value, style: AppBottomSheetStyle.optionStyle),
            subtitle: Text(x[e.key] != null ? 'Uploaded · tap to replace' : 'Tap to take a photo', style: AppBottomSheetStyle.subtitleStyle),
            trailing: _busy == e.key ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null,
            onTap: _busy == null ? () => _capture(e.key, e.value) : null,
          ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final (text, bg, fg) = switch (status) {
      'verified' => ('You are verified and can go online.', const Color(0xFFE8F5E9), const Color(0xFF298341)),
      'submitted' => ('Your documents are being reviewed (usually under 48 hours).', const Color(0xFFFFF4CC), const Color(0xFF8A6A00)),
      'rejected' => ('Verification was rejected. Update your details and ID, then save again.', const Color(0xFFFDECEA), const Color(0xFFD32F2F)),
      _ => ('Add your ride details and government ID to get verified.', const Color(0xFFEEF1F4), const Color(0xFF5F6368)),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(fontFamily: 'Montserrat', fontSize: 13, fontWeight: FontWeight.w500, color: fg)),
    );
  }
}
