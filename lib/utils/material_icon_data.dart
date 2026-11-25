import 'package:flutter/material.dart';

/// Resolve códigos salvos no banco para ícones Material incluídos no app.
IconData materialIconFromCode(Object? value) {
  if (value is! num) return Icons.event_rounded;

  final icons = <int, IconData>{
    Icons.child_care_rounded.codePoint: Icons.child_care_rounded,
    Icons.emoji_people_rounded.codePoint: Icons.emoji_people_rounded,
    Icons.local_fire_department_rounded.codePoint:
        Icons.local_fire_department_rounded,
    Icons.favorite_rounded.codePoint: Icons.favorite_rounded,
    Icons.shield_rounded.codePoint: Icons.shield_rounded,
    Icons.public_rounded.codePoint: Icons.public_rounded,
    Icons.home_rounded.codePoint: Icons.home_rounded,
    Icons.person_add_alt_1_rounded.codePoint: Icons.person_add_alt_1_rounded,
    Icons.music_note_rounded.codePoint: Icons.music_note_rounded,
    Icons.camera_alt_rounded.codePoint: Icons.camera_alt_rounded,
    Icons.child_care_rounded.codePoint: Icons.child_care_rounded,
    Icons.emoji_people_rounded.codePoint: Icons.emoji_people_rounded,
    Icons.local_fire_department_rounded.codePoint:
        Icons.local_fire_department_rounded,
    Icons.shield_rounded.codePoint: Icons.shield_rounded,
    Icons.home_rounded.codePoint: Icons.home_rounded,
    Icons.person_add_alt_1_rounded.codePoint: Icons.person_add_alt_1_rounded,
    Icons.access_time_filled_rounded.codePoint:
        Icons.access_time_filled_rounded,
    Icons.volunteer_activism_rounded.codePoint:
        Icons.volunteer_activism_rounded,
    Icons.menu_book_rounded.codePoint: Icons.menu_book_rounded,
    Icons.wb_sunny_rounded.codePoint: Icons.wb_sunny_rounded,
    Icons.auto_stories_rounded.codePoint: Icons.auto_stories_rounded,
    Icons.apartment_rounded.codePoint: Icons.apartment_rounded,
    Icons.groups_rounded.codePoint: Icons.groups_rounded,
    Icons.church_rounded.codePoint: Icons.church_rounded,
    Icons.wine_bar_rounded.codePoint: Icons.wine_bar_rounded,
    Icons.family_restroom_rounded.codePoint: Icons.family_restroom_rounded,
    Icons.event_rounded.codePoint: Icons.event_rounded,
    Icons.event_available_rounded.codePoint: Icons.event_available_rounded,
    Icons.calendar_month_rounded.codePoint: Icons.calendar_month_rounded,
    Icons.school_rounded.codePoint: Icons.school_rounded,
    Icons.lightbulb_rounded.codePoint: Icons.lightbulb_rounded,
    Icons.handshake_rounded.codePoint: Icons.handshake_rounded,
    Icons.mic_rounded.codePoint: Icons.mic_rounded,
    Icons.headphones_rounded.codePoint: Icons.headphones_rounded,
    Icons.spa_rounded.codePoint: Icons.spa_rounded,
    Icons.savings_rounded.codePoint: Icons.savings_rounded,
    Icons.restaurant_rounded.codePoint: Icons.restaurant_rounded,
    Icons.water_drop_rounded.codePoint: Icons.water_drop_rounded,
    Icons.health_and_safety_rounded.codePoint: Icons.health_and_safety_rounded,
    Icons.directions_car_rounded.codePoint: Icons.directions_car_rounded,
    Icons.emoji_events_rounded.codePoint: Icons.emoji_events_rounded,
    Icons.star_rounded.codePoint: Icons.star_rounded,
    Icons.bolt_rounded.codePoint: Icons.bolt_rounded,
  };

  return icons[value.toInt()] ?? Icons.event_rounded;
}
