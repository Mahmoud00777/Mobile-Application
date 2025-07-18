import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer_ledger_summary.dart';
import '../services/customer_ledger_service.dart';

class CustomerLedgerPage extends StatefulWidget {
  const CustomerLedgerPage({super.key});

  @override
  State<CustomerLedgerPage> createState() => _CustomerLedgerPageState();
}

class _CustomerLedgerPageState extends State<CustomerLedgerPage> {
  final Color primaryColor = Color(0xFF60B245);
  final Color secondaryColor = Color(0xFFFFFFFF);
  final Color backgroundColor = Color(0xFFF2F2F2);
  final Color blackColor = Color(0xFF383838);

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
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: primaryColor,
        colorScheme: Theme.of(
          context,
        ).colorScheme.copyWith(primary: primaryColor, secondary: primaryColor),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: primaryColor,
          selectionColor: primaryColor.withOpacity(0.4),
          selectionHandleColor: primaryColor,
        ),
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: primaryColor, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تقرير المستحقات'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Search bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'بحث باسم العميل',
                  filled: true,
                  fillColor: secondaryColor,
                  prefixIcon: Icon(Icons.search, color: primaryColor),
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
                            horizontal: 4,
                            vertical: 6,
                          ),
                          color: secondaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 3,
                          child: ListTile(
                            title: Text(
                              summary.customerName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            trailing: Text(
                              '${summary.closingBalance.toStringAsFixed(2)} LYD',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            onTap: () {
                              // action if needed
                            },
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
      ),
    );
  }
}
