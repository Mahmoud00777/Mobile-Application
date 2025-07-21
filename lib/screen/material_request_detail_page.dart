import 'package:flutter/material.dart';
import '../models/materials_requestM.dart';
import '../services/materials_service.dart';

class MaterialRequestDetailPage extends StatefulWidget {
  final String requestName;
  final Color primaryColor = const Color(0xFF60B245);
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = const Color(0xFFF2F2F2);
  final Color pressedColor = const Color(0xFFFFFFFF);
  final Color textColor = const Color(0xFF383838);

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
      backgroundColor: widget.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'تفاصيل طلب مواد',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        backgroundColor: widget.primaryColor,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(25),
            bottomLeft: Radius.circular(25),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: FutureBuilder<MaterialRequest>(
        future: _requestFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'حدث خطأ في تحميل البيانات',
                    style: TextStyle(
                      fontSize: 18,
                      color: widget.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _requestFuture =
                            MaterialRequestService.getMaterialRequestByName(
                              widget.requestName,
                            );
                      });
                    },
                    child: const Text(
                      'إعادة المحاولة',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }

          final request = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  color: widget.secondaryColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'طلب مواد رقم ${request.name}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: widget.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Divider(color: widget.primaryColor.withOpacity(0.3)),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          icon: Icons.description,
                          label: 'السبب:',
                          value: request.reason,
                        ),
                        _buildDetailRow(
                          icon: Icons.calendar_today,
                          label: 'الموعد المطلوب:',
                          value: request.scheduleDate,
                        ),
                        _buildDetailRow(
                          icon: Icons.warehouse,
                          label: 'المخزن:',
                          value: request.warehouse,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Items Section
                Text(
                  'الأصناف المطلوبة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.textColor,
                  ),
                ),
                const SizedBox(height: 12),

                ...request.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(12),
                      color: widget.secondaryColor,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {},
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.itemName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: widget.primaryColor,
                                    ),
                                  ),
                                  Text(
                                    item.itemCode,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.scale,
                                    size: 18,
                                    color: widget.primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${item.qty} ${item.uom}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: widget.textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: widget.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: widget.textColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
