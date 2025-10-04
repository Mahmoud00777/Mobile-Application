import 'package:alkhair_daem/models/payment_entry_report';
import 'package:alkhair_daem/services/payment_entry_report_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

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

  final Color primaryColor = const Color(0xFF60B245);
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = const Color(0xFFF2F2F2);
  final Color textColor = const Color(0xFF383838);

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
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'تفاصيل الدفعة',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(25),
            bottomLeft: Radius.circular(25),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildBody(),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 8),
        child: FloatingActionButton.extended(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 6,
          icon: const Icon(Icons.print_outlined, size: 28),
          label: const Text(
            'طباعة الدفعة',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          onPressed:
              paymentDetails == null
                  ? null
                  : () {
                    printTest(paymentDetails!);
                  },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            color: secondaryColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'دفعة رقم ${details?.name ?? 'غير محدد'}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(color: primaryColor.withOpacity(0.3)),
                  const SizedBox(height: 8),
                  _buildDetailRow('العميل:', details?.party ?? 'غير محدد'),
                  _buildDetailRow('التاريخ:', _df.format(details!.postingDate)),
                  _buildDetailRow(
                    'المبلغ المدفوع:',
                    '${details.paidAmount.toStringAsFixed(2)} ل.د',
                  ),
                  _buildDetailRow(
                    'طريقة الدفع:',
                    details.modeOfPayment ?? 'غير محدد',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
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

void printTest(PaymentEntryReport payment) async {
  if (!await isSunmiDevice()) {
    print('🚫 ليس جهاز Sunmi. إلغاء الطباعة.');
    return;
  }

  final ByteData logoBytes = await rootBundle.load('assets/images/test.png');
  final Uint8List imageBytes = logoBytes.buffer.asUint8List();
  final now = DateTime.now();
  final formattedDate = DateFormat('yyyy-MM-dd – HH:mm').format(now);
  await SunmiPrinter.initPrinter();
  await SunmiPrinter.startTransactionPrint(true);
  // await SunmiPrinter.printImage(imageBytes, align: SunmiPrintAlign.CENTER);
  await SunmiPrinter.printText(
    'إيصال دفع',
    style: SunmiTextStyle(
      bold: true,
      align: SunmiPrintAlign.CENTER,
      fontSize: 50,
    ),
  );
  await SunmiPrinter.printText(
    '--------------------------------',
    style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true),
  );
  await SunmiPrinter.line();
  await SunmiPrinter.printText('العميل: ${payment.party ?? "غير معروف"}');
  await SunmiPrinter.printText('التاريخ والوقت: $formattedDate');
  await SunmiPrinter.printText('رقم الدفعة: ${payment.name ?? "-"}');
  await SunmiPrinter.printText('طريقة الدفع: ${payment.modeOfPayment ?? "-"}');
  await SunmiPrinter.printText('');
  await SunmiPrinter.lineWrap(2);
  await SunmiPrinter.printRow(
    cols: [
      SunmiColumn(
        text: 'المبلغ',
        width: 4,
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true),
      ),
      SunmiColumn(
        text: 'العملة',
        width: 2,
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true),
      ),
    ],
  );
  await SunmiPrinter.printText(
    '--------------------------------',
    style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
  );
  await SunmiPrinter.printRow(
    cols: [
      SunmiColumn(
        text: payment.paidAmount.toStringAsFixed(2),
        width: 4,
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
      ),
      SunmiColumn(
        text: 'LYD',
        width: 2,
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
      ),
    ],
  );
  await SunmiPrinter.printText(
    '--------------------------------',
    style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
  );
  await SunmiPrinter.printText(
    'شكرًا لتعاملكم معنا',
    style: SunmiTextStyle(
      bold: true,
      fontSize: 35,
      align: SunmiPrintAlign.CENTER,
    ),
  );

  // await SunmiPrinter.printText(
  //   'نتمنى أن نراكم مجددًا 😊',
  //   style: SunmiTextStyle(fontSize: 35, align: SunmiPrintAlign.CENTER),
  // );
  await SunmiPrinter.lineWrap(3);
  await SunmiPrinter.cutPaper();
}

Future<bool> isSunmiDevice() async {
  if (!Platform.isAndroid) return false;
  final deviceInfo = DeviceInfoPlugin();
  final androidInfo = await deviceInfo.androidInfo;
  final brand = androidInfo.brand.toLowerCase() ?? '';
  final manufacturer = androidInfo.manufacturer.toLowerCase() ?? '';
  return brand.contains('sunmi') || manufacturer.contains('sunmi');
}
