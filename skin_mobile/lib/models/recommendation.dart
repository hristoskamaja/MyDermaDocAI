/// Recommendation `type` values returned by the API.
class RecommendationType {
  static const String selfCare = 'SELF_CARE';
  static const String medicalConsult = 'MEDICAL_CONSULT';
  static const String lifestyle = 'LIFESTYLE';
}

class Recommendation {
  final int id;
  final String name;
  /// "What to do".
  final String description;

  /// Optional parts; null/empty for older recommendations.
  final String? whatToAvoid;
  final String? whenToSeeDoctor;
  final String type;

  Recommendation({
    required this.id,
    required this.name,
    required this.description,
    this.whatToAvoid,
    this.whenToSeeDoctor,
    required this.type,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      whatToAvoid: json['what_to_avoid'] as String?,
      whenToSeeDoctor: json['when_to_see_doctor'] as String?,
      type: json['type'] as String? ?? '',
    );
  }
}
