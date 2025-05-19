import 'package:drsaf/screen/material_request_detail_page.dart';
import 'package:flutter/material.dart';
import '../models/materials_requestM.dart';
import '../services/materials_service.dart';
import 'materials_request.dart';

class MaterialRequestScreen extends StatefulWidget {
  const MaterialRequestScreen({super.key});

  @override
  State<MaterialRequestScreen> createState() => _MaterialRequestScreenState();
}

class _MaterialRequestScreenState extends State<MaterialRequestScreen> {
  late Future<List<MaterialRequest>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _requestsFuture = MaterialRequestService.getMaterialRequests();
  }

  void _refreshRequests() {
    setState(() {
      _requestsFuture = MaterialRequestService.getMaterialRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات المواد'),
        backgroundColor: const Color.fromARGB(255, 156, 20, 20),
      ),
      body: FutureBuilder<List<MaterialRequest>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }

          final requests = snapshot.data!;

          if (requests.isEmpty) {
            return const Center(child: Text('لا توجد طلبات حالياً.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 2,
                child: ListTile(
                  title: Text('النوع: ${req.reason}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الموعد: ${req.scheduleDate}'),
                      Text('المخزن: ${req.warehouse}'),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => MaterialRequestDetailPage(
                              requestName: req.name,
                            ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MaterialRequestPage()),
          );
          if (result == true) {
            _refreshRequests();
          }
        },
        backgroundColor: const Color.fromARGB(255, 156, 20, 20),
        child: const Icon(Icons.add),
      ),
    );
  }
}
