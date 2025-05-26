import 'package:flutter/material.dart';
import '../models/total_stock_summary.dart';
import '../models/warehouse.dart';
import '../services/warehouse_service.dart';
import '../services/stock_service.dart';

class TotalStockSummaryPage extends StatefulWidget {
  const TotalStockSummaryPage({super.key});

  @override
  _TotalStockSummaryPageState createState() => _TotalStockSummaryPageState();
}

class _TotalStockSummaryPageState extends State<TotalStockSummaryPage> {
  List<Warehouse> _warehouses = [];
  String? _selectedWarehouse;
  List<TotalStockSummary> _summary = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchWarehousesAndLoad();
  }

  Future<void> _fetchWarehousesAndLoad() async {
    setState(() => _loading = true);
    try {
      final list = await WarehouseService.getWarehouses();
      if (list.isEmpty) throw Exception('لا توجد مخازن');
      setState(() {
        _warehouses = list;
        _selectedWarehouse = list.first.name;
      });
      await _loadReport();
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadReport() async {
    if (_selectedWarehouse == null) return;
    setState(() => _loading = true);
    try {
      final data = await StockService.fetchSummary(
        warehouse: _selectedWarehouse!,
        company: 'HR',
        groupBy: 'Warehouse',
      );
      setState(() => _summary = data);
      if (data.isEmpty) _showError('لا توجد بيانات للتقرير');
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg, textAlign: TextAlign.center)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ملخص المخزون الكلي')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Warehouse selector
            DropdownButton<String>(
              isExpanded: true,
              value: _selectedWarehouse,
              items:
                  _warehouses.map((w) {
                    return DropdownMenuItem(value: w.name, child: Text(w.name));
                  }).toList(),
              onChanged: (val) {
                setState(() => _selectedWarehouse = val);
                _loadReport();
              },
            ),
            const SizedBox(height: 16),
            // Report cards or loading indicator
            _loading
                ? Expanded(child: Center(child: CircularProgressIndicator()))
                : _summary.isEmpty
                ? Expanded(child: Center(child: Text('لا توجد بيانات')))
                : Expanded(
                  child: ListView.builder(
                    itemCount: _summary.length,
                    itemBuilder: (ctx, i) {
                      final row = _summary[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.item,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text('الوصف: ${row.description}'),
                              const SizedBox(height: 4),
                              Text('الكمية الحالية: ${row.currentQty}'),
                            ],
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
