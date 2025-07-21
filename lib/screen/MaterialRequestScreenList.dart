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

  final Color primaryColor = Color(0xFF60B245);
  final Color secondaryColor = Color(0xFFFFFFFF);
  final Color backgroundColor = Color(0xFFF2F2F2);
  final Color blackColor = Color(0xFF383838);
  final Color pressedColor = const Color(0xFFF2E2B1);

  DateTimeRange? _selectedDateRange;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  final DateFormat _df = DateFormat('yyyy-MM-dd');

  String _searchQuery = '';
  String? _selectedStatus;
  static const Map<String, String> statusLabels = {
    'Pending': 'قيد الانتظار',
    'Draft': 'مسودة',
    'Transferred': 'تم التحويل',
    'Cancelled': 'ملغاة',
  };
  final List<String> _statusOptions = [
    'Pending',
    'Draft',
    'Transferred',
    'Cancelled',
  ];

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
      _fromDate = DateTime.now().subtract(const Duration(days: 30));
      _toDate = DateTime.now();
    });
  }

  Future<void> _pickDateRange() async {
    // Show the date range picker with default English locale and themed colors
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor, // Header background
              onPrimary: Colors.white, // Header text/icons
              surface: Colors.white, // Picker background
              onSurface: Colors.black, // Picker text
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryColor, // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
        _selectedDateRange = picked;
      });
    }
  }

  void _showFilterBottomSheet() {
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
                'فلتر حسب الطلب',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // خيار الكل
              ListTile(
                title: const Text('الكل'),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.list, color: Colors.black54),
                    const SizedBox(width: 8),
                  ],
                ),
                onTap: () {
                  setState(() {
                    _selectedStatus = null;
                  });
                  Navigator.pop(context);
                },
              ),
              // خيارات الحالات
              ..._statusOptions.map((status) {
                return ListTile(
                  title: Text(statusLabels[status] ?? status),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _getStatusIcon(statusLabels[status] ?? status),
                      const SizedBox(width: 8),
                    ],
                  ),
                  onTap: () {
                    setState(() {
                      _selectedStatus = status;
                    });
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Icon _getStatusIcon(String status) {
    switch (status) {
      case 'قيد الانتظار':
        return const Icon(Icons.hourglass_top, color: Colors.orange);
      case 'تمت الموافقة':
        return const Icon(Icons.done_all, color: Colors.green);
      case 'ملغاة':
        return const Icon(Icons.cancel, color: Colors.red);
      case 'قيد التحويل':
        return const Icon(Icons.sync_alt, color: Colors.blue);
      default:
        return const Icon(Icons.info, color: Colors.grey);
    }
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
        case 'مسودة':
          return Colors.red;
        case 'تم التحويل':
          return const Color.fromARGB(255, 32, 85, 202);
        case 'ملغاة':
          return Colors.red;
        case 'قيد الانتظار':
          return Colors.orange;
        case 'تمت الموافقة ':
          return Colors.green;
        default:
          return const Color.fromARGB(255, 105, 105, 106);
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
                            statusLabels[req.status] ?? req.status,
                            style: TextStyle(
                              color: getStatusColor(
                                statusLabels[req.status] ?? req.status,
                              ),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: getStatusColor(
                            statusLabels[req.status] ?? req.status,
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
                        'Type: ${req.reason}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    if (req.warehouse.isNotEmpty)
                      Text(
                        'Warehouse: ${req.warehouse}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    Text(
                      'Request Date: ${req.transactionDate}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    Text(
                      'Scheduled Date: ${req.scheduleDate}',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: const Text(
          'طلبات المواد',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
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
            icon: const Icon(Icons.refresh, color: Colors.white),
            color: Colors.white,
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
                    'Error fetching data',
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
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final requests = snapshot.data!;
          final searchLower = _searchQuery.replaceAll('/', '').toLowerCase();

          final filteredRequests =
              requests.where((req) {
                // Date range match
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

                // Normalize dates for year/month query
                String formattedTransactionDate = DateFormat('yyyyMMdd').format(
                  DateTime.tryParse(req.transactionDate) ?? DateTime(2000),
                );
                String formattedScheduleDate = DateFormat(
                  'yyyyMMdd',
                ).format(DateTime.tryParse(req.scheduleDate) ?? DateTime(2000));

                final nameNormalized =
                    req.name.replaceAll('/', '').toLowerCase();

                final matchSearch =
                    _searchQuery.isEmpty ||
                    nameNormalized.contains(searchLower) ||
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
              // Search bar
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
                          hintText: 'Search by request ID',
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
                  ],
                ),
              ),

              // Date range picker button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: _pickDateRange,
                    icon: Icon(Icons.date_range, color: primaryColor),
                    label: Text(
                      '${_df.format(_fromDate)} → ${_df.format(_toDate)}',
                      style: TextStyle(color: primaryColor),
                    ),
                  ),
                ),
              ),

              if (filteredRequests.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      _searchQuery.isNotEmpty ||
                              _selectedDateRange != null ||
                              (_selectedStatus != null && _selectedStatus != '')
                          ? 'No matching results'
                          : 'No requests available',
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

      // Floating action buttons: filter + add
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 16.0, bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'filter',
              onPressed: _showFilterBottomSheet,
              backgroundColor: primaryColor,
              child: const Icon(
                Icons.filter_alt,
                size: 28,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: 'add',
              onPressed: () => _createNewRequest(context),
              backgroundColor: primaryColor,
              child: const Icon(Icons.add, size: 28, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
