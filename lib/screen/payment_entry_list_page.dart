import '../services/payment_service_list.dart';
import 'package:flutter/material.dart';
import '../models/payment_entry_list.dart';
import 'create_payment_page.dart';

class PaymentEntryListPage extends StatefulWidget {
  const PaymentEntryListPage({super.key});

  @override
  State<PaymentEntryListPage> createState() => _PaymentEntryListPageState();
}

class _PaymentEntryListPageState extends State<PaymentEntryListPage> {
  List<PaymentEntry> _payments = [];
  String _searchText = '';
  bool _isLoading = true;
  final _searchController = TextEditingController();
  final Color primaryColor = Color(0xFFB6B09F);
  final Color secondaryColor = Color(0xFFEAE4D5);
  final Color backgroundColor = Color(0xFFF2F2F2);
  final Color blackColor = Color.fromARGB(255, 85, 84, 84);
  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      final payments = await PaymentService.getPaymentEntries(
        customer: _searchText.trim().isNotEmpty ? _searchText.trim() : null,
      );
      setState(() => _payments = payments);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: primaryColor),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSearch() {
    FocusScope.of(context).unfocus();
    _loadPayments();
  }

  double get totalPaid => _payments.fold(0.0, (sum, e) => sum + e.paidAmount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('دفعات العملاء'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        // iconTheme: IconThemeData(color: secondaryColor),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'بحث باسم العميل...',
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: (_) => _onSearch(),
                    onChanged: (v) => _searchText = v,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _onSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: secondaryColor,
                  ),
                  child: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                    : _payments.isEmpty
                    ? Center(
                      child: Text(
                        'لا توجد نتائج',
                        style: TextStyle(color: primaryColor),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _payments.length + 1,
                      itemBuilder: (ctx, i) {
                        if (i < _payments.length) {
                          final e = _payments[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            color: secondaryColor,
                            shape: RoundedRectangleBorder(),
                            child: ListTile(
                              title: Text(e.party),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('طريقة الدفع: ${e.modeOfPayment}'),
                                  Text('تاريخ: ${e.postingDate}'),
                                ],
                              ),
                              trailing: Text(
                                e.paidAmount.toStringAsFixed(2),
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        } else {
                          return Card(
                            margin: const EdgeInsets.all(12),
                            color: primaryColor,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'إجمالي المدفوع',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: secondaryColor,
                                    ),
                                  ),
                                  Text(
                                    totalPaid.toStringAsFixed(2),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: secondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FloatingActionButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreatePaymentPage()),
              );
              _loadPayments();
            },
            backgroundColor: primaryColor,
            foregroundColor: secondaryColor,
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}
