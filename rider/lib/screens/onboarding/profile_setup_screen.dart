import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/rider_api.dart';
import '../../core/api/session.dart';
import '../../core/services/rider_state.dart';
import '../../core/ui/format.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';
import 'splash_screen.dart';

const vehicleTypes = {'bike': ('Motorbike', Icons.two_wheeler), 'bicycle': ('Bicycle', Icons.pedal_bike), 'car': ('Car', Icons.directions_car), 'truck': ('Van / Truck', Icons.local_shipping)};

/// First-run profile (name, vehicle, zone, photo). Pass [editing] to reuse it from Account.
class ProfileSetupScreen extends StatefulWidget {
  final bool editing;
  const ProfileSetupScreen({super.key, this.editing = false});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final r = Session.instance.rider ?? {};
  late final _first = TextEditingController(text: r['first_name'] as String? ?? '');
  late final _last = TextEditingController(text: r['last_name'] as String? ?? '');
  late final _email = TextEditingController(text: r['email'] as String? ?? '');
  late final _plate = TextEditingController(text: r['plate'] as String? ?? '');
  late String? _vehicle = r['vehicle_type'] as String?;
  String? _zone;
  List<Map<String, dynamic>> _zones = [];
  String? _photoData;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    RiderApi.config().then((c) {
      if (!mounted) return;
      setState(() {
        _zones = ((c['zones'] as List?) ?? []).map((z) => Map<String, dynamic>.from(z as Map)).toList();
      });
    }).catchError((_) {});
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front, maxWidth: 800, imageQuality: 80);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() => _photoData = RiderApi.dataUri(bytes));
  }

  bool get _valid => _first.text.trim().isNotEmpty && _last.text.trim().isNotEmpty && _vehicle != null && (_vehicle == 'bicycle' || _plate.text.trim().length >= 4);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await RiderApi.updateMe({
        'first_name': _first.text.trim(), 'last_name': _last.text.trim(), 'vehicle_type': _vehicle,
        'plate': _plate.text.trim().toUpperCase(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        if (_zone != null) 'zone_code': _zone,
        if (_photoData != null) 'photo': _photoData,
      });
      await Session.instance.updateRider(updated);
      if (!mounted) return;
      if (widget.editing) {
        RiderState.instance.refresh();
        toast(context, 'Profile updated');
        Navigator.pop(context);
      } else {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => nextScreenFor(Session.instance)), (_) => false);
      }
    } catch (e) {
      if (mounted) toast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = r['photo'] as String?;
    return Scaffold(
      backgroundColor: context.card,
      appBar: widget.editing ? appBar(context, 'Profile & vehicle') : AppBar(backgroundColor: context.card, elevation: 0, automaticallyImplyLeading: false, surfaceTintColor: Colors.transparent),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
          if (!widget.editing) ...[
            const Text('STEP 1 OF 2', style: TextStyle(fontSize: 12, color: brandGreen, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
            const SizedBox(height: 6),
            Text('About you & your ride', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: context.ink)),
            const SizedBox(height: 6),
            const Text('Customers see your name, photo and plate when you accept their delivery.', style: TextStyle(fontSize: 14, color: inkGrey, height: 1.5)),
            const SizedBox(height: 20),
          ],
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: brandGreen.withValues(alpha: 0.12),
                  backgroundImage: _photoData != null
                      ? MemoryImage(Uri.parse(_photoData!).data!.contentAsBytes())
                      : (photo != null ? NetworkImage(photo) : null) as ImageProvider?,
                  child: _photoData == null && photo == null ? const Icon(Icons.person, size: 44, color: brandGreen) : null,
                ),
                const Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 15, backgroundColor: brandGreen, child: Icon(Icons.camera_alt, size: 16, color: Colors.white))),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          const Center(child: Text('Clear face photo, no sunglasses', style: TextStyle(fontSize: 12, color: inkGrey))),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: AppField('First name', _first, caps: TextCapitalization.words, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 12),
            Expanded(child: AppField('Last name', _last, caps: TextCapitalization.words, onChanged: (_) => setState(() {}))),
          ]),
          const SizedBox(height: 14),
          AppField('Email (optional)', _email, keyboard: TextInputType.emailAddress, hint: 'For payout receipts'),
          const SizedBox(height: 18),
          Text('Vehicle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.ink)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.6,
            children: vehicleTypes.entries.map((e) {
              final on = _vehicle == e.key;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _vehicle = e.key),
                child: Container(
                  decoration: BoxDecoration(
                    color: on ? brandGreen.withValues(alpha: 0.1) : context.cs.secondary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: on ? brandGreen : Colors.transparent, width: 1.6),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(e.value.$2, color: on ? brandGreen : inkGrey, size: 20),
                    const SizedBox(width: 8),
                    Text(e.value.$1, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: on ? brandGreen : context.ink)),
                  ]),
                ),
              );
            }).toList(),
          ),
          if (_vehicle != 'bicycle') ...[
            const SizedBox(height: 14),
            AppField('Plate number', _plate, hint: 'e.g. BEN-238-KJA', caps: TextCapitalization.characters, onChanged: (_) => setState(() {})),
          ],
          if (_zones.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('City you ride in', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.ink)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _zone,
              hint: const Text('Choose a city'),
              decoration: InputDecoration(
                filled: true, fillColor: context.cs.secondary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              items: _zones
                  .map((z) => DropdownMenuItem(value: z['code'] as String, child: Text('${z['name']}${z['is_live'] == true ? '' : ' (coming soon)'}')))
                  .toList(),
              onChanged: (v) => setState(() => _zone = v),
            ),
          ],
          const SizedBox(height: 28),
          AppButton(widget.editing ? 'Save changes' : 'Continue', loading: _saving, onTap: _valid ? _save : null),
        ]),
      ),
    );
  }
}
