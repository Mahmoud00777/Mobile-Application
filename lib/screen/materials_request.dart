import 'package:drsaf/models/materials_requestM.dart';
import 'package:drsaf/services/materials_service.dart';
import 'package:flutter/material.dart';
import '../models/item.dart';
import '../models/warehouse.dart';
import '../services/item_service.dart';
import '../services/warehouse_service.dart';

class MaterialRequestPage extends StatefulWidget {
  const MaterialRequestPage({super.key});

  @override
  State<MaterialRequestPage> createState() => _MaterialRequestPageState();
}

class _MaterialRequestPageState extends State<MaterialRequestPage> {
  final TextEditingController reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime? scheduleDate;
  Warehouse? selectedWarehouse;
  Future? _pendingRequest;
  List<Item> availableItems = [];
  List<Warehouse> availableWarehouses = [];
  final Color primaryColor = const Color(0xFFBDB395);
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = const Color(0xFFF6F0F0);
  final Color pressedColor = const Color(0xFFF2E2B1);
  List<Map<String, dynamic>> itemsTable = [];
  final List<String> requestReasons = [
    'Purchase',
    'Material Transfer',
    'Material Issue',
    'Manufacture',
    'Customer Provided',
  ];
  String? selectedReason;

  @override
  void initState() {
    super.initState();
    _pendingRequest = _loadData();
  }

  @override
  void dispose() {
    _pendingRequest?.ignore();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final items = await ItemService.getItems();
      final warehouses = await WarehouseService.getWarehouses();

      if (!mounted) return;

      setState(() {
        availableItems = items;
        availableWarehouses = warehouses;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحميل البيانات: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addItemRow() {
    setState(() {
      itemsTable.add({'item': null, 'qty': 1});
    });
  }

  void _saveMaterialRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (scheduleDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد تاريخ الطلب'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedWarehouse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد المخزن المستهدف'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (itemsTable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إضافة أصناف على الأقل'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final request = MaterialRequest(
        reason: selectedReason.toString(),
        scheduleDate: scheduleDate!.toIso8601String(),
        warehouse: selectedWarehouse!.name,
        items:
            itemsTable.map((e) {
              final item = e['item'] as Item;
              return MaterialRequestItem(
                itemCode: item.itemName,
                qty: e['qty'],
                itemName: '',
                uom: '',
              );
            }).toList(),
        name: '',
      );

      await MaterialRequestService.submitMaterialRequest(request);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب المواد بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء الإرسال: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب مواد'),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(25),
            bottomLeft: Radius.circular(25),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'معلومات الطلب الأساسية',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedReason,
                          items:
                              requestReasons.map((reason) {
                                return DropdownMenuItem(
                                  value: reason,
                                  child: Text(reason),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedReason = value;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'سبب الطلب',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            prefixIcon: const Icon(Icons.receipt),
                          ),
                          validator:
                              (value) =>
                                  value == null ? 'يرجى اختيار سبب' : null,
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 1),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null) {
                              setState(() {
                                scheduleDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'تاريخ المطلوب',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              prefixIcon: const Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              scheduleDate == null
                                  ? 'اختر التاريخ'
                                  : scheduleDate!.toLocal().toString().split(
                                    ' ',
                                  )[0],
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<Warehouse>(
                          value: selectedWarehouse,
                          items:
                              availableWarehouses.map((w) {
                                return DropdownMenuItem(
                                  value: w,
                                  child: Text(w.name),
                                );
                              }).toList(),
                          onChanged:
                              (val) => setState(() => selectedWarehouse = val),
                          decoration: InputDecoration(
                            labelText: 'المخزن المستهدف',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            prefixIcon: const Icon(Icons.warehouse),
                          ),
                          validator:
                              (value) =>
                                  value == null ? 'يرجى اختيار مخزن' : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الأصناف المطلوبة',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add_circle, color: primaryColor),
                              onPressed: _addItemRow,
                              tooltip: 'إضافة صنف',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (itemsTable.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'لا توجد أصناف مضافة',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ...itemsTable.asMap().entries.map((entry) {
                          int index = entry.key;
                          var row = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Card(
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: DropdownButtonFormField<Item>(
                                        value: row['item'],
                                        hint: const Text('اختر صنف'),
                                        isExpanded: true,
                                        items:
                                            availableItems.map((item) {
                                              return DropdownMenuItem(
                                                value: item,
                                                child: Text(item.itemName),
                                              );
                                            }).toList(),
                                        onChanged: (item) {
                                          setState(() {
                                            itemsTable[index]['item'] = item;
                                          });
                                        },
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey[50],
                                        ),
                                        validator:
                                            (value) =>
                                                value == null
                                                    ? 'يرجى اختيار صنف'
                                                    : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 1,
                                      child: TextFormField(
                                        initialValue: row['qty'].toString(),
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'الكمية',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey[50],
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'مطلوب';
                                          }
                                          if (int.tryParse(value) == null ||
                                              int.parse(value) <= 0) {
                                            return 'كمية غير صالحة';
                                          }
                                          return null;
                                        },
                                        onChanged: (val) {
                                          setState(() {
                                            itemsTable[index]['qty'] =
                                                int.tryParse(val) ?? 1;
                                          });
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          itemsTable.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saveMaterialRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 247, 249, 250),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: primaryColor, width: 2.0),
                    ),
                  ),
                  child: Text(
                    'حفظ الطلب',
                    style: TextStyle(fontSize: 18, color: primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
