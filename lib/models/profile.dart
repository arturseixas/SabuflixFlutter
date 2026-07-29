class Profile {
  final String id;
  final String name;
  final String avatarUrl;
  final String maxAgeRating; // e.g. 'L', '10', '12', '14', '16', '18'
  final int colorValue;

  Profile({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.maxAgeRating,
    this.colorValue = 0xFF4285F4,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      name: json['name'],
      avatarUrl: json['avatarUrl'] ?? '',
      maxAgeRating: json['maxAgeRating'] ?? '18',
      colorValue: json['colorValue'] ?? 0xFF4285F4,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'maxAgeRating': maxAgeRating,
      'colorValue': colorValue,
    };
  }

  Profile copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? maxAgeRating,
    int? colorValue,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      maxAgeRating: maxAgeRating ?? this.maxAgeRating,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}
