class CastMember {
  final int id;
  final String name;
  final String character;
  final String? profilePath;

  CastMember({
    required this.id,
    required this.name,
    required this.character,
    this.profilePath,
  });

  String get fullProfilePath {
    if (profilePath != null && profilePath!.isNotEmpty) {
      return 'https://image.tmdb.org/t/p/w185$profilePath';
    }
    return 'https://via.placeholder.com/185x278/1E1E28/FFFFFF?text=Ator';
  }

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Desconhecido',
      character: json['character'] ?? '',
      profilePath: json['profile_path'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'character': character,
      'profile_path': profilePath,
    };
  }
}
