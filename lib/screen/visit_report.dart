import 'package:flutter/material.dart';
import '../models/visit.dart';
import '../services/visit_service.dart';
import 'package:intl/intl.dart';

class VisitReportPage extends StatefulWidget {
  final int filter;
  const VisitReportPage({super.key, required this.filter});

  @override
  _VisitReportPageState createState() => _VisitReportPageState();
}

class _VisitReportPageState extends State<VisitReportPage> {
  final Color primaryColor = Color(0xFF60B245);
  final Color secondaryColor = Color(0xFFFFFFFF);
  final Color backgroundColor = Color(0xFFF2F2F2);
  final Color blackColor = Color(0xFF383838);
  final DateFormat _df = DateFormat('yyyy-MM-dd');

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  int _quickFilter = 3;

  List<Visit> _allVisits = [];
  List<Visit> _filteredVisits = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  bool _isDisposed = false;
  @override
  void initState() {
    super.initState();
    _quickFilter = widget.filter;
    _applyQuickFilter(_quickFilter);
    _searchController.addListener(_applySearch);
    _isDisposed = true;
  }

  @override
  void dispose() {
    _isDisposed = false;
    _searchController.dispose();
    super.dispose();
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
          final yesterday = now.subtract(const Duration(days: 1));
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
          _fromDate = now.subtract(const Duration(days: 7));
          _toDate = now;
          break;
        case 3:
          _fromDate = DateTime(2020);
          _toDate = now;
          break;
      }
    });
    _loadReport();
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
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final data = await VisitService.fetchVisitsByProfileDate(
        from: _fromDate,
        to: _toDate,
      );
      if (!_isDisposed) return;
      setState(() {
        _allVisits = data;
        _applySearch();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في تحميل البيانات: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applySearch() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredVisits = _allVisits;
      } else {
        _filteredVisits =
            _allVisits
                .where((v) => v.customer.toLowerCase().contains(query))
                .toList();
      }
    });
  }

  void _showStateFilterBottomSheet(BuildContext context) {
    final states = _allVisits.map((v) => v.select_state).toSet().toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'فلترة حسب الحالة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // خيار "الكل"
              SingleChildScrollView(
                child: ListTile(
                  leading: const Icon(Icons.all_inclusive, color: Colors.black),
                  title: const Text('الكل'),
                  onTap: () {
                    setState(() {
                      _filteredVisits = _allVisits;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),

              // عرض الحالات مع الأيقونات
              ...states.map((state) {
                IconData icon;
                Color color;

                switch (state) {
                  case 'لم تتم زيارة':
                    icon = Icons.pending_actions;
                    color = Colors.orange;
                    break;
                  case 'تمت زيارة':
                    icon = Icons.check_circle;
                    color = Colors.green;
                    break;
                  case 'فاتورة':
                    icon = Icons.receipt;
                    color = Colors.blue;
                    break;
                  case 'ايصال قبض':
                    icon = Icons.payment;
                    color = Colors.purple;
                    break;
                  case 'فاتورة + ايصال قبض':
                    icon = Icons.receipt_long;
                    color = Colors.indigo;
                    break;
                  default:
                    icon = Icons.filter_alt;
                    color = Colors.grey;
                }

                return ListTile(
                  leading: Icon(icon, color: color),
                  title: Text(state),
                  onTap: () {
                    setState(() {
                      _filteredVisits =
                          _allVisits
                              .where((v) => v.select_state == state)
                              .toList();
                    });
                    Navigator.pop(context);
                  },
                );
              }),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: primaryColor,

        colorScheme: Theme.of(
          context,
        ).colorScheme.copyWith(primary: primaryColor, secondary: primaryColor),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تقرير الزيارات'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomRight: Radius.circular(25),
              bottomLeft: Radius.circular(25),
            ),
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'بحث باسم العميل',
                          prefixIcon: Icon(Icons.search, color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                    ],
                  ),
                ),
                Expanded(
                  child:
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _filteredVisits.isEmpty
                          ? const Center(child: Text('لا توجد زيارات'))
                          : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredVisits.length,
                            itemBuilder: (ctx, i) {
                              final v = _filteredVisits[i];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  title: Text(
                                    v.customer,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: primaryColor,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      DateFormat(
                                        'yyyy-MM-dd – HH:mm',
                                      ).format(v.dateTime),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.15),
                                      border: Border.all(color: primaryColor),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      v.select_state,
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: GestureDetector(
                onTap: () => _showStateFilterBottomSheet(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: const Icon(Icons.filter_alt, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
