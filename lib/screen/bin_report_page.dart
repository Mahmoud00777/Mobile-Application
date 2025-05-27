import 'package:drsaf/services/warehouse_service.dart';
import 'package:flutter/material.dart';
import '../models/bin_report.dart';
import '../services/bin_report_service.dart';

class BinReportPage extends StatefulWidget {
  const BinReportPage({Key? key}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _itemController.addListener(() {
      // whenever item text changes, reload report
      _fetchPage(reset: true);
    });
    _loadWarehouses();
  }

  @override
  void dispose() {
    _itemController.removeListener(() {});
    _itemController.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    setState(() => _loading = true);
    try {
      final list = await WarehouseService.getWarehouses();
      setState(() {
        _warehouses = list.map((w) => w.name).toList();
        _selectedWarehouse = _warehouses.isNotEmpty ? _warehouses.first : null;
      });
      _fetchPage(reset: true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchPage({bool reset = false}) async {
    if (_loading || !_hasMore && !reset) return;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Bin Report')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedWarehouse,
                    items:
                        _warehouses
                            .map(
                              (w) => DropdownMenuItem(value: w, child: Text(w)),
                            )
                            .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedWarehouse = v;
                      });
                      _fetchPage(reset: true);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _itemController,
                    decoration: InputDecoration(
                      labelText: 'Item Code',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _data.length + (_hasMore ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i < _data.length) {
                    final row = _data[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        title: Text(
                          row.itemCode,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Warehouse: ${row.warehouse}'),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Actual: ${row.actualQty}'),
                            Text('Projected: ${row.projectedQty}'),
                          ],
                        ),
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child:
                            _loading
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
