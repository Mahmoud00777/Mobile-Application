import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sales_invoice_summary.dart';
import '../services/sales_invoice_service.dart';

class SalesInvoiceSummaryPage extends StatefulWidget {
  final int? invoiceType; // جعلها nullable
  final int? filter;
  const SalesInvoiceSummaryPage({
    super.key,
    this.invoiceType = 0,
    this.filter = 3,
  });

  @override
  // ignore: library_private_types_in_public_api
  _SalesInvoiceSummaryPageState createState() =>
      _SalesInvoiceSummaryPageState();
}

class _SalesInvoiceSummaryPageState extends State<SalesInvoiceSummaryPage> {
  final DateFormat _df = DateFormat('yyyy-MM-dd');
  final TextEditingController _customerController = TextEditingController();
  final Color primaryColor = Color(0xFFB6B09F);
  final Color secondaryColor = Color(0xFFEAE4D5);
  final Color backgroundColor = Color(0xFFF2F2F2);
  final Color blackColor = Color.fromARGB(255, 85, 84, 84);
  DateTime _fromDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _toDate = DateTime.now();
  int? _isReturnFilter = 0;
  int _quickFilter = 3;

  final List<SalesInvoiceSummary> _invoices = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    // تعيين الفلتر الأولي بناءً على invoiceType
    if (widget.invoiceType == 0 || widget.invoiceType == 1) {
      _isReturnFilter = widget.invoiceType == 1 ? 1 : 0;
    }
    _quickFilter = widget.filter!;

    _applyQuickFilter(widget.filter!);
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
        isReturn: _isReturnFilter, // <-- use the current filter here
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

  void _applyQuickFilter(int index) {
    print('_applyQuickFilter');
    print(_quickFilter);
    print(_isReturnFilter);
    setState(() {
      _quickFilter = index;
      final now = DateTime.now();
      switch (index) {
        case 0:
          _fromDate = DateTime(now.year, now.month, now.day);
          _toDate = now;
          break;
        case 1:
          final yesterday = now.subtract(Duration(days: 1));
          _fromDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
          _toDate = DateTime(
            yesterday.year,
            yesterday.month,
            yesterday.day,
            23,
            59,
            59,
          );
          break;
        case 2:
          _fromDate = now.subtract(Duration(days: 7));
          _toDate = now;
          break;
        case 3:
          _fromDate = DateTime(2020);
          _toDate = now;
          break;
      }
    });
    _fetchPage(reset: true);
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
      appBar: AppBar(
        title: const Text('تقرير المبيعات'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _customerController,
                  decoration: InputDecoration(
                    labelText: 'البحث باسم العميل',
                    prefixIcon: Icon(Icons.search, color: primaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: primaryColor, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onSubmitted: (_) => _fetchPage(reset: true),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _pickDateRange,
                  icon: Icon(Icons.date_range, color: primaryColor),
                  label: Text(
                    '${_df.format(_fromDate)} → ${_df.format(_toDate)}',
                    style: TextStyle(color: primaryColor),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('اليوم'),
                      selected: _quickFilter == 0,
                      selectedColor: primaryColor,
                      onSelected: (_) => _applyQuickFilter(0),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('أمس'),
                      selected: _quickFilter == 1,
                      selectedColor: primaryColor,
                      onSelected: (_) => _applyQuickFilter(1),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('أسبوع'),
                      selected: _quickFilter == 2,
                      selectedColor: primaryColor,
                      onSelected: (_) => _applyQuickFilter(2),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('الكل'),
                      selected: _quickFilter == 3,
                      selectedColor: primaryColor,
                      onSelected: (_) => _applyQuickFilter(3),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                          color: secondaryColor,
                          child: ListTile(
                            title: Text(
                              inv.customer,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            subtitle: Text(
                              '${_df.format(inv.postingDate)} • ${inv.invoiceNumber}',
                              style: const TextStyle(color: Colors.black54),
                            ),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${inv.grandTotal.toStringAsFixed(2)} LYD',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
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
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: secondaryColor,
                                      ),
                                      onPressed: () => _fetchPage(),
                                      child: const Text('أظهار المزيد'),
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
          Positioned(
            bottom: 30,
            right: 30,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.filter_list, color: Colors.white),
                onPressed: () async {
                  final selected = await showModalBottomSheet<int?>(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (context) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 24,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'تصفية حسب النوع',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              leading: Icon(
                                Icons.all_inclusive,
                                color: primaryColor,
                              ),
                              title: const Text('الكل'),
                              onTap: () => Navigator.pop(context, null),
                            ),
                            ListTile(
                              leading: Icon(
                                Icons.receipt_long,
                                color: primaryColor,
                              ),
                              title: const Text('Invoices'),
                              onTap: () => Navigator.pop(context, 0),
                            ),
                            ListTile(
                              leading: Icon(Icons.undo, color: primaryColor),
                              title: const Text('Returns'),
                              onTap: () => Navigator.pop(context, 1),
                            ),
                          ],
                        ),
                      );
                    },
                  );

                  if (selected != _isReturnFilter) {
                    setState(() => _isReturnFilter = selected);
                    _fetchPage(reset: true);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
