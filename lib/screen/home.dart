import 'package:drsaf/screen/MaterialRequestScreenList.dart';
import 'package:drsaf/screen/PosOpeningPage.dart';
import 'package:drsaf/screen/appbar.dart';
import 'package:drsaf/screen/login.dart';
import 'package:drsaf/screen/payment_entry_list_page.dart';
import 'package:drsaf/screen/pos.dart';
import 'package:drsaf/screen/pos_return.dart';
import 'package:drsaf/screen/reports.dart';
import 'package:drsaf/screen/sales_invoice_summary_page.dart';
import 'package:drsaf/screen/store_screen.dart';
import 'package:drsaf/screen/visit.dart';
import 'package:drsaf/screen/visit_report.dart';
import 'package:drsaf/services/auth_service.dart';
import 'package:drsaf/services/pos_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HomePage extends StatefulWidget {
  final bool showLoginSuccess;

  const HomePage({super.key, this.showLoginSuccess = false});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  final Color primaryColor = Color(0xFF60B245);
  final Color secondaryColor = Color(0xFFFFFFFF);
  final Color backgroundColor = Color(0xFFF2F2F2);
  final Color blackColor = Color(0xFF383838);

  final List<Map<String, dynamic>> buttons = [
    {'label': 'نقطة البيع', 'icon': Icons.point_of_sale},
    {'label': 'طلبات المواد', 'icon': Icons.inventory_2},
    {'label': 'المدفوعات والديون', 'icon': Icons.payments},
    {'label': 'سجل الزيارة', 'icon': Icons.assignment_turned_in},
    {'label': 'الإرجاعات', 'icon': Icons.assignment_return},
    {'label': 'التقارير', 'icon': Icons.analytics},
  ];
  bool _isClosingShift = false;
  Map<String, int> statistics = {
    'visits': 0,
    'invoices': 0,
    'orders': 0,
    'items': 0,
    'returns': 0,
  };

  bool isLoadingStats = true;
  Map<String, dynamic>? selectedPOSProfile;
  String? time;
  final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

  @override
  void initState() {
    super.initState();
    if (widget.showLoginSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الدخول بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      });
    }
    _loadSelectedPOSProfile().then((_) => _loadStatistics());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentRoute = ModalRoute.of(context);
    if (currentRoute is PageRoute) {
      routeObserver.subscribe(this, currentRoute);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    if (!mounted) return;

    setState(() => isLoadingStats = true);

    try {
      if (selectedPOSProfile != null) {
        final posOpeningName = selectedPOSProfile!['name'];
        final prefs = await SharedPreferences.getInstance();
        final posOpeningShift = prefs.getString('pos_open');
        final results = await Future.wait([
          PosService.getVisitCount(posOpeningName),
          PosService.getInvoiceCount(posOpeningName, posOpeningShift!),
          PosService.getOrderCount(posOpeningName),
          PosService.getItemCount(),
          PosService.getReturnInvoiceCount(posOpeningName, posOpeningShift),
        ]);

        if (mounted) {
          setState(() {
            statistics = {
              'visits': results[0],
              'invoices': results[1],
              'orders': results[2],
              'items': results[3],
              'returns': results[4],
            };
          });
        }
      }
    } catch (e) {
      print('Error loading statistics: $e');
    } finally {
      if (mounted) {
        setState(() => isLoadingStats = false);
      }
    }
  }

  Future<void> _loadSelectedPOSProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('selected_pos_profile');
    time = prefs.getString('pos_time');
    if (jsonString != null) {
      setState(() {
        selectedPOSProfile = jsonDecode(jsonString);
      });
    }
  }

  Future<void> _closePOSShift() async {
    setState(() {
      _isClosingShift = true;
    });

    try {
      final closingData = await _getClosingData();

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: const Text('تأكيد إغلاق الوردية'),
              content: _buildClosingSummary(closingData),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('تأكيد الإغلاق'),
                ),
              ],
            ),
      );

      if (confirmed == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const Center(child: CircularProgressIndicator()),
        );

        try {
          final cashAmount = await _getCurrentCashAmount();
          await PosService.createClosingEntry(cashAmount, selectedPOSProfile!);

          if (mounted) {
            Navigator.pop(context);
            await _executeClosing();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إغلاق الوردية بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const PosOpeningPage()),
            );
          }
        } catch (e) {
          if (mounted) Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل في إغلاق الوردية: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (confirmed != true) {
        setState(() {
          _isClosingShift = false;
        });
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحضير بيانات الإغلاق: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildClosingSummary(Map<String, dynamic> data) {
    final paymentMethods = <String, double>{};
    for (final payment in data['entry']) {
      final method = payment['mode_of_payment'] ?? 'غير محدد';
      final amount = (payment['paid_amount'] as num).toDouble();
      paymentMethods.update(
        method,
        (value) => value + amount,
        ifAbsent: () => amount,
      );
    }
    final totalSales = data['total_sales'] ?? 0.0;
    final totalPayments = paymentMethods.values.fold(
      0.0,
      (sum, amount) => sum + amount,
    );
    final grandTotal = totalSales + totalPayments;
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ملخص إغلاق الوردية',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            _buildSummaryCard(
              title: 'الفواتير',
              children: [
                _buildSummaryRow('عدد الفواتير', '${data['invoice_count']}'),
                const Divider(height: 20),
                _buildSummaryRow(
                  'الإجمالي',
                  _formatCurrency(data['total_sales']),
                ),
              ],
            ),
            _buildSummaryCard(
              title: 'المدفوعات',
              children: [
                ...paymentMethods.entries.map(
                  (entry) =>
                      _buildSummaryRow(entry.key, _formatCurrency(entry.value)),
                ),
                const Divider(height: 20),
                _buildSummaryRow(
                  'إجمالي',
                  _formatCurrency(
                    paymentMethods.values.fold(
                      0.0,
                      (sum, amount) => sum + amount,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'الدفع في فواتير',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 5,
                  dataRowHeight: 40,
                  headingRowHeight: 40,
                  columns: const [
                    DataColumn(
                      label: SizedBox(width: 100, child: Text('طريقة الدفع')),
                    ),
                    DataColumn(
                      label: SizedBox(width: 100, child: Text('المبلغ')),
                      numeric: true,
                    ),
                  ],
                  rows:
                      data['payments'].map<DataRow>((payment) {
                        return DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 100,
                                child: Text(
                                  payment['method'],
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 100,
                                child: Text(
                                  _formatCurrency(payment['amount']),
                                  textAlign: TextAlign.start,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'المجموع النهائي',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    _formatCurrency(grandTotal),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _getClosingData() async {
    if (selectedPOSProfile == null) {
      throw Exception('لا يوجد وردية مفتوحة');
    }

    final shiftName = selectedPOSProfile!['name'];

    final results = await Future.wait([
      PosService.getShiftInvoices(shiftName),
      PosService.getPaymentMethods(),
      PosService.getShiftPaymentEntries(shiftName),
    ], eagerError: true);

    return {
      'invoice_count': results[0].length,
      'total_sales': results[0].fold(
        0.0,
        (sum, inv) => sum + inv['grand_total'],
      ),
      'payments': results[1],
      'entry': results[2],
    };
  }

  Future<void> _executeClosing() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_pos_profile');
    await prefs.remove('pos_time');
    await prefs.remove('pos_open');
    if (mounted) {
      setState(() => selectedPOSProfile = null);
    }
  }

  String _formatCurrency(dynamic amount) {
    try {
      final num parsedAmount =
          amount is String ? double.tryParse(amount) ?? 0 : (amount as num);
      return NumberFormat.currency(
        symbol: "د.ل",
        decimalDigits: 0,
        locale: 'ar_LY',
      ).format(parsedAmount);
    } catch (e) {
      print('Error formatting currency: $e');
      return 'د.ل‏ 0.00';
    }
  }

  Future<double> _getCurrentCashAmount() async {
    final controller = TextEditingController();

    return await showDialog<double>(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => AlertDialog(
                title: const Text('إدخال المبلغ النقدي'),
                content: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ النقدي المغلق',
                    hintText: '0.00',
                  ),
                  onChanged: (value) {
                    if (value.isEmpty || double.tryParse(value) == null) {
                      return;
                    }
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, 0.0),
                    child: const Text('إلغاء'),
                  ),
                  TextButton(
                    onPressed: () {
                      final value = double.tryParse(controller.text) ?? 0.0;
                      Navigator.pop(context, value);
                    },
                    child: const Text('تأكيد'),
                  ),
                ],
              ),
        ) ??
        0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      drawer: AppDrawer(onLogout: _logout),
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: Text('الصفحة الرئيسية', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: CircleAvatar(
              backgroundColor: Color(0xFFF2F2F2),
              child:
                  _isClosingShift
                      ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            primaryColor,
                          ),
                          strokeWidth: 2,
                        ),
                      )
                      : Icon(Icons.lock_clock, color: primaryColor),
            ),
            onPressed: _isClosingShift ? null : _closePOSShift,
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(25),
            bottomLeft: Radius.circular(25),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // Added SingleChildScrollView here
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (selectedPOSProfile != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: blackColor),
                        const SizedBox(width: 8),
                        Text(
                          formatTime(time!),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: blackColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                _buildDashboardCard(),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true, // Added shrinkWrap
                  physics:
                      const NeverScrollableScrollPhysics(), // Disable GridView scroll
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: buttons.length,
                  itemBuilder:
                      (context, index) => _buildButton(buttons[index], context),
                ),
                const SizedBox(height: 20), // Added extra space at bottom
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(Map<String, dynamic> button, BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: secondaryColor,
        padding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: primaryColor, width: 2),
        ),
        overlayColor: WidgetStateColor.resolveWith((states) {
          return states.contains(WidgetState.pressed)
              ? blackColor.withOpacity(0.1)
              : Colors.transparent;
        }),
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.3),
      ),
      onPressed: () async {
        final navigator = Navigator.of(context);
        Widget? targetScreen;

        switch (button['label']) {
          case 'سجل الزيارة':
            targetScreen = const VisitScreen();
            break;
          case 'طلبات المواد':
            targetScreen = const MaterialRequestScreen();
            break;
          case 'نقطة البيع':
            targetScreen = const POSScreen();
            break;
          case 'المدفوعات والديون':
            targetScreen = const PaymentEntryListPage();
            break;
          case 'الإرجاعات':
            targetScreen = const POSReturnScreen();
            break;
          case 'STORE':
            targetScreen = const MaterialStoreScreen();
            break;
          case 'التقارير':
            targetScreen = ReportsScreen();
            break;
          default:
            print('${button['label']} pressed');
            return;
        }

        await navigator.push(
          MaterialPageRoute(builder: (context) => targetScreen!),
        );

        if (mounted) {
          await _loadStatistics();
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(button['icon'] as IconData, size: 40, color: blackColor),
          const SizedBox(height: 10),
          Text(
            button['label'] as String,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: blackColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard() {
    return Card(
      color: primaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.dashboard, size: 36, color: blackColor),
                    const SizedBox(width: 12),
                    Text(
                      'لوحة الإحصائيات',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: blackColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  Icons.shopping_cart,
                  statistics['orders'].toString(),
                  'الطلبات',

                  onTap: () => _navigateToOrders(context),
                ),
                _buildStatItem(
                  Icons.assignment_turned_in,
                  statistics['visits'].toString(),
                  'الزيارات',
                  onTap: () => _navigateToVisits(context),
                ),
                _buildStatItem(
                  Icons.receipt,
                  statistics['invoices'].toString(),
                  'الفواتير',
                  onTap: () => _navigateToInvoices(context),
                ),
                _buildStatItem(
                  Icons.assignment_return,
                  statistics['returns'].toString(),
                  'المرتجعات',
                  onTap: () => _navigateToReturns(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToOrders(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MaterialRequestScreen()),
    );
  }

  void _navigateToVisits(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VisitReportPage(filter: 0)),
    );
  }

  void _navigateToInvoices(BuildContext context) {
    final int type = 0;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SalesInvoiceSummaryPage(invoiceType: type, filter: 0),
      ),
    );
  }

  void _navigateToReturns(BuildContext context) {
    final int type = 1;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SalesInvoiceSummaryPage(invoiceType: type, filter: 0),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: blackColor.withOpacity(0.05),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: blackColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: blackColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: blackColor.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await AuthService.logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Login()),
    );
  }

  String formatTime(String isoTime) {
    try {
      final dateTime = DateTime.parse(isoTime);
      return DateFormat('yyyy-MM-dd hh:mm a').format(dateTime);
    } catch (e) {
      return isoTime;
    }
  }
}
