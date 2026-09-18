import 'package:flutter/material.dart';

/// Icon for a profile avatar key (see `profileAvatarKeys`).
IconData profileIcon(String key) => switch (key) {
      'movie' => Icons.movie_rounded,
      'star' => Icons.star_rounded,
      'rocket' => Icons.rocket_launch_rounded,
      'pets' => Icons.pets_rounded,
      'gamepad' => Icons.sports_esports_rounded,
      'favorite' => Icons.favorite_rounded,
      'music' => Icons.music_note_rounded,
      'sports' => Icons.sports_soccer_rounded,
      'child' => Icons.child_care_rounded,
      _ => Icons.person_rounded,
    };
