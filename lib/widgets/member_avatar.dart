import 'package:flutter/material.dart';

import '../models/user_profile.dart';

class MemberAvatar extends StatelessWidget {
  final UserProfile user;
  final double radius;

  const MemberAvatar({super.key, required this.user, required this.radius});

  @override
  Widget build(BuildContext context) {
    final photoUrl = user.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitials(),
        ),
      );
    }
    return _buildInitials();
  }

  Widget _buildInitials() => CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFF10B981),
    child: Text(
      user.initials,
      style: TextStyle(
        fontSize: radius * 0.75,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  );
}
