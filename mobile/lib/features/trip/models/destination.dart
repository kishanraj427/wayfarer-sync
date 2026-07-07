import '../../../core/constants/appStrings.dart';

class Destination {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int order;

  const Destination({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.order,
  });

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? AppStrings.destinationFallback,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }
}
