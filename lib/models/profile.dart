import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Icons a profile can pick instead of the plain silhouette.
const List<String> profileAvatarKeys = [
  'person',
  'movie',
  'star',
  'rocket',
  'pets',
  'gamepad',
  'favorite',
  'music',
  'sports',
  'child',
];

class Profile {
  final String id;
  final String name;
  final String avatarUrl;
  final String maxAgeRating; // e.g. 'Livre', '10', '12', '14', '16', '18'
  final int colorValue;

  /// One of [profileAvatarKeys].
  final String avatar;

  /// SHA-256 of a 4-digit PIN, or `null` when the profile is open.
  final String? pinHash;

  /// Kids profiles get a simplified home and no adult catalogue rows.
  final bool isKids;

  Profile({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.maxAgeRating,
    this.colorValue = 0xFF4285F4,
    this.avatar = 'person',
    this.pinHash,
    this.isKids = false,
  });

  bool get hasPin => pinHash != null && pinHash!.isNotEmpty;

  /// Age the profile may watch, `Livre` counting as 0.
  int get maxAge =>
      int.tryParse(maxAgeRating.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  static String hashPin(String pin) =>
      sha256.convert(utf8.encode('sabuflix:$pin')).toString();

  bool checkPin(String pin) => hasPin && hashPin(pin) == pinHash;

  factory Profile.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar']?.toString();
    return Profile(
      id: json['id'],
      name: json['name'],
      avatarUrl: json['avatarUrl'] ?? '',
      maxAgeRating: json['maxAgeRating'] ?? '18',
      colorValue: json['colorValue'] ?? 0xFF4285F4,
      avatar: profileAvatarKeys.contains(avatar) ? avatar! : 'person',
      pinHash: json['pinHash']?.toString(),
      isKids: json['isKids'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'maxAgeRating': maxAgeRating,
      'colorValue': colorValue,
      'avatar': avatar,
      'pinHash': pinHash,
      'isKids': isKids,
    };
  }

  Profile copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? maxAgeRating,
    int? colorValue,
    String? avatar,
    String? pinHash,
    bool clearPin = false,
    bool? isKids,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      maxAgeRating: maxAgeRating ?? this.maxAgeRating,
      colorValue: colorValue ?? this.colorValue,
      avatar: avatar ?? this.avatar,
      pinHash: clearPin ? null : (pinHash ?? this.pinHash),
      isKids: isKids ?? this.isKids,
    );
  }
}
