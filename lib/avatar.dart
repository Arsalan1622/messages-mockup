import 'package:flutter/material.dart';

import 'models.dart';

/// Google Messages style avatar: coloured circle with a person icon, or
/// initials when the sender is a saved contact.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.address,
    this.displayName,
    this.showInitials = false,
    this.radius = 26,
  });

  final String address;
  final String? displayName;
  final bool showInitials;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = avatarColorFor(address);
    final initials =
        (showInitials && displayName != null) ? initialsFor(displayName!) : '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: initials.isEmpty
          ? Icon(Icons.person, color: Colors.white, size: radius * 1.25)
          : Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.75,
                fontWeight: FontWeight.w500,
              ),
            ),
    );
  }
}
