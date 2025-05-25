import '../services/payment_service_list.dart';
import 'package:flutter/material.dart';
import '../models/payment_entry_list.dart';
import 'create_payment_page.dart';
// Import your payment entry creation page

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
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
      appBar: AppBar(title: const Text('دفعات العملاء')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'بحث باسم العميل...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: (_) => _onSearch(),
                    onChanged: (v) => _searchText = v,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _onSearch,
                  child: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _payments.isEmpty
                    ? const Center(child: Text('لا توجد نتائج'))
                    : ListView.builder(
                      itemCount: _payments.length + 1, // one extra for summary
                      itemBuilder: (ctx, i) {
                        if (i < _payments.length) {
                          final e = _payments[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        } else {
                          return Card(
                            margin: const EdgeInsets.all(12),
                            color: Colors.grey[200],
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'إجمالي المدفوع',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    totalPaid.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreatePaymentPage()),
              );
            },
            backgroundColor: Colors.blue,
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}
