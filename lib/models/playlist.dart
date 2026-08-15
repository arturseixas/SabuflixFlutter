import 'media_item.dart';

class Playlist {
  final String id;
  final String name;
  final List<MediaItem> items;

  Playlist({
    required this.id,
    required this.name,
    this.items = const [],
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'],
      name: json['name'],
      items: (json['items'] as List?)?.map((i) => MediaItem.fromJson(i)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

  Playlist copyWith({
    String? id,
    String? name,
    List<MediaItem>? items,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
    );
  }
}
