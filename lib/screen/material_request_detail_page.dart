import 'package:flutter/material.dart';
import '../models/materials_requestM.dart';
import '../services/materials_service.dart';

class MaterialRequestDetailPage extends StatefulWidget {
  final String requestName;

  const MaterialRequestDetailPage({super.key, required this.requestName});

  @override
  State<MaterialRequestDetailPage> createState() =>
      _MaterialRequestDetailPageState();
}

class _MaterialRequestDetailPageState extends State<MaterialRequestDetailPage> {
  late Future<MaterialRequest> _requestFuture;

  @override
  void initState() {
    super.initState();
    _requestFuture = MaterialRequestService.getMaterialRequestByName(
      widget.requestName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل طلب المواد')),
      body: FutureBuilder<MaterialRequest>(
        future: _requestFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }

          final request = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                _buildDetailRow('الرقم:', request.name),
                _buildDetailRow('النوع:', request.reason),
                _buildDetailRow('الموعد المطلوب:', request.scheduleDate),
                _buildDetailRow('المخزن:', request.warehouse),
                const SizedBox(height: 16),
                const Text(
                  'الأصناف:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...request.items.map(
                  (item) => Card(
                    child: ListTile(
                      title: Text('${item.itemName} (${item.itemCode})'),
                      subtitle: Text('الكمية: ${item.qty} ${item.uom}'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
