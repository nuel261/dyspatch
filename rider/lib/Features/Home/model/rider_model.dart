/// Represents the assigned rider for a delivery order.
class RiderModel {
  final String name;
  final String photoUrl;
  final double rating;
  final String plate;
  final String phone;

  const RiderModel({
    required this.name,
    required this.photoUrl,
    required this.rating,
    required this.plate,
    required this.phone,
  });

  factory RiderModel.fromJson(Map<String, dynamic> json) {
    return RiderModel(
      name: json['name'] as String,
      photoUrl: json['photo_url'] as String,
      rating: (json['rating'] as num).toDouble(),
      plate: json['plate'] as String,
      phone: json['phone'] as String,
    );
  }
}
