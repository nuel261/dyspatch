import 'package:latlong2/latlong.dart';
import 'rider_model.dart';

/// Possible statuses for a delivery ride.
enum RideStatus {
  matched,
  otpVerified,
  pickedUp,
  enRoute,
  arrived, // 👈 add this
  delivered;

  static RideStatus fromString(String value) {
    switch (value) {
      case 'matched':
        return RideStatus.matched;
      case 'otp_verified':
        return RideStatus.otpVerified;
      case 'picked_up':
        return RideStatus.pickedUp;
      case 'en_route':
        return RideStatus.enRoute;
      case 'arrived':
        return RideStatus.arrived; // 👈
      case 'delivered':
        return RideStatus.delivered;
      default:
        return RideStatus.matched;
    }
  }

  String get label {
    switch (this) {
      case RideStatus.matched:
        return 'Matched';
      case RideStatus.otpVerified:
        return 'OTP Verified';
      case RideStatus.pickedUp:
        return 'Picked Up';
      case RideStatus.enRoute:
        return 'En Route';
      case RideStatus.arrived:
        return 'Arrived'; // 👈
      case RideStatus.delivered:
        return 'Delivered';
    }
  }
}

/// Represents a full ride/order returned from GET /orders/{orderId}
class RideModel {
  final String orderId;
  final RideStatus status;
  final LatLng dropoffLocation;
  final String dropoffAddress;
  final int etaMinutes;
  final RiderModel rider;

  const RideModel({
    required this.orderId,
    required this.status,
    required this.dropoffLocation,
    required this.dropoffAddress,
    required this.etaMinutes,
    required this.rider,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      orderId: json['order_id'] as String,
      status: RideStatus.fromString(json['status'] as String),
      dropoffLocation: LatLng(
        (json['dropoff']['lat'] as num).toDouble(),
        (json['dropoff']['lng'] as num).toDouble(),
      ),
      dropoffAddress: json['dropoff']['address'] as String,
      etaMinutes: json['eta_minutes'] as int,
      rider: RiderModel.fromJson(json['rider'] as Map<String, dynamic>),
    );
  }
}
