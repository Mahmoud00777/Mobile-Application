import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:drsaf/models/sales_invoice_summary.dart';
import 'package:drsaf/services/sales_invoice_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sunmi_printer_plus/core/enums/enums.dart';
import 'package:sunmi_printer_plus/core/styles/sunmi_text_style.dart';
import 'package:sunmi_printer_plus/core/sunmi/sunmi_printer.dart';
import 'package:sunmi_printer_plus/core/types/sunmi_column.dart';

class InvoDetailsScreen extends StatefulWidget {
  final dynamic invoce;

  const InvoDetailsScreen({super.key, required this.invoce});

  @override
  State<InvoDetailsScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoDetailsScreen> {
  final Color primaryColor = const Color(0xFF60B245);
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = const Color(0xFFF2F2F2);
  final Color pressedColor = const Color(0xFFFFFFFF);
  final Color textColor = const Color(0xFF383838);
  SalesInvoiceSummary? invoiceDetails;
  bool isLoading = true;
  String? errorMessage;
  final _df = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _loadInvoiceDetails();
  }

  Future<void> _loadInvoiceDetails() async {
    try {
      final details = await SalesInvoiceService.getSalesInvoiceByName(
        widget.invoce,
      );
      setState(() {
        invoiceDetails = details;
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تفاصيل فاتورة مبيعات',
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
            'طباعة الفاتورة',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          onPressed:
              invoiceDetails == null ? null : () => printTest(invoiceDetails!),
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

    if (invoiceDetails == null) {
      return const Center(child: Text('لا توجد بيانات للفاتورة'));
    }

    return _buildInvoiceDetails();
  }

  Widget _buildInvoiceDetails() {
    final details = invoiceDetails;
    final Color primaryColor = const Color(0xFF60B245);
    final Color secondaryColor = Colors.white;
    final Color backgroundColor = const Color(0xFFF2F2F2);
    final Color textColor = const Color(0xFF383838);

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
            color: secondaryColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'فاتورة رقم ${details?.invoiceNumber ?? 'غير محدد'}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(color: primaryColor.withOpacity(0.3)),
                  const SizedBox(height: 8),
                  _buildDetailRow('العميل:', details?.customer ?? 'غير محدد'),
                  _buildDetailRow('التاريخ:', _df.format(details!.postingDate)),
                  _buildDetailRow(
                    'المجموع:',
                    '${details.grandTotal.toStringAsFixed(2)} ل.د',
                  ),
                  _buildDetailRow(
                    'الوردية:',
                    details.customPosOpenShift ?? 'غير محدد',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Items Section
          Text(
            'بنود الفاتورة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          ...details.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(12),
                color: secondaryColor,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.itemName ?? 'بند بدون اسم',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            Text(
                              item.itemCode ?? '',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.scale, size: 18, color: primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              '${item.qty.toStringAsFixed(2)} ${item.uom}',
                              style: TextStyle(fontSize: 15, color: textColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'السعر: ${item.rate.toStringAsFixed(2)} ل.د',
                          style: TextStyle(fontSize: 14, color: textColor),
                        ),
                        Text(
                          'المجموع: ${(item.qty * item.rate).toStringAsFixed(2)} ل.د',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (details.items.isEmpty) const Center(child: Text('لا توجد بنود')),
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

  Widget _buildInvoiceItem(SalesInvoiceItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.itemName ?? 'بند بدون اسم',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الكمية: ${item.qty.toStringAsFixed(2) ?? '0'}'),
                Text('السعر: ${item.rate.toStringAsFixed(2) ?? '0.00'} ل.د'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'المجموع: ${item.qty * item.rate} ل.د',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

void printTest(SalesInvoiceSummary invo) async {
  if (!await isSunmiDevice()) {
    print('🚫 ليس جهاز Sunmi. إلغاء الطباعة.');
    return;
  }

  final ByteData logoBytes = await rootBundle.load('assets/images/test.png');
  final Uint8List imageBytes = logoBytes.buffer.asUint8List();
  final now = DateTime.now();
  final formattedDate = DateFormat('yyyy-MM-dd – HH:mm').format(now);
  // ignore: deprecated_member_use
  await SunmiPrinter.initPrinter();
  // ignore: deprecated_member_use
  await SunmiPrinter.startTransactionPrint(true);
  await SunmiPrinter.printImage(imageBytes, align: SunmiPrintAlign.CENTER);
  await SunmiPrinter.printText(
    'تفاصيل الفاتورة',
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
  await SunmiPrinter.printText('الزبون: ${invo.customer ?? "غير معروف"}');
  await SunmiPrinter.printText('');
  await SunmiPrinter.printText('التاريخ والوقت: $formattedDate');
  await SunmiPrinter.printText('');
  await SunmiPrinter.lineWrap(3);

  await SunmiPrinter.printRow(
    cols: [
      SunmiColumn(
        text: 'الإجمالي',
        width: 3,
        style: SunmiTextStyle(align: SunmiPrintAlign.LEFT, bold: true),
      ),
      SunmiColumn(
        text: 'السعر',
        width: 2,
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true),
      ),
      SunmiColumn(
        text: 'الكمية',
        width: 2,
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true),
      ),
      SunmiColumn(
        text: 'المنتج',
        width: 5,
        style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true),
      ),
    ],
  );

  await SunmiPrinter.printText(
    '--------------------------------',
    style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
  );
  double total = 0.0;

  for (final item in invo.items) {
    final name = item.itemName ?? '';
    final qty = item.qty ?? 0;
    final rate = item.rate ?? 0.0;
    final amount = (qty * rate);

    total += amount;

    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: amount.toStringAsFixed(1),
          width: 2,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: rate.toStringAsFixed(1),
          width: 2,
          style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
        ),
        SunmiColumn(
          text: '×$qty',
          width: 2,
          style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
        ),
        SunmiColumn(
          text: name,
          width: 6,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );
    await SunmiPrinter.printText(
      '--------------------------------',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
    );
  }
  await SunmiPrinter.printText(
    'الإجمالي: ${total.toStringAsFixed(1)} LYD',
    style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.LEFT),
  );
  await SunmiPrinter.printText(
    '--------------------------------',
    style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
  );
  await SunmiPrinter.printText(
    'شكرًا لزيارتكم!',
    style: SunmiTextStyle(bold: true, fontSize: 35),
  );

  await SunmiPrinter.printText(
    'نتمنى أن نراكم مجددًا 😊',
    style: SunmiTextStyle(fontSize: 35),
  );

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
