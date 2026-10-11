import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'application/notification_controller.dart';
import 'data/notification_models.dart';
import 'notification_navigation.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scroll = ScrollController();
  NotificationController? _notificationController;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<NotificationController>();
    if (identical(_notificationController, controller)) return;

    _notificationController?.setCenterVisible(false);
    _notificationController = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_notificationController, controller)) {
        controller.setCenterVisible(true);
      }
    });
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _notificationController?.setCenterVisible(false);
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 240) {
      unawaited(_notificationController?.loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationController>();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1D2939)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
        actions: [
          TextButton(
            onPressed: controller.unreadCount == 0
                ? null
                : () => unawaited(controller.markAllRead()),
            child: Text(
              'Tout lire',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1FBF9A),
              ),
            ),
          ),
        ],
      ),
      body: _body(controller),
    );
  }

  Widget _body(NotificationController controller) {
    if (controller.isLoading && controller.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.items.isEmpty && controller.error != null) {
      return _ErrorState(onRetry: controller.refresh);
    }
    if (controller.items.isEmpty) return const _EmptyState();
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount:
            controller.items.length +
            (controller.isLoadingMore || controller.error != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == controller.items.length) {
            if (controller.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                controller.error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFB42318),
                ),
              ),
            );
          }
          return _NotificationCard(notification: controller.items[index]);
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});
  final InboxNotification notification;

  @override
  Widget build(BuildContext context) {
    final color = _notificationColor(notification.type);
    final canNavigate =
        notification.reference.type != NotificationReferenceType.none;
    return GestureDetector(
      onTap: () {
        unawaited(
          context.read<NotificationController>().markRead(notification),
        );
        if (canNavigate) {
          unawaited(NotificationNavigation.open(context, notification));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.read
              ? Colors.white
              : const Color(0xFF1FBF9A).withValues(alpha: .05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.read
                ? const Color(0xFFE5E7EB)
                : const Color(0xFF1FBF9A).withValues(alpha: .2),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _notificationIcon(notification.type),
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.titleFr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1D2939),
                          ),
                        ),
                      ),
                      if (!notification.read)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1FBF9A),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.bodyFr,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF667085),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Color(0xFF667085),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _relativeTime(notification.createdAt, DateTime.now()),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF667085),
                        ),
                      ),
                      if (canNavigate) ...[
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Color(0xFF1FBF9A),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF1FBF9A).withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.notifications_none,
            size: 60,
            color: Color(0xFF1FBF9A),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Aucune Notification',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Vous n\'avez pas de nouvelles notifications',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: const Color(0xFF667085),
          ),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_rounded, size: 52, color: Color(0xFF667085)),
        const SizedBox(height: 16),
        const Text('Impossible de charger les notifications.'),
        TextButton(
          onPressed: () => unawaited(onRetry()),
          child: const Text('Réessayer'),
        ),
      ],
    ),
  );
}

String _relativeTime(DateTime createdAt, DateTime now) {
  final difference = now.toUtc().difference(createdAt.toUtc());
  if (difference.isNegative || difference.inMinutes < 1) return 'À l’instant';
  if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes} min';
  if (difference.inHours < 24) return 'Il y a ${difference.inHours} h';
  if (difference.inDays < 7) return 'Il y a ${difference.inDays} j';
  return '${createdAt.toLocal().day.toString().padLeft(2, '0')}/${createdAt.toLocal().month.toString().padLeft(2, '0')}/${createdAt.toLocal().year}';
}

IconData _notificationIcon(InboxNotificationType type) => switch (type) {
  InboxNotificationType.appointmentConfirmed ||
  InboxNotificationType.doctorBookingProposalAccepted => Icons.check_circle,
  InboxNotificationType.doctorBookingTimeProposed => Icons.event_repeat_rounded,
  InboxNotificationType.doctorBookingRequestCreated => Icons.event_note_rounded,
  InboxNotificationType.doctorBookingRequestDeclined ||
  InboxNotificationType.doctorBookingRequestCancelledByPatient ||
  InboxNotificationType.doctorBookingProposalDeclined ||
  InboxNotificationType.appointmentCancelledByPatient ||
  InboxNotificationType.appointmentCancelledByProfessional ||
  InboxNotificationType.doctorBookingRequestExpired => Icons.event_busy_rounded,
  InboxNotificationType.unknown => Icons.info,
};

Color _notificationColor(InboxNotificationType type) => switch (type) {
  InboxNotificationType.appointmentConfirmed ||
  InboxNotificationType.doctorBookingProposalAccepted => const Color(
    0xFF1FBF9A,
  ),
  InboxNotificationType.doctorBookingTimeProposed ||
  InboxNotificationType.doctorBookingRequestCreated => const Color(0xFF3B82F6),
  InboxNotificationType.doctorBookingRequestDeclined ||
  InboxNotificationType.doctorBookingRequestCancelledByPatient ||
  InboxNotificationType.doctorBookingProposalDeclined ||
  InboxNotificationType.appointmentCancelledByPatient ||
  InboxNotificationType.appointmentCancelledByProfessional ||
  InboxNotificationType.doctorBookingRequestExpired => const Color(0xFFEF4444),
  InboxNotificationType.unknown => const Color(0xFF667085),
};
