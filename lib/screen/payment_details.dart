import 'package:drsaf/models/payment_entry_report';
import 'package:drsaf/services/payment_entry_report_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PaymentDetails extends StatefulWidget {
  final dynamic payment;
  const PaymentDetails({super.key, required this.payment});
  @override
  State<PaymentDetails> createState() => _ScreenPaymentDetails();
}

class _ScreenPaymentDetails extends State<PaymentDetails> {
  PaymentEntryReport? paymentDetails;
  bool isLoading = true;
  String? errorMessage;
  final _df = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _loadPaymentDetails();
  }

  Future<void> _loadPaymentDetails() async {
    try {
      final details = await PaymentEntryReportService.getOPaymentEntryByName(
        widget.payment,
      );
      setState(() {
        paymentDetails = details;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'فشل في تحميل الفاتورة: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("تفاصيل الدفعة")),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (paymentDetails == null) {
      return const Center(child: Text('لا توجد بيانات للفاتورة'));
    }

    return _buildPaymentDetails();
  }

  Widget _buildPaymentDetails() {
    final details = paymentDetails;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // معلومات الفاتورة الأساسية
          Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('العميل:', details?.name ?? 'غير محدد'),
                  _buildDetailRow(
                    'رقم الفاتورة:',
                    details?.party ?? 'غير محدد',
                  ),
                  _buildDetailRow('التاريخ:', _df.format(details!.postingDate)),
                  _buildDetailRow(
                    'المجموع:',
                    '${details.paidAmount.toStringAsFixed(2) ?? '0.00'} ل.د',
                  ),
                  _buildDetailRow(
                    'الوردية:',
                    details.modeOfPayment ?? 'غير محدد',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // // بنود الفاتورة
          // const Text(
          //   'بنود الفاتورة',
          //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          // ),
          // const Divider(),

          // if (details.items != null && details.items.isNotEmpty)
          //   ...details.items
          //       .map<Widget>((item) => _buildInvoiceItem(item))
          //       .toList()
          // else
          //   const Center(child: Text('لا توجد بنود')),
          Center(
            child: FloatingActionButton(
              onPressed: () {
                print("*******************");
                // printTest(details);
              },
              child: const Icon(Icons.print_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(flex: 3, child: Text(value, textAlign: TextAlign.start)),
        ],
      ),
    );
  }
}
