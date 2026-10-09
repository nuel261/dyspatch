/// Represents the assigned rider for a delivery order.
class RiderModel {
  final String name;
  final String photoUrl;
  final double rating;
  final String plate;
  final String phone;
  final String vehicle;
  final double? lat;
  final double? lng;

  const RiderModel({
    required this.name,
    required this.photoUrl,
    required this.rating,
    required this.plate,
    required this.phone,
    this.vehicle = 'bike',
    this.lat,
    this.lng,
  });

  factory RiderModel.fromJson(Map<String, dynamic> json) {
    return RiderModel(
      name: (json['name'] ?? 'Rider') as String,
      photoUrl: (json['photo_url'] ?? '') as String,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      plate: (json['plate'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      vehicle: (json['vehicle_type'] ?? 'bike') as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }
}
