import 'dart:async';

import 'package:dyspatch_app/Features/Home/Screen/delivery_created.dart';
import 'package:dyspatch_app/Features/Home/Screen/topup_screen.dart';
import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/api/session.dart';
import 'package:dyspatch_app/core/utils/format.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';

// ── Shared form state across all steps ──
class _DeliveryFormData {
  String pickup = '';
  double? pickupLat;
  double? pickupLng;
  String dropoff = '';
  double? dropoffLat;
  double? dropoffLng;
  String packageType = 'Medium Package';
  String packageDescription = '';
  String recipientName = '';
  String recipientPhone = '';
  String deliveryType = (Session.instance.user?['default_delivery_type'] as String?) ?? 'standard';
  String paymentMethod = 'wallet';

  Map<String, dynamic> toJson() => {
        'pickup_address': pickup, 'pickup_lat': pickupLat, 'pickup_lng': pickupLng,
        'dropoff_address': dropoff, 'dropoff_lat': dropoffLat, 'dropoff_lng': dropoffLng,
        'package_type': packageType, 'package_description': packageDescription,
        'recipient_name': recipientName, 'recipient_phone': recipientPhone,
        'delivery_type': deliveryType, 'payment_method': paymentMethod,
      };
}

class CreateDelivery extends StatefulWidget {
  const CreateDelivery({super.key});

  @override
  State<CreateDelivery> createState() => _CreateDeliveryState();
}

class _CreateDeliveryState extends State<CreateDelivery> {
  final PageController _pageController = PageController();
  final _formData = _DeliveryFormData();
  int _currentStep = 0;

  void _nextStep() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep == 0) {
      Navigator.pop(context);
    } else {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: _previousStep,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.tertiaryContainer,
              ),
              child: Icon(
                Icons.arrow_back,
                color: Theme.of(context).colorScheme.inversePrimary,
                size: 20,
              ),
            ),
          ),
        ),
        title: Text(
          'Create delivery',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Theme.of(context).colorScheme.inversePrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentStep = index),
        children: [
          _FromToStep(formData: _formData, onNext: _nextStep),
          _AddressSuggestionsStep(formData: _formData, onNext: _nextStep),
          _PackageDetailsStep(formData: _formData, onNext: _nextStep),
          _ConfirmDeliveryStep(formData: _formData, active: _currentStep == 3),
        ],
      ),
    );
  }
}

// ── Step 1: From / To search ──
class _FromToStep extends StatefulWidget {
  final _DeliveryFormData formData;
  final VoidCallback onNext;
  const _FromToStep({required this.formData, required this.onNext});

  @override
  State<_FromToStep> createState() => _FromToStepState();
}

class _FromToStepState extends State<_FromToStep> {
  late TextEditingController _fromController;
  late TextEditingController _toController;
  final _fromFocus = FocusNode();
  final _toFocus = FocusNode();
  bool _editingFrom = true;
  Timer? _debounce;
  bool _searching = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];
  double? _biasLat;
  double? _biasLng;

  @override
  void initState() {
    super.initState();
    _fromController = TextEditingController(text: widget.formData.pickup);
    _toController = TextEditingController(text: widget.formData.dropoff);
    _fromFocus.addListener(() { if (_fromFocus.hasFocus) setState(() { _editingFrom = true; _results = []; }); });
    _toFocus.addListener(() { if (_toFocus.hasFocus) setState(() { _editingFrom = false; _results = []; }); });
    final u = Session.instance.user;
    _biasLat = (u?['lat'] as num?)?.toDouble();
    _biasLng = (u?['lng'] as num?)?.toDouble();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _fromController.dispose();
    _toController.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  void _onType(String q) {
    if (_editingFrom) {
      widget.formData.pickupLat = null;
      widget.formData.pickupLng = null;
    } else {
      widget.formData.dropoffLat = null;
      widget.formData.dropoffLng = null;
    }
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() { _searching = true; _error = null; });
      try {
        final r = await DyspatchApi.searchPlaces(q, lat: _biasLat, lng: _biasLng);
        if (mounted) setState(() => _results = r);
      } catch (e) {
        if (mounted) setState(() => _error = e.toString());
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _pick(Map<String, dynamic> place) {
    final name = (place['name'] ?? '') as String;
    final addr = (place['address'] ?? '') as String;
    final label = addr.isNotEmpty && addr != name ? '$name, $addr' : name;
    final lat = (place['lat'] as num).toDouble();
    final lng = (place['lng'] as num).toDouble();
    final f = widget.formData;
    if (_editingFrom) {
      _fromController.text = label;
      f.pickup = label; f.pickupLat = lat; f.pickupLng = lng;
      _biasLat = lat; _biasLng = lng;
    } else {
      _toController.text = label;
      f.dropoff = label; f.dropoffLat = lat; f.dropoffLng = lng;
    }
    setState(() => _results = []);
    if (f.pickupLat != null && f.dropoffLat != null) {
      FocusScope.of(context).unfocus();
      widget.onNext();
    } else {
      (f.pickupLat == null ? _fromFocus : _toFocus).requestFocus();
    }
  }

  Future<void> _useMyLocation() async {
    setState(() { _searching = true; _error = null; });
    try {
      final loc = Location();
      if (!await loc.serviceEnabled() && !await loc.requestService()) throw Exception('Turn on location services');
      var perm = await loc.hasPermission();
      if (perm == PermissionStatus.denied) perm = await loc.requestPermission();
      if (perm != PermissionStatus.granted && perm != PermissionStatus.grantedLimited) throw Exception('Location permission denied');
      final d = await loc.getLocation();
      final r = await DyspatchApi.reverse(d.latitude!, d.longitude!);
      _editingFrom = true;
      _pick({'name': (r['address'] as String?) ?? 'Current location', 'address': '', 'lat': d.latitude, 'lng': d.longitude});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Widget _searchField({
    required TextEditingController controller,
    required FocusNode focus,
    required String hint,
    required Color dotColor,
    bool isDot = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          isDot
              ? Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                  ),
                )
              : Icon(Icons.search, color: Colors.grey.shade500, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onChanged: (v) { setState(() {}); _onType(v); },
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() { controller.clear(); _results = []; }),
              child: Icon(Icons.close, color: Colors.grey.shade600, size: 18),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _searchField(
            controller: _fromController,
            focus: _fromFocus,
            hint: 'From (pickup address)',
            dotColor: Colors.transparent,
          ),
          const SizedBox(height: 12),
          _searchField(
            controller: _toController,
            focus: _toFocus,
            hint: 'To (drop-off address)',
            dotColor: const Color(0xFF298341),
            isDot: true,
          ),
          const SizedBox(height: 12),
          if (_editingFrom)
            TextButton.icon(
              onPressed: _searching ? null : _useMyLocation,
              icon: const Icon(Icons.my_location, size: 18, color: Color(0xFF298341)),
              label: const Text('Use my current location', style: TextStyle(fontFamily: 'Montserrat', color: Color(0xFF298341), fontWeight: FontWeight.w600)),
            ),
          if (_searching) const LinearProgressIndicator(color: Color(0xFF298341), minHeight: 2),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: _results.map((p) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.circle_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  title: Text(
                    (p['name'] ?? '') as String,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                  ),
                  subtitle: Text(
                    (p['address'] ?? '') as String,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  onTap: () => _pick(p),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: Address confirmation (auto-advances via step 1 tap; kept as a
// standalone step in case you want a manual "confirm addresses" screen) ──
class _AddressSuggestionsStep extends StatelessWidget {
  final _DeliveryFormData formData;
  final VoidCallback onNext;
  const _AddressSuggestionsStep({required this.formData, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirm pickup & drop-off',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
          ),
          const SizedBox(height: 16),
          _addressTile(context, 'Pickup', formData.pickup),
          const SizedBox(height: 12),
          _addressTile(context, 'Dropoff', formData.dropoff),
          const Spacer(),
          _ContinueButton(label: 'Continue', onPressed: onNext),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _addressTile(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Package details ──
class _PackageDetailsStep extends StatefulWidget {
  final _DeliveryFormData formData;
  final VoidCallback onNext;
  const _PackageDetailsStep({required this.formData, required this.onNext});

  @override
  State<_PackageDetailsStep> createState() => _PackageDetailsStepState();
}

class _PackageDetailsStepState extends State<_PackageDetailsStep> {
  late TextEditingController _descController;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(
      text: widget.formData.packageDescription,
    );
    _nameController = TextEditingController(
      text: widget.formData.recipientName,
    );
    _phoneController = TextEditingController(
      text: widget.formData.recipientPhone,
    );
  }

  @override
  void dispose() {
    _descController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Widget _radioTile(String label) {
    return RadioListTile<String>(
      value: label,
      groupValue: widget.formData.packageType,
      onChanged: (val) => setState(() => widget.formData.packageType = val!),
      activeColor: const Color(0xFF298341),
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 14,
          color: Theme.of(context).colorScheme.inversePrimary,
        ),
      ),
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.inversePrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 14,
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Package type',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
          ),
          _radioTile('Small Package'),
          _radioTile('Medium Package'),
          _radioTile('Large Package'),
          const SizedBox(height: 16),
          _textField(
            'Package description (optional)',
            _descController,
            'e.g. small box with a phone inside',
          ),
          const SizedBox(height: 20),
          _textField('Recipient name *', _nameController, 'e.g. Mr. Chris'),
          const SizedBox(height: 20),
          _textField('Recipient phone *', _phoneController, 'e.g. 08102437791'),
          const SizedBox(height: 8),
          const Text('The recipient gets a 4-digit delivery code by SMS to confirm handover.',
              style: TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 32),
          _ContinueButton(
            label: 'Continue',
            onPressed: () {
              final name = _nameController.text.trim();
              final phone = _phoneController.text.replaceAll(RegExp(r'[^0-9+]'), '');
              if (name.isEmpty || phone.length < 10) {
                toast(context, 'Enter the recipient\'s name and a valid phone number', error: true);
                return;
              }
              FocusScope.of(context).unfocus();
              widget.formData.packageDescription = _descController.text.trim();
              widget.formData.recipientName = name;
              widget.formData.recipientPhone = phone;
              widget.onNext();
            },
          ),
        ],
      ),
    );
  }
}

// ── Step 4: Confirm delivery (live quote + create) ──
class _ConfirmDeliveryStep extends StatefulWidget {
  final _DeliveryFormData formData;
  final bool active;
  const _ConfirmDeliveryStep({required this.formData, required this.active});

  @override
  State<_ConfirmDeliveryStep> createState() => _ConfirmDeliveryStepState();
}

class _ConfirmDeliveryStepState extends State<_ConfirmDeliveryStep> {
  Map<String, dynamic>? _quote;
  bool _loading = false;
  bool _submitting = false;
  String? _error;

  @override
  void didUpdateWidget(covariant _ConfirmDeliveryStep old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _fetchQuote();
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) _fetchQuote();
  }

  Future<void> _fetchQuote() async {
    setState(() { _loading = true; _error = null; });
    try {
      final q = await DyspatchApi.quote(widget.formData.toJson());
      if (!mounted) return;
      setState(() => _quote = q);
      final bal = (q['wallet_balance_kobo'] as num?)?.toInt() ?? 0;
      final fee = (q['fee_kobo'] as num?)?.toInt() ?? 0;
      if (bal < fee && widget.formData.paymentMethod == 'wallet') {
        setState(() => widget.formData.paymentMethod = 'cash');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final order = await DyspatchApi.createOrder(widget.formData.toJson());
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DeliveryCreated(order: order)));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _choice(String label, String sub, bool selected, VoidCallback onTap, {bool enabled = true}) {
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF298341).withOpacity(0.10) : Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? const Color(0xFF298341) : Colors.transparent, width: 1.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600, fontSize: 13, color: Theme.of(context).colorScheme.inversePrimary)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 11, color: Colors.grey)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.formData;
    final q = _quote;
    final fee = (q?['fee_kobo'] as num?)?.toInt() ?? 0;
    final bal = (q?['wallet_balance_kobo'] as num?)?.toInt() ?? 0;
    final serviceable = q?['serviceable'] == true;
    final walletOk = bal >= fee;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(context, 'Pickup', f.pickup.isEmpty ? '—' : f.pickup),
          _row(context, 'Dropoff', f.dropoff.isEmpty ? '—' : f.dropoff),
          _row(context, 'Recipient', '${f.recipientName} · ${f.recipientPhone}'),
          _row(context, 'Package', f.packageType),
          const SizedBox(height: 10),
          Row(children: [
            _choice('Standard', '60 – 120 mins', f.deliveryType == 'standard', () { setState(() => f.deliveryType = 'standard'); _fetchQuote(); }),
            const SizedBox(width: 10),
            _choice('Express', '20 – 40 mins', f.deliveryType == 'express', () { setState(() => f.deliveryType = 'express'); _fetchQuote(); }),
          ]),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(color: Color(0xFF298341))))
          else if (q != null) ...[
            _row(context, 'Delivery fee', '${naira(fee)}  ·  ${q['distance_km']} km'),
            if (!serviceable)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  q['zone'] == null ? 'Pickup is outside our service area.' : "We're not live in ${q['zone']['name']} yet — coming soon!",
                  style: const TextStyle(color: Colors.red, fontFamily: 'Montserrat', fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 10),
            Text('Payment method', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(children: [
              _choice('Wallet', '${naira(bal)} available', f.paymentMethod == 'wallet', () => setState(() => f.paymentMethod = 'wallet'), enabled: walletOk),
              const SizedBox(width: 10),
              _choice('Cash', 'Pay the rider at pickup', f.paymentMethod == 'cash', () => setState(() => f.paymentMethod = 'cash')),
            ]),
            if (!walletOk)
              TextButton(
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const TopUpScreen()));
                  _fetchQuote();
                },
                child: Text('Top up wallet (need ${naira(fee - bal)} more)', style: const TextStyle(color: Color(0xFF298341), fontWeight: FontWeight.w600, fontFamily: 'Montserrat')),
              ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontFamily: 'Montserrat', fontSize: 13)),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (q != null && serviceable && !_submitting && !_loading) ? _submit : (q == null && !_loading ? _fetchQuote : null),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF298341),
                disabledBackgroundColor: const Color(0xFF2D6A3E),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                  : Text(
                      q == null ? 'Get price' : 'Confirm delivery · ${naira(fee)}',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Shared continue button ──
class _ContinueButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _ContinueButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF298341),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
