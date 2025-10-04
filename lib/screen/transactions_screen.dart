import 'package:alkhair_daem/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pos_service.dart';
import 'package:intl/intl.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final Color primaryColor = Color(0xFF60B245);
  final Color secondaryColor = Color(0xFFFFFFFF);
  final Color backgroundColor = Color(0xFFF2F2F2);
  final Color blackColor = Color(0xFF383838);
  bool _isDisposed = false;
  List<TransactionModel> transactions = [];
  bool isLoading = true;
  String errorMessage = '';
  double totalSales = 0.0;
  double totalPayments = 0.0;
  double totalPaidAmount = 0.0;
  double grandTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    if (_isDisposed) return;
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final posOpeningName = prefs.getString('pos_open');

      if (posOpeningName == null || posOpeningName.isEmpty) {
        throw Exception('لا يوجد وردية مفتوحة');
      }

      final results = await Future.wait([
        PosService.get_ShiftInvoices(posOpeningName),
        PosService.get_ShiftPayment(posOpeningName),
      ]);

      final invoices = results[0];
      final payments = results[1];

      List<TransactionModel> tempTransactions = [];
      double salesTotal = 0.0;
      double paymentsTotal = 0.0;
      double paidAmountTotal = 0.0;

      for (var invoice in invoices) {
        final amount = (invoice['grand_total'] ?? 0.0).toDouble();
        final paidAmount = (invoice['paid_amount'] ?? 0.0).toDouble();
        salesTotal += amount;
        paidAmountTotal += paidAmount;

        tempTransactions.add(
          TransactionModel(
            id: invoice['name'] ?? '',
            type: 'sales_invoice',
            typeArabic: 'فاتورة مبيعات',
            customer: invoice['customer'],
            amount: amount,
            paidAmount: paidAmount,
            date: invoice['posting_date'],
            status: invoice['status'],
          ),
        );
      }

      for (var payment in payments) {
        final amount = (payment['paid_amount'] ?? 0.0).toDouble();
        paymentsTotal += amount;

        tempTransactions.add(
          TransactionModel(
            id: payment['name'] ?? '',
            type: 'payment',
            typeArabic: 'مدفوعات',
            customer: payment['party_name'],
            amount: amount,
            paymentMethod: payment['mode_of_payment'],
          ),
        );
      }

      tempTransactions.sort((a, b) {
        if (a.type != b.type) {
          return a.type.compareTo(b.type);
        }
        return a.id.compareTo(b.id);
      });
      if (_isDisposed) return;
      setState(() {
        transactions = tempTransactions;
        totalSales = salesTotal;
        totalPayments = paymentsTotal;
        totalPaidAmount = paidAmountTotal + paymentsTotal;
        grandTotal = salesTotal + paymentsTotal;
        isLoading = false;
      });
    } catch (e) {
      if (_isDisposed) return;
      setState(() {
        errorMessage = 'خطأ في تحميل البيانات: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("تقرير الحركات"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTransactions,
            tooltip: 'تحديث التقرير',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
            SizedBox(height: 16),
            Text(
              'جاري تحميل الحركات...',
              style: TextStyle(fontSize: 16, color: blackColor),
            ),
          ],
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              errorMessage,
              style: TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTransactions,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'لا توجد حركات في الوردية الحالية',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildSummaryCard(),

        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              return _buildTransactionCard(transactions[index]);
            },
          ),
        ),

        _buildTotalCard(),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'فواتير المبيعات',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: blackColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      NumberFormat('#,##0.00').format(totalSales),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 35,
                color: primaryColor.withOpacity(0.3),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'المدفوعات',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: blackColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      NumberFormat('#,##0.00').format(totalPayments),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 12),
          Container(
            height: 1,
            width: double.infinity,
            color: primaryColor.withOpacity(0.3),
          ),
          SizedBox(height: 12),

          Column(
            children: [
              Text(
                'إجمالي المدفوع',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: blackColor,
                ),
              ),
              SizedBox(height: 6),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Text(
                  NumberFormat('#,##0.00').format(totalPaidAmount),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel transaction) {
    final isInvoice = transaction.type == 'sales_invoice';
    final color = isInvoice ? primaryColor : Colors.blue;
    final icon = isInvoice ? Icons.receipt : Icons.payment;

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              transaction.typeArabic,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: blackColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            Text(
              'رقم: ${_formatTransactionId(transaction.id)}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (transaction.customer != null) ...[
              SizedBox(height: 4),
              Text(
                transaction.customer!,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
            if (transaction.paymentMethod != null) ...[
              SizedBox(height: 4),
              Text(
                'طريقة الدفع: ${transaction.paymentMethod}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
            if (transaction.status != null) ...[
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(transaction.status!).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  transaction.status!,
                  style: TextStyle(
                    fontSize: 11,
                    color: _getStatusColor(transaction.status!),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Container(
          constraints: BoxConstraints(maxWidth: 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                NumberFormat('#,##0.00').format(transaction.amount),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),

              if (transaction.type == 'sales_invoice' &&
                  transaction.paidAmount != null) ...[
                SizedBox(height: 2),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    'مدفوع: ${NumberFormat('#,##0.00').format(transaction.paidAmount!)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'إجمالي الحركات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            NumberFormat('#,##0.00').format(grandTotal),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'partly paid':
        return Colors.orange;
      case 'unpaid':
        return Colors.red;
      case 'return':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatTransactionId(String id) {
    if (id.length > 15) {
      return '...${id.substring(id.length - 12)}';
    }
    return id;
  }
}
