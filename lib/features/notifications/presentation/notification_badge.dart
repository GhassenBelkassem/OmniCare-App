import 'package:flutter/material.dart';

class NotificationBadge extends StatelessWidget {
  const NotificationBadge({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Material(
        color: Colors.white.withValues(alpha: 0.86),
        shape: const CircleBorder(side: BorderSide(color: Color(0xFFD8DEDD))),
        elevation: 1,
        child: InkWell(
          key: const ValueKey('notification-bell'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF172033),
              size: 21,
            ),
          ),
        ),
      ),
      if (count > 0)
        Positioned(
          right: -4,
          top: -5,
          child: Container(
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              count > 99 ? '99+' : '$count',
              key: const ValueKey('notification-badge-count'),
              style: const TextStyle(
                fontSize: 8.5,
                height: 1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
    ],
  );
}
