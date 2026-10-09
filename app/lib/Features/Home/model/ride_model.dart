import 'package:latlong2/latlong.dart';
import 'rider_model.dart';

/// Possible statuses for a delivery ride (mirrors the backend order status).
enum RideStatus {
  pending,
  matched,
  otpVerified,
  pickedUp,
  enRoute,
  arrived,
  delivered,
  cancelled,
  failed;

  static RideStatus fromString(String value) {
    switch (value) {
      case 'pending':       return RideStatus.pending;
      case 'matched':       return RideStatus.matched;
      case 'otp_verified':  return RideStatus.otpVerified;
      case 'picked_up':     return RideStatus.pickedUp;
      case 'en_route':      return RideStatus.enRoute;
      case 'arrived':       return RideStatus.arrived;
      case 'delivered':     return RideStatus.delivered;
      case 'cancelled':     return RideStatus.cancelled;
      case 'failed':        return RideStatus.failed;
      default:              return RideStatus.pending;
    }
  }

  bool get isActive => this == matched || this == otpVerified || this == pickedUp || this == enRoute || this == arrived;
  bool get isFinished => this == delivered || this == cancelled || this == failed;

  String get label {
    switch (this) {
      case RideStatus.pending:     return 'Finding rider';
      case RideStatus.matched:     return 'Matched';
      case RideStatus.otpVerified: return 'OTP Verified';
      case RideStatus.pickedUp:    return 'Picked Up';
      case RideStatus.enRoute:     return 'In Transit';
      case RideStatus.arrived:     return 'Arrived';
      case RideStatus.delivered:   return 'Delivered';
      case RideStatus.cancelled:   return 'Cancelled';
      case RideStatus.failed:      return 'Failed';
    }
  }
}

class TimelineStep {
  final String label;
  final String? note;
  final DateTime? time;
  final bool isItem;
  const TimelineStep({required this.label, this.note, this.time, this.isItem = false});
}

class ParcelItem {
  final String code;
  final String description;
  final int quantity;
  final String statusLabel;
  final String status;
  const ParcelItem({required this.code, required this.description, required this.quantity, required this.status, required this.statusLabel});
}

/// Full ride/order returned from GET /orders/{trackId} (or public /track/{trackId}).
class RideModel {
  final String orderId; // Track ID, e.g. BEN-48213
  final String orderNo;
  final RideStatus status;
  final LatLng pickupLocation;
  final String pickupAddress;
  final LatLng dropoffLocation;
  final String dropoffAddress;
  final String route;
  final int etaMinutes;
  final RiderModel? rider;
  final List<TimelineStep> timeline;
  final List<ParcelItem> items;
  final String? deliveryCode;
  final String? pickupCode;
  final String? fee;
  final bool isOwner;
  final bool canCancel;
  final DateTime? arrivedAt;
  final DateTime? deliveredAt;

  const RideModel({
    required this.orderId,
    required this.status,
    required this.dropoffLocation,
    required this.dropoffAddress,
    required this.etaMinutes,
    this.rider,
    this.orderNo = '',
    this.pickupLocation = const LatLng(0, 0),
    this.pickupAddress = '',
    this.route = '',
    this.timeline = const [],
    this.items = const [],
    this.deliveryCode,
    this.pickupCode,
    this.fee,
    this.isOwner = false,
    this.canCancel = false,
    this.arrivedAt,
    this.deliveredAt,
  });

  static DateTime? _t(dynamic v) => v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toLocal() : null;

  factory RideModel.fromJson(Map<String, dynamic> json) {
    LatLng pt(Map? m) => LatLng(((m?['lat']) as num?)?.toDouble() ?? 0, ((m?['lng']) as num?)?.toDouble() ?? 0);
    return RideModel(
      orderId: (json['track_id'] ?? json['order_id']) as String,
      orderNo: (json['order_no'] ?? '') as String,
      status: RideStatus.fromString((json['status'] ?? 'pending') as String),
      pickupLocation: pt(json['pickup'] as Map?),
      pickupAddress: ((json['pickup'] as Map?)?['address'] ?? '') as String,
      dropoffLocation: pt(json['dropoff'] as Map?),
      dropoffAddress: ((json['dropoff'] as Map?)?['address'] ?? '') as String,
      route: (json['route'] ?? '') as String,
      etaMinutes: (json['eta_minutes'] as num?)?.toInt() ?? 0,
      rider: json['rider'] is Map ? RiderModel.fromJson(Map<String, dynamic>.from(json['rider'])) : null,
      timeline: ((json['timeline'] as List?) ?? const [])
          .map((e) => TimelineStep(label: e['label'] ?? '', note: e['note'], time: _t(e['time']), isItem: e['item_id'] != null))
          .toList(),
      items: ((json['items'] as List?) ?? const [])
          .map((e) => ParcelItem(code: e['item_code'] ?? '', description: e['description'] ?? '', quantity: (e['quantity'] as num?)?.toInt() ?? 1, status: e['status'] ?? '', statusLabel: e['status_label'] ?? ''))
          .toList(),
      deliveryCode: json['delivery_code'] as String?,
      pickupCode: json['pickup_code'] as String?,
      fee: json['fee'] as String?,
      isOwner: json.containsKey('payment_status'),
      canCancel: json['can_cancel'] == true,
      arrivedAt: _t(json['arrived_at']),
      deliveredAt: _t(json['delivered_at']),
    );
  }
}
