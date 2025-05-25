import 'package:drsaf/screen/material_request_detail_page.dart';
import 'package:drsaf/screen/store_screen_details.dart';
import 'package:flutter/material.dart';
import '../models/materials_requestM.dart';
import '../services/materials_service.dart';
import 'materials_request.dart';

class MaterialStoreScreen extends StatefulWidget {
  const MaterialStoreScreen({super.key});

  @override
  State<MaterialStoreScreen> createState() => _MaterialStoreScreenState();
}

class _MaterialStoreScreenState extends State<MaterialStoreScreen> {
  late Future<List<MaterialRequest>> _requestsFuture;
  final Color primaryColor = const Color(0xFFBDB395);
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = const Color(0xFFF6F0F0);
  final Color pressedColor = const Color(0xFFF2E2B1);
  @override
  void initState() {
    super.initState();
    _requestsFuture = MaterialRequestService.getMaterialStoreRequests();
  }

  void _refreshRequests() {
    setState(() {
      _requestsFuture = MaterialRequestService.getMaterialStoreRequests();
    });
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'طلبات',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(25),
            bottomLeft: Radius.circular(25),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshRequests,
          ),
        ],
      ),
      body: FutureBuilder<List<MaterialRequest>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color.fromARGB(255, 156, 20, 20),
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'حدث خطأ في جلب البيانات',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 156, 20, 20),
                    ),
                    onPressed: _refreshRequests,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          final requests = snapshot.data!;

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/empty_box.png', width: 120),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد طلبات مواد حالياً',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _createNewRequest(context),
                    child: const Text(
                      'إنشاء طلب جديد',
                      style: TextStyle(
                        color: Color.fromARGB(255, 156, 20, 20),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final req = requests[index];
              return _buildRequestCard(context, req);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewRequest(context),
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, size: 28, color: Colors.white),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, MaterialRequest req) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _navigateToDetail(context, req.name),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    req.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  _buildStatusChip(req.status),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.category, 'النوع', req.reason),
              _buildInfoRow(Icons.warehouse, 'المخزن', req.warehouse),
              _buildInfoRow(
                Icons.calendar_today,
                'تاريخ الطلب',
                req.transactionDate,
              ),
              _buildInfoRow(Icons.schedule, 'الموعد المخطط', req.scheduleDate),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    switch (status.toLowerCase()) {
      case 'pending':
        chipColor = Colors.orange;
        break;
      case 'completed':
        chipColor = Colors.green;
        break;
      case 'cancelled':
        chipColor = Colors.red;
        break;
      default:
        chipColor = Colors.blue;
    }

    return Chip(
      label: Text(
        status,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: chipColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }

  void _createNewRequest(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MaterialRequestPage()),
    );
    if (result == true) {
      _refreshRequests();
    }
  }

  void _navigateToDetail(BuildContext context, String requestName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialStoreDetailPage(requestName: requestName),
      ),
    );
  }
}
