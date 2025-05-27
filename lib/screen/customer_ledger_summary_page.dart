import 'package:flutter/material.dart';
import '../models/customer_ledger_summary.dart';
import '../services/customer_ledger_service.dart';
import 'package:intl/intl.dart';

class CustomerLedgerPage extends StatefulWidget {
  const CustomerLedgerPage({Key? key}) : super(key: key);

  @override
  State<CustomerLedgerPage> createState() => _CustomerLedgerPageState();
}

class _CustomerLedgerPageState extends State<CustomerLedgerPage> {
  late DateTime _fromDate;
  late DateTime _toDate;
  late Future<List<CustomerLedgerSummary>> _future;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _toDate = DateTime.now();
    _fromDate = DateTime(_toDate.year, _toDate.month - 1, _toDate.day);
    _loadData();
    _searchController.addListener(() => setState(() {}));
  }

  void _loadData() {
    final df = DateFormat('yyyy-MM-dd');
    _future = CustomerLedgerService.fetchSummary(
      company: 'HR',
      fromDate: df.format(_fromDate),
      toDate: df.format(_toDate),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Ledger Summary')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Customer',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<CustomerLedgerSummary>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final data = snapshot.data ?? [];
                  // filter by search text
                  final filtered =
                      data.where((e) {
                        final term = _searchController.text.toLowerCase();
                        return e.customerName.toLowerCase().contains(term);
                      }).toList();
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No data available'));
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final summary = filtered[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          title: Text(
                            summary.customerName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: Text(
                            '${summary.closingBalance.toStringAsFixed(2)} LYD',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
