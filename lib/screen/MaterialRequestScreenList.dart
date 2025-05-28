import 'package:drsaf/screen/material_request_detail_page.dart';
import 'package:drsaf/screen/materials_request.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/materials_requestM.dart';
import '../services/materials_service.dart';

class MaterialRequestScreen extends StatefulWidget {
  const MaterialRequestScreen({super.key});

  @override
  State<MaterialRequestScreen> createState() => _MaterialRequestScreenState();
}

class _MaterialRequestScreenState extends State<MaterialRequestScreen> {
  late Future<List<MaterialRequest>> _requestsFuture;
  final Color primaryColor = const Color(0xFFBDB395);
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = const Color(0xFFF6F0F0);
  final Color pressedColor = const Color(0xFFF2E2B1);

  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';
  String? _selectedStatus;
  final List<String> _statusOptions = ['معلق', 'موافق عليه', 'مرفوض'];

  @override
  void initState() {
    super.initState();
    _requestsFuture = MaterialRequestService.getMaterialRequests();
  }

  void _refreshRequests() {
    setState(() {
      _requestsFuture = MaterialRequestService.getMaterialRequests();
      _selectedDateRange = null;
      _searchQuery = '';
      _selectedStatus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'طلبات المواد',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(25),
            bottomLeft: Radius.circular(25),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshRequests,
          ),
        ],
      ),
      body: FutureBuilder<List<MaterialRequest>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color.fromARGB(255, 156, 20, 20),
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'حدث خطأ في جلب البيانات',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 156, 20, 20),
                    ),
                    onPressed: _refreshRequests,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          final requests = snapshot.data!;
          final searchLower = _searchQuery.replaceAll('/', '').toLowerCase();

          final filteredRequests =
              requests.where((req) {
                final matchDateRange =
                    _selectedDateRange == null ||
                    (DateTime.tryParse(req.transactionDate) != null &&
                        DateTime.parse(req.transactionDate).isAfter(
                          _selectedDateRange!.start.subtract(
                            const Duration(days: 1),
                          ),
                        ) &&
                        DateTime.parse(req.transactionDate).isBefore(
                          _selectedDateRange!.end.add(const Duration(days: 1)),
                        ));

                String formattedTransactionDate = DateFormat('yyyyMMdd').format(
                  DateTime.tryParse(req.transactionDate) ?? DateTime(2000),
                );
                String formattedScheduleDate = DateFormat(
                  'yyyyMMdd',
                ).format(DateTime.tryParse(req.scheduleDate) ?? DateTime(2000));

                final matchSearch =
                    _searchQuery.isEmpty ||
                    req.name.toLowerCase().contains(searchLower) ||
                    formattedTransactionDate.contains(searchLower) ||
                    formattedScheduleDate.contains(searchLower) ||
                    _matchesYearMonth(req.transactionDate, _searchQuery) ||
                    _matchesYearMonth(req.scheduleDate, _searchQuery);

                final matchStatus =
                    _selectedStatus == null ||
                    _selectedStatus == '' ||
                    req.status == _selectedStatus;

                return matchDateRange && matchSearch && matchStatus;
              }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'بحث برقم الطلب أو التاريخ (مثال: 2024/05)',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.trim();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const SizedBox(width: 4),
                    DropdownButton<String>(
                      value: _selectedStatus,
                      hint: const Text('الحالة'),
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('كل الحالات'),
                        ),
                        ..._statusOptions.map((status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value == '' ? null : value;
                        });
                      },
                    ),
                  ],
                ),
              ),

              if (filteredRequests.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      _searchQuery.isNotEmpty ||
                              _selectedDateRange != null ||
                              (_selectedStatus != null && _selectedStatus != '')
                          ? 'لا توجد نتائج مطابقة'
                          : 'لا توجد طلبات حالياً',
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredRequests.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final req = filteredRequests[index];
                      return _buildRequestCard(context, req);
                    },
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewRequest(context),
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, size: 28, color: Colors.white),
      ),
    );
  }

  bool _matchesYearMonth(String dateStr, String query) {
    try {
      final date = DateTime.tryParse(dateStr);
      if (date == null) return false;

      final normalizedQuery = query
          .trim()
          .replaceAll('-', '/')
          .replaceAll('.', '/');
      final parts = normalizedQuery.split('/');
      if (parts.length != 2) return false;

      final part1 = int.tryParse(parts[0]);
      final part2 = int.tryParse(parts[1]);
      if (part1 == null || part2 == null) return false;

      final isYearMonth = part1 > 1900;
      final year = isYearMonth ? part1 : part2;
      final month = isYearMonth ? part2 : part1;

      return date.year == year && date.month == month;
    } catch (_) {
      return false;
    }
  }

  Widget _buildRequestCard(BuildContext context, MaterialRequest req) {
    Color getStatusColor(String status) {
      switch (status) {
        case 'معلق':
          return Colors.orange;
        case 'موافق عليه':
          return Colors.green;
        case 'مرفوض':
          return Colors.red;
        default:
          return const Color.fromARGB(255, 24, 120, 255);
      }
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: pressedColor.withOpacity(0.3),
        highlightColor: pressedColor.withOpacity(0.2),
        onTap: () => _navigateToDetail(context, req.name),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            req.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Chip(
                          label: Text(
                            req.status,
                            style: TextStyle(
                              color: getStatusColor(req.status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: getStatusColor(
                            req.status,
                          ).withOpacity(0.15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (req.reason.isNotEmpty)
                      Text(
                        '📦 النوع: ${req.reason}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    if (req.warehouse.isNotEmpty)
                      Text(
                        '🏬 المخزن: ${req.warehouse}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    Text(
                      '📅 تاريخ الطلب: ${req.transactionDate}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    Text(
                      '🕒 الموعد المخطط: ${req.scheduleDate}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createNewRequest(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MaterialRequestPage()),
    );
    if (result == true) {
      _refreshRequests();
    }
  }

  void _navigateToDetail(BuildContext context, String requestName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialRequestDetailPage(requestName: requestName),
      ),
    );
  }
}
