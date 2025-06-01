import 'package:drsaf/screen/bin_report_page.dart';
import 'package:drsaf/screen/customer_ledger_summary_page.dart';
import 'package:drsaf/screen/sales_invoice_summary_page.dart';
import 'package:drsaf/screen/visit_report.dart';
import 'package:flutter/material.dart';
import 'payment_entry_report_page.dart';

class ReportsScreen extends StatelessWidget {
  // تعريف الألوان المطلوبة
  final Color primaryColor = const Color(0xFFB6B09F);
  final Color secondaryColor = const Color(0xFFEAE4D5);
  final Color backgroundColor = const Color(0xFFF2F2F2);
  final Color blackColor = const Color.fromARGB(255, 85, 84, 84);

  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'التقارير',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        // elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 0.9,
          children: [
            _buildReportButton(
              context,
              icon: Icons.bar_chart,
              title: 'تقرير المبيعات',
              onTap: () => _navigateToReport(context, 'Sales Report'),
            ),
            _buildReportButton(
              context,
              icon: Icons.inventory,
              title: 'تقرير المخزون',
              onTap: () => _navigateToReport(context, 'Stock Report'),
            ),
            _buildReportButton(
              context,
              icon: Icons.payments,
              title: 'تقرير المدفوعات',
              onTap: () => _navigateToReport(context, 'payments'),
            ),
            _buildReportButton(
              context,
              icon: Icons.assignment_return,
              title: 'تقرير المستحقات',
              onTap: () => _navigateToReport(context, 'Outstanding'),
            ),
            _buildReportButton(
              context,
              icon: Icons.location_on,
              title: 'تقرير الزيارات',
              onTap: () => _navigateToReport(context, 'Visit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: primaryColor.withOpacity(0.5), width: 1.5),
      ),
      shadowColor: blackColor.withOpacity(0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        splashColor: primaryColor.withOpacity(0.2),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: secondaryColor,
            boxShadow: [
              BoxShadow(
                color: blackColor.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 35, color: blackColor),
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: blackColor,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToReport(BuildContext context, String reportType) {
    final Map<String, Widget> reportScreens = {
      'Stock Report': const BinReportPage(),
      'Sales Report': const SalesInvoiceSummaryPage(),
      'Outstanding': const CustomerLedgerPage(),
      'payments': const PaymentEntryReportPage(),
      'Visit': const VisitReportPage(filter: 3),
    };

    final Widget screen =
        reportScreens[reportType] ?? const DefaultReportPage();

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class DefaultReportPage extends StatelessWidget {
  const DefaultReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقرير غير متوفر')),
      body: const Center(child: Text('هذا التقرير غير متوفر حالياً')),
    );
  }
}
