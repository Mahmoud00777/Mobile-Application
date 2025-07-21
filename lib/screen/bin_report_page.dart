import 'package:flutter/material.dart';
import 'package:drsaf/services/warehouse_service.dart';
import '../models/bin_report.dart';
import '../services/bin_report_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

class BinReportPage extends StatefulWidget {
  const BinReportPage({super.key});

  @override
  _BinReportPageState createState() => _BinReportPageState();
}

class _BinReportPageState extends State<BinReportPage> {
  final List<BinReport> _data = [];
  final TextEditingController _itemController = TextEditingController();
  String? _selectedWarehouse;
  bool _loading = false;
  String? _error;
  List<String> _warehouses = [];
  int _page = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool? hasInternet;

  final Color primaryColor = Color(0xFF60B245);
  final Color secondaryColor = Color(0xFFFFFFFF);
  final Color backgroundColor = Color(0xFFF2F2F2);
  final Color blackColor = Color(0xFF383838);
  @override
  void initState() {
    super.initState();
    _checkInternet();
  }

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  Future<void> _checkInternet() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    bool realInternet = false;
    if (connectivityResult.first == ConnectivityResult.wifi ||
        connectivityResult.first == ConnectivityResult.mobile ||
        connectivityResult.first == ConnectivityResult.ethernet) {
      try {
        final result = await InternetAddress.lookup('google.com');
        realInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        realInternet = false;
      }
    }
    if (!mounted) return;
    setState(() {
      hasInternet = realInternet;
    });
    if (realInternet) {
      _loadWarehouses();
    }
  }

  Future<void> _loadWarehouses() async {
    setState(() => _loading = true);
    try {
      // 1. جلب المخزن من ملف البيع فقط
      final warehouse = await WarehouseService.getWarehouses();

      setState(() {
        // 2. تعبئة القائمة بالمخزن الوحيد إن وجد
        _warehouses = warehouse != null ? [warehouse.name] : [];

        // 3. تحديد المخزن المحدد (سيكون الوحيد في القائمة)
        _selectedWarehouse = warehouse?.name;
      });

      // 4. تحميل البيانات المرتبطة بالمخزن
      if (_selectedWarehouse != null) {
        _fetchPage(reset: true);
      }
    } catch (e) {
      setState(() => _error = 'حدث خطأ: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في جلب مخزن ملف البيع: ${e.toString()}')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchPage({bool reset = false}) async {
    if (_loading || (!_hasMore && !reset)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (reset) {
        _page = 0;
        _data.clear();
        _hasMore = true;
      }
      final rows = await BinReportService.fetchReport(
        warehouse: _selectedWarehouse!,
        itemCode: _itemController.text.trim(),
        limitStart: _page * _pageSize,
        limitPageLength: _pageSize,
      );
      setState(() {
        _data.addAll(rows);
        _hasMore = rows.length == _pageSize;
        _page++;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (hasInternet == false) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('تقرير المخزون'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 80, color: Colors.redAccent),
              const SizedBox(height: 24),
              Text(
                'لا يوجد اتصال بالإنترنت',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'يرجى التحقق من الاتصال وحاول مرة أخرى',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: Icon(Icons.refresh),
                label: Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  textStyle: TextStyle(fontSize: 18),
                ),
                onPressed: _checkInternet,
              ),
            ],
          ),
        ),
      );
    }
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: primaryColor,
        colorScheme: Theme.of(
          context,
        ).colorScheme.copyWith(primary: primaryColor, secondary: primaryColor),
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: primaryColor, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: primaryColor,
          selectionColor: primaryColor.withOpacity(0.4),
          selectionHandleColor: primaryColor,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تقرير المخزون'),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'المخزن',
                        filled: true,
                        fillColor: secondaryColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      isExpanded: true,
                      value: _selectedWarehouse,
                      items:
                          _warehouses
                              .map(
                                (w) =>
                                    DropdownMenuItem(value: w, child: Text(w)),
                              )
                              .toList(),
                      onChanged: (v) {
                        setState(() => _selectedWarehouse = v);
                        _fetchPage(reset: true);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _itemController,
                      decoration: InputDecoration(
                        labelText: 'الصنف أو الكود',
                        filled: true,
                        fillColor: secondaryColor,
                        prefixIcon: Icon(Icons.search, color: primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: (_) => _fetchPage(reset: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _fetchPage(reset: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: secondaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Icon(Icons.search),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child:
                    _error != null
                        ? Center(child: Text('Error: $_error'))
                        : ListView.builder(
                          itemCount: _data.length + (_hasMore ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i < _data.length) {
                              final row = _data[i];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                color: secondaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 3,
                                child: ListTile(
                                  title: Text(
                                    row.itemCode,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color.fromARGB(255, 85, 84, 84),
                                    ),
                                  ),
                                  subtitle: Text('المخزن: ${row.warehouse}'),
                                  trailing: Text(
                                    'الكمية: ${row.actualQty}',
                                    style: TextStyle(
                                      fontSize: 18, // حجم الخط المكبر
                                      fontWeight: FontWeight.bold,
                                      color: Color.fromARGB(255, 85, 84, 84),
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Center(
                                  child:
                                      _loading
                                          ? const CircularProgressIndicator()
                                          : ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryColor,
                                              foregroundColor: secondaryColor,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            onPressed: () => _fetchPage(),
                                            child: const Text('تحميل المزيد'),
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
      ),
    );
  }
}
