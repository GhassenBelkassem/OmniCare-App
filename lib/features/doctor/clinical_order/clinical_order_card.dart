import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/network/app_http_client.dart';
import '../../scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';
import 'clinical_order.dart';
import 'clinical_order_api.dart';
import 'clinical_order_controller.dart';

class ClinicalOrderCard extends StatefulWidget {
  const ClinicalOrderCard({super.key, required this.consultationId});
  final String consultationId;
  @override
  State<ClinicalOrderCard> createState() => _ClinicalOrderCardState();
}

class _ClinicalOrderCardState extends State<ClinicalOrderCard> {
  ClinicalOrderController? _controller;
  ClinicalOrderRealtimeTarget? _target;
  VoidCallback? _unregister;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final controller = ClinicalOrderController(
      consultationId: widget.consultationId,
      api: ClinicalOrderApi(context.read<AppHttpClient>()),
    )..addListener(_changed);
    _controller = controller;
    final coordinator = context.read<ScheduledCareRealtimeCoordinator?>();
    if (coordinator != null) {
      _target = ClinicalOrderRealtimeTarget(controller);
      _unregister = coordinator.registerTarget(_target!);
    }
    controller.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _unregister?.call();
    _target?.dispose();
    _controller
      ?..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child:
          controller == null ||
              (controller.isLoading && controller.orders.isEmpty)
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clinical orders',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D2939),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Laboratory · Imaging · Referral', style: _muted()),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ClinicalOrderCategory.values
                      .map(
                        (category) => OutlinedButton(
                          onPressed: () => controller.beginCreate(category),
                          child: Text(category.label),
                        ),
                      )
                      .toList(growable: false),
                ),
                if (controller.failureCode != null ||
                    controller.newerVersionAvailable) ...[
                  const SizedBox(height: 12),
                  Text(
                    controller.conflict
                        ? 'This order changed on another device. Your local edit is preserved.'
                        : controller.newerVersionAvailable
                        ? 'A newer version is available. Your local edit was not replaced.'
                        : controller.failureCode ==
                              'CLINICAL_ORDER_ALREADY_FINALIZED'
                        ? 'This order is finalized and immutable.'
                        : 'The operation failed. Your local edit remains in memory.',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFB42318),
                    ),
                  ),
                ],
                if (controller.editor case final editor?) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    key: ValueKey(
                      '${editor.orderId ?? 'new'}:${editor.category.wire}:${editor.original.fingerprint()}',
                    ),
                    initialValue: editor.draft.value(editor.category),
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: editor.category.fieldLabel,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: controller.updateValue,
                  ),
                  Row(
                    children: [
                      if (controller.conflict ||
                          controller.newerVersionAvailable) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => controller.load(force: true),
                            child: const Text('Reload'),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      TextButton(
                        onPressed: controller.cancelEdit,
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: controller.dirty && !controller.isSaving
                              ? controller.save
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1FBF9A),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                if (!controller.isLoading && controller.orders.isEmpty)
                  Text(
                    'No clinical orders for this consultation.',
                    style: _muted(),
                  ),
                ...controller.orders.map(
                  (order) => _OrderRow(order: order, controller: controller),
                ),
              ],
            ),
    );
  }

  TextStyle _muted() =>
      GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF667085));
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.controller});
  final ClinicalOrder order;
  final ClinicalOrderController controller;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE4E7EC)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                order.category.label,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              order.status == ClinicalOrderStatus.finalized
                  ? 'FINALIZED'
                  : 'DRAFT',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF667085),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(order.definition.value(order.category)),
        const SizedBox(height: 4),
        Text(
          'v${order.version}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: const Color(0xFF667085),
          ),
        ),
        if (order.status == ClinicalOrderStatus.draft) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => controller.beginEdit(order),
                child: const Text('Edit'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: controller.finalizingId == null
                    ? () => controller.finalize(order)
                    : null,
                child: const Text('Finalize'),
              ),
            ],
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Immutable',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF667085),
              ),
            ),
          ),
      ],
    ),
  );
}
