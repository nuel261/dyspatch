import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api/rider_api.dart';
import '../../core/api/session.dart';
import '../../core/services/rider_state.dart';
import '../../core/ui/format.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';
import '../home/home_shell.dart';

const idTypes = {'nin': 'NIN', 'drivers_license': "Driver's licence", 'voters_card': "Voter's card", 'bvn': 'BVN'};

/// ID verification (POST /rider/kyc). Reviewed in Admin → Verifications, or instantly
/// verified when a KYC provider (Prembly) is configured in Admin → Settings.
class VerificationScreen extends StatefulWidget {
  final bool fromAccount;
  const VerificationScreen({super.key, this.fromAccount = false});
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  String _type = 'nin';
  final _number = TextEditingController();
  String? _doc;
  bool _saving = false;

  Future<void> _pick(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 80);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() => _doc = RiderApi.dataUri(bytes));
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final env = await RiderApi.submitKyc(idType: _type, idNumber: _number.text.trim(), documentDataUri: _doc);
      await Session.instance.updateRider({'kyc_status': (env['data'] as Map?)?['kyc_status'] ?? 'submitted'});
      await RiderState.instance.refresh();
      if (!mounted) return;
      toast(context, env['message'] as String? ?? 'Submitted');
      _finish();
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _finish() {
    RiderState.instance.start();
    if (widget.fromAccount) {
      Navigator.pop(context);
    } else {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeShell()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<Session>().kycStatus;
    final rejected = status == 'rejected';
    return Scaffold(
      backgroundColor: context.card,
      appBar: widget.fromAccount
          ? appBar(context, 'Verification')
          : AppBar(backgroundColor: context.card, elevation: 0, automaticallyImplyLeading: false, surfaceTintColor: Colors.transparent),
      body: SafeArea(
        child: (status == 'submitted' || status == 'verified')
            ? _StatusView(status: status, onDone: _finish)
            : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
                if (!widget.fromAccount) ...[
                  const Text('STEP 2 OF 2', style: TextStyle(fontSize: 12, color: brandGreen, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                  const SizedBox(height: 6),
                ],
                Text('Verify your identity', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: context.ink)),
                const SizedBox(height: 6),
                const Text('Every Dyspatch rider is verified. This keeps customers and their packages safe. Review usually takes under 48 hours.',
                    style: TextStyle(fontSize: 14, color: inkGrey, height: 1.5)),
                if (rejected) ...[
                  const SizedBox(height: 14),
                  AppCard(
                    color: dangerRed.withValues(alpha: 0.08),
                    child: const Text('Your last submission could not be verified. Check the details and try again.',
                        style: TextStyle(color: dangerRed, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(height: 20),
                Text('ID type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.ink)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: idTypes.entries.map((e) {
                  final on = _type == e.key;
                  return ChoiceChip(
                    label: Text(e.value),
                    selected: on,
                    onSelected: (_) => setState(() => _type = e.key),
                    selectedColor: brandGreen.withValues(alpha: 0.15),
                    labelStyle: TextStyle(color: on ? brandGreen : context.ink, fontWeight: FontWeight.w600),
                    side: BorderSide(color: on ? brandGreen : context.line),
                    showCheckmark: false,
                  );
                }).toList()),
                const SizedBox(height: 16),
                AppField('${idTypes[_type]} number', _number, keyboard: _type == 'nin' || _type == 'bvn' ? TextInputType.number : TextInputType.text,
                    onChanged: (_) => setState(() {})),
                const SizedBox(height: 18),
                Text('Photo of the ID', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.ink)),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => showModalBottomSheet(
                    context: context,
                    builder: (_) => SafeArea(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () { Navigator.pop(context); _pick(ImageSource.camera); }),
                        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from gallery'), onTap: () { Navigator.pop(context); _pick(ImageSource.gallery); }),
                      ]),
                    ),
                  ),
                  child: Container(
                    height: 170,
                    decoration: BoxDecoration(
                      color: context.cs.secondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _doc != null ? brandGreen : context.line, width: 1.4),
                      image: _doc != null ? DecorationImage(image: MemoryImage(Uri.parse(_doc!).data!.contentAsBytes()), fit: BoxFit.cover) : null,
                    ),
                    child: _doc != null
                        ? null
                        : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.badge_outlined, size: 36, color: brandGreen),
                            SizedBox(height: 8),
                            Text('Tap to add the front of your ID', style: TextStyle(color: inkGrey, fontSize: 13)),
                          ]),
                  ),
                ),
                const SizedBox(height: 28),
                AppButton('Submit for verification', loading: _saving, onTap: _number.text.trim().length >= 6 && _doc != null ? _submit : null),
                if (!widget.fromAccount) ...[
                  const SizedBox(height: 10),
                  Center(child: TextButton(onPressed: _finish, child: const Text('Do this later', style: TextStyle(color: inkGrey)))),
                ],
              ]),
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  final String status;
  final VoidCallback onDone;
  const _StatusView({required this.status, required this.onDone});
  @override
  Widget build(BuildContext context) {
    final ok = status == 'verified';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Spacer(),
        Container(
          width: 96, height: 96,
          decoration: BoxDecoration(color: (ok ? brandGreen : warnAmber).withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(ok ? Icons.verified : Icons.hourglass_top_rounded, color: ok ? brandGreen : warnAmber, size: 46),
        ),
        const SizedBox(height: 20),
        Text(ok ? "You're verified" : 'Verification in review', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: context.ink)),
        const SizedBox(height: 8),
        Text(
          ok ? 'Go online from the home screen to start receiving delivery requests.' : "We're checking your details — usually under 48 hours. We'll notify you the moment you're approved.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: inkGrey, height: 1.5),
        ),
        const Spacer(),
        AppButton(ok ? 'Start riding' : 'Go to home', onTap: onDone),
      ]),
    );
  }
}
