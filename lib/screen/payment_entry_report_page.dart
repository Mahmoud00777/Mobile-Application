import 'package:drsaf/models/payment_entry_report';
import 'package:drsaf/screen/payment_details.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/payment_entry_report_service.dart';

class PaymentEntryReportPage extends StatefulWidget {
  const PaymentEntryReportPage({super.key});

  @override
  _PaymentEntryReportPageState createState() => _PaymentEntryReportPageState();
}

class _PaymentEntryReportPageState extends State<PaymentEntryReportPage> {
  final Color primaryColor = Color(0xFFB6B09F);
  final Color secondaryColor = Color(0xFFEAE4D5);
  final Color backgroundColor = Color(0xFFF2F2F2);
  final Color blackColor = Color.fromARGB(255, 85, 84, 84);
  final DateFormat _df = DateFormat('yyyy-MM-dd');

  String? _posProfile;
  DateTime _fromDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _toDate = DateTime.now();

  final List<PaymentEntryReport> _entries = [];
  bool _isLoading = false;
  bool _hasMore = true;
  static const int _pageSize = 20;
  int _offset = 0;

  int _quickFilter = 3;

  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _posProfile =
          prefs.getString('selected_pos_profile_name') ?? 'Default POS Profile';
    });
    _applyQuickFilter(3);
  }

  void _applyQuickFilter(int index) {
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
    _reload();
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
        _quickFilter = -1;
      });
      _reload();
    }
  }

  Future<void> _reload() async {
    _offset = 0;
    _entries.clear();
    _hasMore = true;
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore || _posProfile == null) return;
    setState(() => _isLoading = true);
    try {
      final newItems = await PaymentEntryReportService.fetchReport(
        posProfile: _posProfile!,
        fromDate: _fromDate,
        toDate: _toDate,
        offset: _offset,
        limit: _pageSize,
      );

      setState(() {
        _entries.addAll(newItems);
        _offset += newItems.length;
        _hasMore = newItems.length == _pageSize;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries =
        _searchTerm.isEmpty
            ? _entries
            : _entries
                .where(
                  (e) =>
                      e.party.toLowerCase().contains(_searchTerm.toLowerCase()),
                )
                .toList();

    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: primaryColor,
        colorScheme: Theme.of(
          context,
        ).colorScheme.copyWith(primary: primaryColor, secondary: primaryColor),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تقرير المدفوعات'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchTerm = value.trim();
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'بحث باسم العميل',
                      prefixIcon: Icon(
                        Icons.search,
                        color: primaryColor,
                      ), // لون الأيقونة
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
                  const SizedBox(height: 8),
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
                ],
              ),
            ),
            Expanded(
              child:
                  filteredEntries.isEmpty && _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                        itemCount: filteredEntries.length + (_hasMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i < filteredEntries.length) {
                            final e = filteredEntries[i];
                            return InkWell(
                              onTap: () {
                                print("/*/*/*/*/*/*/*/*//*/*/*");
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            PaymentDetails(payment: e.name),
                                  ),
                                );
                              },
                              child: Card(
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
                                    e.party,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${e.postingDate} – ${e.modeOfPayment}',
                                  ),
                                  trailing: Text(
                                    '${e.paidAmount.toStringAsFixed(2)} LYD',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child:
                                  _isLoading
                                      ? const CircularProgressIndicator()
                                      : OutlinedButton(
                                        onPressed: _loadMore,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: primaryColor,
                                          side: BorderSide(color: primaryColor),
                                        ),
                                        child: const Text('أظهار المزيد'),
                                      ),
                            ),
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
