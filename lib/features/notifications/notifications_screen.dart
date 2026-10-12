import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/nav/app_nav.dart';
import '../auth/application/auth_controller.dart';
import '../auth/application/auth_role_family.dart';
import '../scheduled_care/presentation/scheduled_care_resource_resolver.dart';
import 'application/notification_center_controller.dart';
import 'application/notification_navigation_resolver.dart';
import 'domain/notification_models.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.role,
    this.onOpenDoctorRequest,
    this.onOpenDoctorAppointment,
  });

  final AuthRoleFamily? role;
  final ValueChanged<String>? onOpenDoctorRequest;
  final ValueChanged<String>? onOpenDoctorAppointment;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with RouteAware {
  final ScrollController _scrollController = ScrollController();
  NotificationCenterController? _controller;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextController = context.read<NotificationCenterController?>();
    if (!identical(nextController, _controller)) {
      _controller?.setInboxVisible(false);
      _controller = nextController;
      nextController?.setInboxVisible(true);
      if (nextController != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !identical(_controller, nextController)) return;
          unawaited(
            nextController.hasLoaded
                ? nextController.refresh()
                : nextController.load(),
          );
        });
      }
    }
    final nextRoute = ModalRoute.of(context);
    if (!identical(nextRoute, _route) && nextRoute != null) {
      if (_route != null) AppNav.routeObserver.unsubscribe(this);
      _route = nextRoute;
      AppNav.routeObserver.subscribe(this, nextRoute);
    }
  }

  @override
  void didPopNext() {
    _controller?.setInboxVisible(true);
    unawaited(_controller?.refresh());
  }

  @override
  void didPushNext() => _controller?.setInboxVisible(false);

  @override
  void dispose() {
    AppNav.routeObserver.unsubscribe(this);
    _controller?.setInboxVisible(false);
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 280) {
      unawaited(_controller?.loadMore());
    }
  }

  AuthRoleFamily get _role {
    if (widget.role != null) return widget.role!;
    return AuthRoles.familyOf(context.read<AuthController?>()?.globalRole);
  }

  Future<void> _open(InboxNotification notification) async {
    unawaited(_controller?.markRead(notification.id));
    final resolution = NotificationNavigationResolver.resolve(
      notification,
      _role,
    );
    if (resolution.status == NotificationNavigationStatus.noDestination) return;
    if (resolution.status == NotificationNavigationStatus.unavailable) {
      _showUnavailable();
      return;
    }
    final id = resolution.resourceId!;
    if (_role == AuthRoleFamily.patient) {
      if (resolution.resource ==
          NotificationNavigationResource.bookingRequest) {
        await ScheduledCareResourceResolver.openRequest(context, id);
      } else {
        await ScheduledCareResourceResolver.openAppointment(context, id);
      }
      return;
    }
    if (_role == AuthRoleFamily.doctor) {
      if (resolution.resource ==
          NotificationNavigationResource.bookingRequest) {
        widget.onOpenDoctorRequest?.call(id);
      } else {
        widget.onOpenDoctorAppointment?.call(id);
      }
    }
  }

  void _showUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cette destination n’est pas disponible.')),
    );
  }

  Future<void> _markAllRead() async {
    await _controller?.markAllRead();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Toutes les notifications ont été marquées comme lues.'),
        backgroundColor: Color(0xFF1FBF9A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationCenterController?>();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1D2939)),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Notifications',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
        actions: [
          if (MediaQuery.textScalerOf(context).scale(14) > 22)
            IconButton(
              tooltip: 'Tout lire',
              onPressed:
                  controller == null ||
                      controller.isMarkingAll ||
                      (controller.unreadCount ?? 0) == 0
                  ? null
                  : _markAllRead,
              icon: const Icon(Icons.done_all_rounded),
            )
          else
            TextButton(
              onPressed:
                  controller == null ||
                      controller.isMarkingAll ||
                      (controller.unreadCount ?? 0) == 0
                  ? null
                  : _markAllRead,
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
      body: controller == null
          ? const _NotificationError(
              message: 'Les notifications ne sont pas disponibles.',
            )
          : _NotificationBody(
              controller: controller,
              scrollController: _scrollController,
              onOpen: _open,
            ),
    );
  }
}

class _NotificationBody extends StatelessWidget {
  const _NotificationBody({
    required this.controller,
    required this.scrollController,
    required this.onOpen,
  });

  final NotificationCenterController controller;
  final ScrollController scrollController;
  final ValueChanged<InboxNotification> onOpen;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading && controller.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.state == NotificationCenterLoadState.failed &&
        controller.items.isEmpty) {
      return _NotificationError(
        message:
            controller.failure?.message ??
            'Impossible de charger les notifications.',
        onRetry: controller.load,
      );
    }
    if (controller.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: const CustomScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          slivers: [SliverFillRemaining(child: _NotificationEmptyState())],
        ),
      );
    }
    return Column(
      children: [
        if (controller.failure != null)
          MaterialBanner(
            content: Text(controller.failure!.message),
            actions: [
              TextButton(
                onPressed: controller.refresh,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: ListView.builder(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount:
                  controller.items.length + (controller.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == controller.items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final notification = controller.items[index];
                return _NotificationCard(
                  notification: notification,
                  onTap: () => onOpen(notification),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationError extends StatelessWidget {
  const _NotificationError({required this.message, this.onRetry});

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 52,
            color: Color(0xFF667085),
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ],
      ),
    ),
  );
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: const BoxDecoration(
            color: Color(0x1A1FBF9A),
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
          'Aucune notification',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Vous n’avez pas de nouvelles notifications',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: const Color(0xFF667085),
          ),
        ),
      ],
    ),
  );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final InboxNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _accent(notification);
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead ? Colors.white : const Color(0x0D1FBF9A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? const Color(0xFFE5E7EB)
                  : const Color(0x331FBF9A),
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
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon(notification), color: accent, size: 24),
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
                        if (!notification.isRead)
                          const SizedBox(
                            width: 8,
                            height: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFF1FBF9A),
                                shape: BoxShape.circle,
                              ),
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
                        Flexible(
                          child: Text(
                            _relativeTime(notification.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF667085),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _accent(InboxNotification value) => switch (value.priority) {
    InboxNotificationPriority.critical => const Color(0xFFDC2626),
    InboxNotificationPriority.high => const Color(0xFFF59E0B),
    InboxNotificationPriority.medium => const Color(0xFF1FBF9A),
    InboxNotificationPriority.low => const Color(0xFF3B82F6),
    InboxNotificationPriority.unknown => const Color(0xFF667085),
  };

  static IconData _icon(InboxNotification value) => switch (value.category) {
    InboxNotificationCategory.appointment => Icons.event_available_outlined,
    InboxNotificationCategory.consultation => Icons.medical_services_outlined,
    InboxNotificationCategory.medication => Icons.medication_outlined,
    InboxNotificationCategory.message => Icons.chat_bubble_outline,
    InboxNotificationCategory.passport => Icons.folder_shared_outlined,
    _ => Icons.notifications_none_rounded,
  };

  static String _relativeTime(DateTime instant) {
    final elapsed = DateTime.now().toUtc().difference(instant.toUtc());
    if (elapsed.isNegative || elapsed.inMinutes < 1) return 'À l’instant';
    if (elapsed.inHours < 1) return 'Il y a ${elapsed.inMinutes} min';
    if (elapsed.inDays < 1) return 'Il y a ${elapsed.inHours} h';
    if (elapsed.inDays < 7) return 'Il y a ${elapsed.inDays} j';
    final local = instant.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}
