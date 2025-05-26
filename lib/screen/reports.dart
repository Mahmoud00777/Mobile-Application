import 'package:drsaf/screen/total_stock_summary_page.dart';
import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  final Color primaryColor = const Color(0xFFBDB395);
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = const Color(0xFFF6F0F0);

  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('التقارير', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          children: [
            _buildReportButton(
              context,
              icon: Icons.bar_chart,
              title: 'تقرير المبيعات',
              onTap: () => _navigateToReport(context, 'sales'),
            ),
            _buildReportButton(
              context,
              icon: Icons.inventory,
              title: 'Stock Report',
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
              title: 'تقرير المرتجعات',
              onTap: () => _navigateToReport(context, 'returns'),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor.withOpacity(0.7), primaryColor],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: secondaryColor),
              const SizedBox(height: 15),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: secondaryColor,
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
      'Stock Report': const TotalStockSummaryPage(),
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

class ReportDetailsScreen extends StatelessWidget {
  final String reportType;

  const ReportDetailsScreen({super.key, required this.reportType});

  @override
  Widget build(BuildContext context) {
    String title;
    switch (reportType) {
      case 'sales':
        title = 'Sales Report';
        break;
      case 'Stock Report':
        title = 'Stock Report';
        break;
      case 'payments':
        title = 'Payment Report';
        break;
      case 'returns':
        title = 'Return Report';
        break;
      default:
        title = 'Report';
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('سيتم عرض $title هنا')),
    );
  }
}
