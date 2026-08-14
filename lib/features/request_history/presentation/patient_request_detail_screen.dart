// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../request_core/data/request_failure.dart';
import '../../request_core/data/request_models.dart';
import '../../request_core/domain/request_vocabulary.dart';
import '../../request_core/identity/request_operation_id.dart';
import '../application/patient_requests_controller.dart';
import 'patient_request_journey.dart';
import 'request_status_copy.dart';

class PatientRequestDetailScreen extends StatefulWidget {
  const PatientRequestDetailScreen({super.key, required this.requestId});
  final RequestOperationId requestId;
  @override
  State<PatientRequestDetailScreen> createState() => _DetailState();
}

class _DetailState extends State<PatientRequestDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PatientRequestsController>().loadDetail(widget.requestId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PatientRequestsController>();
    final request = controller.detail;
    if (request == null) {
      final isNotFound =
          controller.detailFailure?.kind == RequestFailureKind.notFound;
      final failed = controller.detailFailure != null;
      return Scaffold(
        appBar: AppBar(title: const Text('Clinic request')),
        body: Center(
          child: failed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isNotFound
                          ? 'Request not found'
                          : 'We could not load this request.',
                    ),
                    TextButton(
                      onPressed: () => controller.loadDetail(widget.requestId),
                      child: const Text('Retry'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    final status = RequestStatusCopy.of(request.patientStatus);
    final journey = PatientRequestJourneyMapper.fromStatus(
      request.patientStatus,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinic request'),
        actions: [
          IconButton(
            tooltip: 'Refresh latest status',
            onPressed: controller.isLoadingDetail
                ? null
                : () => controller.loadDetail(widget.requestId),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.loadDetail(widget.requestId),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (controller.cancellationNotice != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    child: Text(controller.cancellationNotice!),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request details',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Subject: ${request.subjectType == RequestSubjectType.self ? 'Me' : 'Family member'}',
                        ),
                        Text('Situation: ${situationLabel(request.situation)}'),
                        Text(
                          'Submitted: ${_detailDateTime(context, request.submittedAt)}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current status',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(status.icon),
                            const SizedBox(width: 8),
                            Text(
                              status.label,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(status.description),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                PatientRequestJourneyWidget(
                  journey: journey,
                  submittedAt: request.submittedAt,
                ),
                if (request.canProvideInformation &&
                    request.informationRequest != null) ...[
                  const SizedBox(height: 8),
                  _InformationRequiredSection(
                    request: request,
                    submitting: controller.isSubmittingInformation,
                    onSubmit: (payload) =>
                        controller.submitInformationResponse(payload: payload),
                  ),
                ],
                if (request.availableActions.contains(
                  PatientRequestAction.cancel,
                ))
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: FilledButton.icon(
                      onPressed: controller.isCancelling
                          ? null
                          : () => _confirmCancel(controller),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel request'),
                    ),
                  ),
                if (controller.detailFailure != null &&
                    !controller.isCancelling)
                  TextButton(
                    onPressed: () => controller.loadDetail(widget.requestId),
                    child: const Text('Refresh latest status'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(PatientRequestsController controller) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel request?'),
        content: const Text(
          'This will cancel your clinic request if it is still available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) await controller.cancelDetail();
  }
}

String _detailDateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatMediumDate(local)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

class _InformationRequiredSection extends StatelessWidget {
  const _InformationRequiredSection({
    required this.request,
    required this.submitting,
    required this.onSubmit,
  });
  final PatientRequest request;
  final bool submitting;
  final ValueChanged<PatientInformationResponsePayload> onSubmit;
  @override
  Widget build(BuildContext context) {
    final information = request.informationRequest!;
    final header = <Widget>[
      Text(
        'Information required',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text('What the clinic needs'),
      Text(
        _reasonLabel(information.reasonCode),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      if (information.patientInstruction?.isNotEmpty == true) ...[
        const SizedBox(height: 8),
        Text(information.patientInstruction!),
      ],
      const SizedBox(height: 16),
      Text('Your action', style: Theme.of(context).textTheme.titleMedium),
    ];
    final form = switch (information.responseType) {
      InformationResponseType.confirmation => _ConfirmationResponseForm(
        request: request,
        submitting: submitting,
        onSubmit: onSubmit,
      ),
      InformationResponseType.contactPreference =>
        _ContactPreferenceResponseForm(
          request: request,
          submitting: submitting,
          onSubmit: onSubmit,
        ),
      InformationResponseType.availabilityWindows => _AvailabilityResponseForm(
        request: request,
        submitting: submitting,
        onSubmit: onSubmit,
      ),
      InformationResponseType.identityConfirmation => _IdentityResponseForm(
        request: request,
        submitting: submitting,
        onSubmit: onSubmit,
      ),
      InformationResponseType.familyInformationConfirmation =>
        _FamilyResponseForm(
          request: request,
          submitting: submitting,
          onSubmit: onSubmit,
        ),
      InformationResponseType.administrativeSelection ||
      InformationResponseType.weekdayAvailability ||
      InformationResponseType.unknown =>
        const _UnsupportedInformationResponse(),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [...header, const SizedBox(height: 8), form],
        ),
      ),
    );
  }
}

class _ConfirmationResponseForm extends StatefulWidget {
  const _ConfirmationResponseForm({
    required this.request,
    required this.submitting,
    required this.onSubmit,
  });
  final PatientRequest request;
  final bool submitting;
  final ValueChanged<PatientInformationResponsePayload> onSubmit;
  @override
  State<_ConfirmationResponseForm> createState() =>
      _ConfirmationResponseFormState();
}

class _ConfirmationResponseFormState extends State<_ConfirmationResponseForm> {
  bool confirmed = false;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: confirmed,
        onChanged: widget.submitting
            ? null
            : (value) => setState(() => confirmed = value ?? false),
        title: const Text(
          'I confirm I have provided or updated this administrative information.',
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      _SubmitButton(
        enabled: confirmed,
        submitting: widget.submitting,
        onPressed: () => widget.onSubmit(
          ConfirmationInformationResponsePayload(
            informationRequestId:
                widget.request.informationRequest!.informationRequestId,
            expectedVersion: widget.request.version,
          ),
        ),
      ),
    ],
  );
}

class _IdentityResponseForm extends _ConfirmationResponseForm {
  const _IdentityResponseForm({
    required super.request,
    required super.submitting,
    required super.onSubmit,
  });
  @override
  State<_IdentityResponseForm> createState() => _IdentityResponseFormState();
}

class _IdentityResponseFormState extends State<_IdentityResponseForm> {
  bool confirmed = false;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: confirmed,
        onChanged: widget.submitting
            ? null
            : (value) => setState(() => confirmed = value ?? false),
        title: const Text('I confirm my identity information is current.'),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      _SubmitButton(
        enabled: confirmed,
        submitting: widget.submitting,
        onPressed: () => widget.onSubmit(
          IdentityConfirmationInformationResponsePayload(
            informationRequestId:
                widget.request.informationRequest!.informationRequestId,
            expectedVersion: widget.request.version,
            identityInformationConfirmed: true,
          ),
        ),
      ),
    ],
  );
}

class _FamilyResponseForm extends _ConfirmationResponseForm {
  const _FamilyResponseForm({
    required super.request,
    required super.submitting,
    required super.onSubmit,
  });
  @override
  State<_FamilyResponseForm> createState() => _FamilyResponseFormState();
}

class _FamilyResponseFormState extends State<_FamilyResponseForm> {
  bool confirmed = false;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: confirmed,
        onChanged: widget.submitting
            ? null
            : (value) => setState(() => confirmed = value ?? false),
        title: const Text(
          'I confirm the family member information is current.',
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      _SubmitButton(
        enabled: confirmed,
        submitting: widget.submitting,
        onPressed: () => widget.onSubmit(
          FamilyInformationConfirmationResponsePayload(
            informationRequestId:
                widget.request.informationRequest!.informationRequestId,
            expectedVersion: widget.request.version,
            familyInformationConfirmed: true,
          ),
        ),
      ),
    ],
  );
}

class _ContactPreferenceResponseForm extends StatefulWidget {
  const _ContactPreferenceResponseForm({
    required this.request,
    required this.submitting,
    required this.onSubmit,
  });
  final PatientRequest request;
  final bool submitting;
  final ValueChanged<PatientInformationResponsePayload> onSubmit;
  @override
  State<_ContactPreferenceResponseForm> createState() =>
      _ContactPreferenceResponseFormState();
}

class _ContactPreferenceResponseFormState
    extends State<_ContactPreferenceResponseForm> {
  PreferredContactMethod? method;
  bool confirmed = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Choose how the clinic should contact you. This does not change your verified phone number or email.',
      ),
      RadioListTile<PreferredContactMethod>(
        dense: true,
        value: PreferredContactMethod.phone,
        groupValue: method,
        onChanged: widget.submitting
            ? null
            : (value) => setState(() => method = value),
        title: const Text('Phone'),
      ),
      RadioListTile<PreferredContactMethod>(
        dense: true,
        value: PreferredContactMethod.email,
        groupValue: method,
        onChanged: widget.submitting
            ? null
            : (value) => setState(() => method = value),
        title: const Text('Email'),
      ),
      CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: confirmed,
        onChanged: widget.submitting
            ? null
            : (value) => setState(() => confirmed = value ?? false),
        title: const Text('My current contact information is accurate.'),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      _SubmitButton(
        enabled: method != null && confirmed,
        submitting: widget.submitting,
        onPressed: () => widget.onSubmit(
          ContactPreferenceInformationResponsePayload(
            informationRequestId:
                widget.request.informationRequest!.informationRequestId,
            expectedVersion: widget.request.version,
            preferredContactMethod: method!,
            contactDetailsConfirmed: true,
          ),
        ),
      ),
    ],
  );
}

class _AvailabilityResponseForm extends StatefulWidget {
  const _AvailabilityResponseForm({
    required this.request,
    required this.submitting,
    required this.onSubmit,
  });
  final PatientRequest request;
  final bool submitting;
  final ValueChanged<PatientInformationResponsePayload> onSubmit;
  @override
  State<_AvailabilityResponseForm> createState() =>
      _AvailabilityResponseFormState();
}

class _AvailabilityResponseFormState extends State<_AvailabilityResponseForm> {
  final windows = <_AvailabilityDraft>[];
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Your availability is a local wall-clock preference, not an appointment time.',
      ),
      const SizedBox(height: 8),
      for (var index = 0; index < windows.length; index++)
        _availabilityRow(context, index),
      TextButton.icon(
        onPressed: widget.submitting || windows.length >= 14
            ? null
            : () => setState(() => windows.add(_AvailabilityDraft())),
        icon: const Icon(Icons.add),
        label: const Text('Add time period'),
      ),
      if (windows.isEmpty)
        const Text('Add at least one available time period.'),
      _SubmitButton(
        enabled: _valid,
        submitting: widget.submitting,
        onPressed: () => widget.onSubmit(
          AvailabilityInformationResponsePayload(
            informationRequestId:
                widget.request.informationRequest!.informationRequestId,
            expectedVersion: widget.request.version,
            availabilityWindows: windows
                .map(
                  (item) => AvailabilityWindow(
                    dayOfWeek: item.day!,
                    startLocalTime: AvailabilityLocalTime(
                      item.start!.hour,
                      item.start!.minute,
                    ),
                    endLocalTime: AvailabilityLocalTime(
                      item.end!.hour,
                      item.end!.minute,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    ],
  );
  bool get _valid {
    if (windows.isEmpty) return false;
    for (final item in windows) {
      if (item.day == null ||
          item.start == null ||
          item.end == null ||
          _minutes(item.start!) >= _minutes(item.end!)) {
        return false;
      }
    }
    final sorted = [...windows]
      ..sort(
        (a, b) => a.day!.index != b.day!.index
            ? a.day!.index.compareTo(b.day!.index)
            : _minutes(a.start!).compareTo(_minutes(b.start!)),
      );
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i - 1].day == sorted[i].day &&
          _minutes(sorted[i - 1].end!) > _minutes(sorted[i].start!)) {
        return false;
      }
    }
    return true;
  }

  Widget _availabilityRow(BuildContext context, int index) {
    final item = windows[index];
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<OperationalWeekday>(
            value: item.day,
            hint: const Text('Day'),
            items: OperationalWeekday.values
                .map(
                  (day) => DropdownMenuItem(
                    value: day,
                    child: Text(_weekdayLabel(day)),
                  ),
                )
                .toList(),
            onChanged: widget.submitting
                ? null
                : (value) => setState(() => item.day = value),
          ),
        ),
        IconButton(
          onPressed: widget.submitting
              ? null
              : () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime:
                        item.start ?? const TimeOfDay(hour: 9, minute: 0),
                  );
                  if (picked != null) setState(() => item.start = picked);
                },
          icon: const Icon(Icons.schedule),
          tooltip: item.start == null
              ? 'Start time'
              : item.start!.format(context),
        ),
        Text(item.start?.format(context) ?? 'Start'),
        const Text(' – '),
        IconButton(
          onPressed: widget.submitting
              ? null
              : () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime:
                        item.end ?? const TimeOfDay(hour: 17, minute: 0),
                  );
                  if (picked != null) setState(() => item.end = picked);
                },
          icon: const Icon(Icons.schedule),
          tooltip: item.end == null ? 'End time' : item.end!.format(context),
        ),
        Text(item.end?.format(context) ?? 'End'),
        IconButton(
          onPressed: widget.submitting
              ? null
              : () => setState(() => windows.removeAt(index)),
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Remove period',
        ),
      ],
    );
  }

  static int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;
}

class _AvailabilityDraft {
  OperationalWeekday? day;
  TimeOfDay? start;
  TimeOfDay? end;
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.enabled,
    required this.submitting,
    required this.onPressed,
  });
  final bool enabled;
  final bool submitting;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: FilledButton.icon(
      onPressed: enabled && !submitting ? onPressed : null,
      icon: submitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.send_outlined),
      label: const Text('Submit information'),
    ),
  );
}

class _UnsupportedInformationResponse extends StatelessWidget {
  const _UnsupportedInformationResponse();
  @override
  Widget build(BuildContext context) => const Text(
    'This request needs an app update before it can be completed. Please contact the clinic.',
  );
}

String _reasonLabel(InformationRequestReasonCode reason) => switch (reason) {
  InformationRequestReasonCode.contactInformation => 'Contact information',
  InformationRequestReasonCode.patientIdentityInformation =>
    'Patient identity information',
  InformationRequestReasonCode.familyMemberInformation =>
    'Family member information',
  InformationRequestReasonCode.requestAdministrativeDetails =>
    'Request administrative details',
  InformationRequestReasonCode.availabilityInformation =>
    'Availability information',
  InformationRequestReasonCode.otherAdministrative =>
    'Other administrative information',
  InformationRequestReasonCode.unknown => 'Administrative information',
};
String _weekdayLabel(OperationalWeekday day) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.index];
