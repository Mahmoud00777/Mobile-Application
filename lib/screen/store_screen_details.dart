import 'package:flutter/material.dart';
import '../models/materials_requestM.dart';
import '../services/materials_service.dart';

class MaterialStoreDetailPage extends StatefulWidget {
  final String requestName;
  final Color primaryColor = const Color(0xFFBDB395);
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = const Color(0xFFF6F0F0);
  final Color pressedColor = const Color(0xFFF2E2B1);
  final Color textColor = const Color(0xFF333333);

  const MaterialStoreDetailPage({super.key, required this.requestName});

  @override
  State<MaterialStoreDetailPage> createState() =>
      _MaterialStoreDetailPageState();
}

class _MaterialStoreDetailPageState extends State<MaterialStoreDetailPage> {
  late Future<MaterialRequest> _requestFuture;
  bool _isApproving = false;
  final bool _isRejecting = false;

  @override
  void initState() {
    super.initState();
    _loadRequestData();
  }

  void _loadRequestData() {
    setState(() {
      _requestFuture = MaterialRequestService.getMaterialRequestByName(
        widget.requestName,
      );
    });
  }

  Future<void> _approveRequest() async {
    if (!mounted) return;

    setState(() => _isApproving = true);

    try {
      final result = await MaterialRequestService.approveRequest(
        widget.requestName,
      );

      if (!mounted) return;

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت الموافقة على الطلب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRequestData(); // إعادة تحميل البيانات لتحديث الحالة
      } else {
        throw Exception(result['error'] ?? 'فشل في الموافقة على الطلب');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isApproving = false);
      }
    }
  }

  Future<void> _rejectRequest() async {
    // if (!mounted) return;

    // setState(() => _isRejecting = true);

    // try {
    //   final result = await MaterialRequestService.rejectRequest(
    //     widget.requestName,
    //   );

    //   if (!mounted) return;

    //   if (result['success']) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(
    //         content: Text('تم رفض الطلب بنجاح'),
    //         backgroundColor: Colors.green,
    //       ),
    //     );
    //     _loadRequestData(); // إعادة تحميل البيانات لتحديث الحالة
    //   } else {
    //     throw Exception(result['error'] ?? 'فشل في رفض الطلب');
    //   }
    // } catch (e) {
    //   if (!mounted) return;
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text('خطأ: ${e.toString()}'),
    //       backgroundColor: Colors.red,
    //     ),
    //   );
    // } finally {
    //   if (mounted) {
    //     setState(() => _isRejecting = false);
    //   }
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'تفاصيل طلب مواد',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
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
        elevation: 4,
      ),
      bottomNavigationBar: _buildApprovalButtons(),
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
                    onPressed: _loadRequestData,
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
                        _buildDetailRow(
                          icon: Icons.assignment_ind,
                          label: 'الحالة:',
                          value: _getStatusText(request.status),
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

  Widget _buildApprovalButtons() {
    return FutureBuilder<MaterialRequest>(
      future: _requestFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final request = snapshot.data!;

        // إخفاء الأزرار إذا كان الطلب معتمدا أو مرفوضا
        if (request.status == 'Approved' || request.status == 'Rejected') {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.secondaryColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isRejecting ? null : _rejectRequest,
                  icon:
                      _isRejecting
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.close, color: Colors.white),
                  label: Text(
                    _isRejecting ? 'جاري الرفض...' : 'رفض الطلب',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isApproving ? null : _approveRequest,
                  icon:
                      _isApproving
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.check, color: Colors.white),
                  label: Text(
                    _isApproving ? 'جاري الموافقة...' : 'موافقة على الطلب',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

  String _getStatusText(String status) {
    switch (status) {
      case 'Approved':
        return 'تمت الموافقة';
      case 'Rejected':
        return 'تم الرفض';
      case 'Pending':
        return 'قيد الانتظار';
      default:
        return status;
    }
  }
}
