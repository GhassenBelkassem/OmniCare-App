import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../request_core/data/request_models.dart';
import '../../request_core/domain/request_vocabulary.dart';
import '../application/patient_requests_controller.dart';
import 'patient_request_detail_screen.dart';
import 'request_status_copy.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});
  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    final c = context.read<PatientRequestsController>();
    if (c.status == PatientRequestsStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) c.loadFirst(); });
    }
    scroll.addListener(() {
      if (scroll.position.pixels >= scroll.position.maxScrollExtent - 180) {
        context.read<PatientRequestsController>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PatientRequestsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('My requests')),
      body: RefreshIndicator(
        onRefresh: () => c.loadFirst(preserveItems: true),
        child: Column(children: [
          SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(children: PatientRequestListFilter.values.map((filter) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(filter.label), selected: c.filter == filter, onSelected: (_) => c.selectFilter(filter)))).toList())),
          Expanded(child: _content(c)),
        ]),
      ),
    );
  }

  Widget _content(PatientRequestsController c) {
    if (c.status == PatientRequestsStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.status == PatientRequestsStatus.error) {
      return Center(child: Text(c.listFailure!.message));
    }
    if (c.status == PatientRequestsStatus.empty) {
      return Center(child: Text(c.filter == PatientRequestListFilter.all ? 'You have no requests yet.' : 'No ${c.filter.label.toLowerCase()} requests yet.'));
    }
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.all(16),
      itemCount: c.items.length + (c.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= c.items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        return RequestCard(request: c.items[index]);
      },
    );
  }
}

class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request});
  final PatientRequestListItem request;
  @override
  Widget build(BuildContext context) {
    final status = RequestStatusCopy.of(request.patientStatus);
    final localizations = MaterialLocalizations.of(context);
    final submittedAt = request.submittedAt.toLocal();
    final submittedLabel =
        '${localizations.formatMediumDate(submittedAt)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(submittedAt))}';
    return Card(
      child: ListTile(
        key: ValueKey(request.requestId.value),
        leading: Icon(status.icon),
        title: Text(request.clinicDisplayName),
        subtitle: Text(
          '${situationLabel(request.situation)} · ${status.label}${request.requiresPatientAction ? ' · Action required' : ''}\n${request.subjectType == RequestSubjectType.self ? 'Me' : request.subjectDisplayName}\n$submittedLabel',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  PatientRequestDetailScreen(requestId: request.requestId),
            ),
          );
        },
      ),
    );
  }
}
