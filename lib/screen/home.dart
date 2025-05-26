import 'package:drsaf/screen/MaterialRequestScreenList.dart';
import 'package:drsaf/screen/login.dart';
import 'package:drsaf/screen/payment_entry_list_page.dart';
import 'package:drsaf/screen/pos.dart';
import 'package:drsaf/screen/pos_return.dart';
import 'package:drsaf/screen/reports.dart';
import 'package:drsaf/screen/store_screen.dart';
import 'package:drsaf/screen/visit.dart';
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
  final Color primaryRed = const Color.fromARGB(255, 156, 20, 20);
  final Color primaryColor = const Color(0xFFBDB395);
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = const Color(0xFFF6F0F0);
  final Color pressedColor = const Color(0xFFF2E2B1);

  final List<Map<String, dynamic>> buttons = [
    {'label': 'POS', 'icon': Icons.point_of_sale},
    {'label': 'MATERIAL REQUESTS', 'icon': Icons.inventory_2},
    {'label': 'PAYMENTS & DEBTS', 'icon': Icons.payments},
    {'label': 'VISIT LOG', 'icon': Icons.assignment_turned_in},
    {'label': 'RETURNS', 'icon': Icons.assignment_return},
    {'label': 'REPORTS', 'icon': Icons.analytics},
    // {'label': 'STORE', 'icon': Icons.store},
  ];
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
    if (!mounted) return; // التحقق أولاً

    setState(() => isLoadingStats = true);

    try {
      if (selectedPOSProfile != null) {
        final posOpeningName = selectedPOSProfile!['name'];
        final prefs = await SharedPreferences.getInstance();
        final posOpeningShift = prefs.getString('pos_open');
        print(
          '***********************************************$posOpeningShift****$posOpeningName',
        );
        final results = await Future.wait([
          PosService.getVisitCount(posOpeningName),
          PosService.getInvoiceCount(posOpeningName),
          PosService.getOrderCount(posOpeningName),
          PosService.getItemCount(),
          PosService.getReturnInvoiceCount(posOpeningName),
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
      print('تم تحميل POS Profile: ${selectedPOSProfile!['name']}');
      print('تم تحميل POS Profile: $time');
    }
  }

  Future<void> _closePOSShift() async {
    try {
      // 1. جلب بيانات الإغلاق أولاً
      final closingData = await _getClosingData();

      // 2. عرض حوار التأكيد مع البيانات
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
          // الحصول على المبلغ النقدي الحالي
          final cashAmount = await _getCurrentCashAmount();

          // استدعاء createClosingEntry
          await PosService.createClosingEntry(cashAmount, selectedPOSProfile!);

          if (mounted) {
            Navigator.pop(context); // إغلاق dialog التحميل
            await _executeClosing();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إغلاق الوردية بنجاح'),
                backgroundColor: Colors.green,
              ),
            );

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Login()),
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
                _buildSummaryRow(
                  'الإجمالي',
                  _formatCurrency(data['total_sales']),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'تفاصيل طرق الدفع',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),

            Container(
              width: double.infinity, // تأخذ العرض الكامل
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal, // التمرير الأفقي عند الحاجة
                child: DataTable(
                  columnSpacing: 20, // تقليل المسافة بين الأعمدة
                  dataRowHeight: 40, // ارتفاع الصفوف
                  headingRowHeight: 40, // ارتفاع رأس الجدول
                  columns: const [
                    DataColumn(
                      label: SizedBox(
                        width: 100, // عرض ثابت للعمود الأول
                        child: Text('طريقة الدفع'),
                      ),
                    ),
                    DataColumn(
                      label: SizedBox(
                        width: 100, // عرض ثابت للعمود الثاني
                        child: Text('المبلغ'),
                      ),
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
                                  overflow:
                                      TextOverflow
                                          .ellipsis, // تقصير النص الطويل
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
                    _formatCurrency(data['total_sales']),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _getClosingData() async {
    if (selectedPOSProfile == null) {
      throw Exception('لا يوجد وردية مفتوحة');
    }

    // جلب الفواتير
    final invoices = await PosService.getShiftInvoices(
      selectedPOSProfile!['name'],
    );

    // جلب طرق الدفع
    final payments = await PosService.getPaymentMethods();

    return {
      'invoice_count': invoices.length,
      'total_sales': invoices.fold(0.0, (sum, inv) => sum + inv['grand_total']),
      'payments': payments,
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
        decimalDigits: 2,
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
                    // التحقق من صحة الإدخال
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
      appBar: AppBar(
        title: const Text(
          'الصفحة الرئيسية',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: _logout,
        ),
        actions: [
          if (selectedPOSProfile != null)
            if (selectedPOSProfile != null)
              IconButton(
                icon: Icon(Icons.refresh, color: primaryColor),
                onPressed: _loadStatistics,
              ),
          IconButton(
            icon: CircleAvatar(
              backgroundColor: secondaryColor,
              child: Icon(Icons.lock_clock, color: primaryColor),
            ),
            onPressed: _closePOSShift,
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (selectedPOSProfile != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        formatTime(time!),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              _buildDashboardCard(),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
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
              ),
              // ElevatedButton(
              //   onPressed: () async {
              //     await AuthService.logout();
              //     Navigator.pushReplacement(
              //       context,
              //       MaterialPageRoute(builder: (context) => const Login()),
              //     );
              //   },
              //   child: const Text('تسجيل الخروج'),
              // ),
              // ElevatedButton(
              //   onPressed: _closePOSShift,
              //   child: const Text('إغلاق الوردية'),
              // ),
            ],
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
        overlayColor: pressedColor,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.3),
      ),
      onPressed: () async {
        final navigator = Navigator.of(context);
        Widget? targetScreen;

        switch (button['label']) {
          case 'VISIT LOG':
            targetScreen = const VisitScreen();
            break;
          case 'MATERIAL REQUESTS':
            targetScreen = const MaterialRequestScreen();
            break;
          case 'POS':
            targetScreen = const POSScreen();
            break;
          case 'PAYMENTS & DEBTS':
            targetScreen = const PaymentEntryListPage();
            break;
          case 'RETURNS':
            targetScreen = const POSReturnScreen();
            break;
          case 'STORE':
            targetScreen = const MaterialStoreScreen();
            break;
          case 'REPORTS':
            targetScreen = const ReportsScreen();
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
          Icon(button['icon'] as IconData, size: 40, color: primaryColor),
          const SizedBox(height: 10),
          Text(
            button['label'] as String,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primaryColor,
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
      elevation: 8, // زيادة الظل لجعلها ثلاثية الأبعاد
      shadowColor: Colors.black.withOpacity(0.5), // اللون الأسود للظل
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
                    Icon(Icons.dashboard, size: 36, color: secondaryColor),
                    const SizedBox(width: 12),
                    Text(
                      'لوحة الإحصائيات',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: secondaryColor,
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
                ),
                _buildStatItem(
                  Icons.assignment_turned_in,
                  statistics['visits'].toString(),
                  'الزيارات',
                ),
                _buildStatItem(
                  Icons.receipt,
                  statistics['invoices'].toString(),
                  'الفواتير',
                ),
                _buildStatItem(
                  Icons.assignment_return,
                  statistics['returns'].toString(),
                  'المرتجعات',
                ),
                // _buildStatItem(
                //   Icons.inventory,
                //   statistics['items'].toString(),
                //   'المخزون',
                // ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String count, String label) {
    return Column(
      children: [
        Icon(icon, size: 28, color: secondaryColor),
        const SizedBox(height: 8),
        Text(
          count,
          style: TextStyle(
            fontFamily: 'Cairo',
            color: secondaryColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            color: secondaryColor,
            fontSize: 14,
          ),
        ),
      ],
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
      // أو أي تنسيق آخر تفضله (انظر الخيارات بالأسفل)
    } catch (e) {
      return isoTime; // في حالة خطأ في التحليل، إرجاع القيمة الأصلية
    }
  }
}
