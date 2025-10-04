import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/pos_service.dart';
import '../Class/message_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TreasuryScreen extends StatefulWidget {
  const TreasuryScreen({super.key});

  @override
  _TreasuryScreenState createState() => _TreasuryScreenState();
}

class _TreasuryScreenState extends State<TreasuryScreen> {
  final Color primaryColor = Color(0xFF60B245);
  final Color secondaryColor = Color(0xFFFFFFFF);
  final Color backgroundColor = Color(0xFFF2F2F2);
  final Color blackColor = Color(0xFF383838);

  bool _isLoading = true;
  Map<String, dynamic>? _treasuryData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTreasuryReport();
  }

  Future<void> _loadTreasuryReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // جلب بيانات طرق الدفع من الفواتير
      final paymentMethodsData =
          await PosService.getPaymentMethodsWithPaidAmount();

      // جلب المدفوعات الإضافية
      final prefs = await SharedPreferences.getInstance();
      final posOpeningName = prefs.getString('pos_open');

      List<Map<String, dynamic>> additionalPayments = [];
      if (posOpeningName != null) {
        additionalPayments = await PosService.getShiftPaymentEntries(
          posOpeningName,
        );
      }

      // دمج البيانات
      final combinedData = _combineTreasuryData(
        paymentMethodsData,
        additionalPayments,
      );

      if (mounted) {
        setState(() {
          _treasuryData = combinedData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
        MessageService.showError(
          context,
          'فشل في تحميل تقرير الخزينة: ${e.toString()}',
        );
      }
    }
  }

  Map<String, dynamic> _combineTreasuryData(
    Map<String, dynamic> paymentMethodsData,
    List<Map<String, dynamic>> additionalPayments,
  ) {
    final summary = Map<String, dynamic>.from(paymentMethodsData['summary']);
    final paymentMethods = List<Map<String, dynamic>>.from(
      paymentMethodsData['payment_methods'],
    );
    final shiftName = paymentMethodsData['shift_name'] as String;

    // تجميع المدفوعات الإضافية
    final Map<String, double> additionalPaymentsByMethod = {};
    final Map<String, int> additionalPaymentsCount = {};

    double totalAdditionalPayments = 0.0;
    int totalAdditionalPaymentsCount = 0;

    for (final payment in additionalPayments) {
      final method = payment['mode_of_payment']?.toString() ?? 'نقدي';
      final amount = (payment['paid_amount'] as num).toDouble();

      additionalPaymentsByMethod[method] =
          (additionalPaymentsByMethod[method] ?? 0.0) + amount;
      additionalPaymentsCount[method] =
          (additionalPaymentsCount[method] ?? 0) + 1;

      totalAdditionalPayments += amount;
      totalAdditionalPaymentsCount++;
    }

    // دمج المدفوعات الإضافية مع طرق الدفع الموجودة
    for (final method in additionalPaymentsByMethod.keys) {
      final existingMethodIndex = paymentMethods.indexWhere(
        (m) => m['method'] == method,
      );

      if (existingMethodIndex != -1) {
        // إضافة المدفوعات الإضافية إلى الطريقة الموجودة
        paymentMethods[existingMethodIndex]['paid_amount'] +=
            additionalPaymentsByMethod[method]!;
        paymentMethods[existingMethodIndex]['invoice_count'] +=
            additionalPaymentsCount[method]!;
      } else {
        // إضافة طريقة دفع جديدة
        paymentMethods.add({
          'method': method,
          'paid_amount': additionalPaymentsByMethod[method]!,
          'total_amount': additionalPaymentsByMethod[method]!,
          'invoice_count': additionalPaymentsCount[method]!,
          'percentage_of_paid': 0.0, // سيتم حسابها لاحقاً
        });
      }
    }

    // إعادة حساب النسب المئوية والإجماليات
    final totalPaidAmount =
        summary['total_paid_amount'] + totalAdditionalPayments;
    final totalInvoices =
        summary['total_invoices'] + totalAdditionalPaymentsCount;

    // تحديث النسب المئوية
    for (final method in paymentMethods) {
      if (totalPaidAmount > 0) {
        method['percentage_of_paid'] =
            (method['paid_amount'] / totalPaidAmount) * 100;
      }
    }

    // تحديث الملخص
    summary['total_paid_amount'] = totalPaidAmount;
    summary['total_invoices'] = totalInvoices;
    summary['additional_payments'] = totalAdditionalPayments;
    summary['additional_payments_count'] = totalAdditionalPaymentsCount;

    return {
      'summary': summary,
      'payment_methods': paymentMethods,
      'shift_name': shiftName,
      'additional_payments': additionalPayments,
      'report_date': DateTime.now().toIso8601String(),
    };
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      symbol: "د.ل",
      decimalDigits: 2,
      locale: 'ar_LY',
    ).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("تقرير الخزينة"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTreasuryReport,
            tooltip: 'تحديث التقرير',
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : _errorMessage != null
              ? _buildErrorWidget()
              : _treasuryData != null
              ? _buildTreasuryReport()
              : _buildEmptyWidget(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'حدث خطأ في تحميل التقرير',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            _errorMessage ?? 'خطأ غير معروف',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadTreasuryReport,
            child: Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'لا توجد بيانات للخزينة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'تأكد من وجود وردية مفتوحة وفواتير مدفوعة',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTreasuryReport() {
    final summary = _treasuryData!['summary'] as Map<String, dynamic>;
    final paymentMethods = _treasuryData!['payment_methods'] as List<dynamic>;
    final shiftName = _treasuryData!['shift_name'] as String;

    return RefreshIndicator(
      onRefresh: _loadTreasuryReport,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 32,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تقرير الخزينة',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'الوردية: $shiftName',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'إجمالي الإيرادات',
                            _formatCurrency(summary['total_paid_amount']),
                            Icons.money,
                            Colors.green,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            'عدد الفواتير',
                            '${summary['invoices_with_payments']}',
                            Icons.receipt,
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    if (summary['additional_payments'] != null &&
                        summary['additional_payments'] > 0) ...[
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'المدفوعات الإضافية',
                              _formatCurrency(summary['additional_payments']),
                              Icons.payment,
                              Colors.orange,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'عدد المدفوعات',
                              '${summary['additional_payments_count']}',
                              Icons.account_balance_wallet,
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Payment Methods Section
            Text(
              'تفاصيل طرق الدفع',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: blackColor,
              ),
            ),
            SizedBox(height: 12),

            // Payment Methods List
            ...paymentMethods.map((method) => _buildPaymentMethodCard(method)),

            SizedBox(height: 20),

            // Additional Payments Section (if any)
            if (_treasuryData!['additional_payments'] != null &&
                (_treasuryData!['additional_payments'] as List).isNotEmpty) ...[
              Text(
                'المدفوعات الإضافية',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: blackColor,
                ),
              ),
              SizedBox(height: 12),
              _buildAdditionalPaymentsSection(),
              SizedBox(height: 20),
            ],

            // Summary Details
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ملخص التقرير',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: blackColor,
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildSummaryRow(
                      'إجمالي الإيرادات',
                      _formatCurrency(summary['total_paid_amount']),
                    ),
                    _buildSummaryRow(
                      'إجمالي الفواتير',
                      _formatCurrency(summary['total_grand_total']),
                    ),
                    _buildSummaryRow(
                      'عدد الفواتير',
                      '${summary['total_invoices']}',
                    ),
                    _buildSummaryRow(
                      'عدد طرق الدفع',
                      '${summary['payment_methods_count']}',
                    ),
                    if (summary['additional_payments'] != null &&
                        summary['additional_payments'] > 0) ...[
                      _buildSummaryRow(
                        'المدفوعات الإضافية',
                        _formatCurrency(summary['additional_payments']),
                      ),
                      _buildSummaryRow(
                        'عدد المدفوعات الإضافية',
                        '${summary['additional_payments_count']}',
                      ),
                    ],
                    _buildSummaryRow(
                      'تاريخ التقرير',
                      DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method) {
    final methodName = method['method'] as String;
    final paidAmount = method['paid_amount'] as double;
    final totalAmount = method['total_amount'] as double;
    final invoiceCount = method['invoice_count'] as int;
    final percentage = method['percentage_of_paid'] as double;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.payment, color: primaryColor, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        methodName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: blackColor,
                        ),
                      ),
                      Text(
                        '$invoiceCount فاتورة',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(paidAmount),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalPaymentsSection() {
    final additionalPayments =
        _treasuryData!['additional_payments'] as List<dynamic>;
    final paymentMethods = _treasuryData!['payment_methods'] as List<dynamic>;

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: additionalPayments.length,
      itemBuilder: (context, index) {
        final payment = additionalPayments[index];
        final methodName = payment['mode_of_payment']?.toString() ?? 'نقدي';
        final paidAmount = payment['paid_amount'] as double;
        final invoiceCount = payment['invoice_count'];

        final method = paymentMethods.firstWhere(
          (m) => m['method'] == methodName,
          orElse: () => {'method': methodName, 'percentage_of_paid': 0.0},
        );
        final percentage = method['percentage_of_paid'] as double;

        return Card(
          margin: EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.payment, color: primaryColor, size: 20),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            methodName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: blackColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrency(paidAmount),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: blackColor,
            ),
          ),
        ],
      ),
    );
  }
}
