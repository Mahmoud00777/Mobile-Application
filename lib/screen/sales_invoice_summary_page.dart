import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sales_invoice_summary.dart';
import '../services/sales_invoice_service.dart';

class SalesInvoiceSummaryPage extends StatefulWidget {
  const SalesInvoiceSummaryPage({super.key});

  @override
  _SalesInvoiceSummaryPageState createState() =>
      _SalesInvoiceSummaryPageState();
}

class _SalesInvoiceSummaryPageState extends State<SalesInvoiceSummaryPage> {
  final DateFormat _df = DateFormat('yyyy-MM-dd');
  final TextEditingController _customerController = TextEditingController();

  DateTime _fromDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _toDate = DateTime.now();
  int? _isReturnFilter; // null = all, 1 = returns only, 0 = non-returns

  final List<SalesInvoiceSummary> _invoices = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _fetchPage(reset: true);
  }

  Future<void> _fetchPage({bool reset = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final list = await SalesInvoiceService.fetchInvoices(
        company: 'HR',
        fromDate: _df.format(_fromDate),
        toDate: _df.format(_toDate),
        customer: _customerController.text.trim(),
        isReturn: _isReturnFilter,
        limitStart: reset ? 0 : _page * _pageSize,
        limitPageLength: _pageSize,
      );

      setState(() {
        if (reset) {
          _invoices.clear();
          _page = 1;
        } else {
          _page++;
        }
        _invoices.addAll(list);
        _hasMore = list.length == _pageSize;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _fetchPage(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Invoice Summary')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Customer search
            TextField(
              controller: _customerController,
              decoration: InputDecoration(
                labelText: 'Search Customer',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (_) => _fetchPage(reset: true),
            ),
            const SizedBox(height: 12),

            // Date range picker
            TextButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Icons.date_range),
              label: Text('${_df.format(_fromDate)} → ${_df.format(_toDate)}'),
            ),
            const SizedBox(height: 12),

            // Return filter toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _isReturnFilter == null,
                  onSelected: (_) {
                    setState(() => _isReturnFilter = null);
                    _fetchPage(reset: true);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Invoices'),
                  selected: _isReturnFilter == 0,
                  onSelected: (_) {
                    setState(() => _isReturnFilter = 0);
                    _fetchPage(reset: true);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Returns'),
                  selected: _isReturnFilter == 1,
                  onSelected: (_) {
                    setState(() => _isReturnFilter = 1);
                    _fetchPage(reset: true);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Invoice list
            Expanded(
              child: ListView.builder(
                itemCount: _invoices.length + (_hasMore ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i < _invoices.length) {
                    final inv = _invoices[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                      child: ListTile(
                        title: Text(
                          inv.invoiceNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${_df.format(inv.postingDate)} • ${inv.customer}',
                        ),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              inv.grandTotal.toStringAsFixed(2) + ' LYD',
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              inv.customPosOpenShift,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child:
                            _isLoading
                                ? const CircularProgressIndicator()
                                : ElevatedButton(
                                  onPressed: () => _fetchPage(),
                                  child: const Text('Load More'),
                                ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
