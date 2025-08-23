import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

class RequestsListPage extends StatefulWidget {
  const RequestsListPage({super.key});

  @override
  State<RequestsListPage> createState() => _RequestsListPageState();
}

class _RequestsListPageState extends State<RequestsListPage> {
  final supabase = SupabaseConfig.client;

  List<Map<String, dynamic>> requests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRequests();
    subscribeToRealtime();
  }

  Future<void> fetchRequests() async {
    setState(() => isLoading = true);

    try {
      final response = await supabase
          .from('requests')
          .select()
          .eq('status', 'pending')
          .order('needed_by', ascending: true);

      setState(() {
        requests = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching requests: $e");
      setState(() => isLoading = false);
    }
  }

  void subscribeToRealtime() {
    supabase.channel('requests_channel')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'requests',
      callback: (payload) {
        final newRequest = payload.newRecord;
        if (newRequest['status'] == 'pending') {
          setState(() {
            requests.insert(0, newRequest);
          });
        }
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'requests',
      callback: (payload) {
        final updated = payload.newRecord;
        final id = updated['id'];

        setState(() {
          if (updated['status'] != 'pending') {
            requests.removeWhere((r) => r['id'] == id);
          } else {
            final index = requests.indexWhere((r) => r['id'] == id);
            if (index != -1) {
              requests[index] = updated;
            }
          }
        });
      },
    )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Requests'),
        backgroundColor: Colors.red,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
          ? const Center(child: Text('No pending blood requests.'))
          : ListView.builder(
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          final neededBy = request['needed_by'] != null
              ? DateTime.parse(request['needed_by']).toLocal()
              : null;

          return Card(
            margin:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red,
                child: Text(
                  request['blood_group'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(request['patient_name'] ?? 'Unknown'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Hospital: ${request['hospital'] ?? 'N/A'}"),
                  Text("Location: ${request['location'] ?? 'N/A'}"),
                  if (neededBy != null)
                    Text("Needed by: ${neededBy.toString().split(' ')[0]}"),
                  Text("Phone: ${request['phone_number'] ?? 'N/A'}")
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
