import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item.dart';
import '../models/materials_requestM.dart';
import '../models/warehouse.dart';
import '../services/item_service.dart';
import '../services/materials_service.dart';
import '../services/warehouse_service.dart';

class MaterialRequestPage extends StatefulWidget {
  const MaterialRequestPage({super.key});

  @override
  State<MaterialRequestPage> createState() => _MaterialRequestPageState();
}

class _MaterialRequestPageState extends State<MaterialRequestPage> {
  final _formKey = GlobalKey<FormState>();
  DateTime? scheduleDate;
  Warehouse? selectedWarehouse;
  List<Item> availableItems = [];
  List<Warehouse> availableWarehouses = [];
  final Color primaryColor = const Color(0xFFBDB395);
  List<Map<String, dynamic>> selectedItems = [];
  final List<String> requestReasons = [
    'Purchase',
    'Material Transfer',
    'Material Issue',
    'Manufacture',
    'Customer Provided',
  ];
  String selectedReason = 'Material Transfer';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final items = await ItemService.getItems();
      final warehouses = await WarehouseService.getWarehouses();
      final prefs = await SharedPreferences.getInstance();
      final posProfileJson = prefs.getString('selected_pos_profile');
      final posProfile = json.decode(posProfileJson!);
      final String warehouseName = posProfile['warehouse'];
      final warehouse = warehouses.firstWhere(
        (w) => w.name == warehouseName,
        orElse: () => Warehouse(name: warehouseName),
      );

      if (!mounted) return;

      setState(() {
        availableItems = items;
        availableWarehouses = [warehouse];
        selectedWarehouse = warehouse;
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

  void _addToSelectedItems(Item item) {
    setState(() {
      final existingIndex = selectedItems.indexWhere(
        (element) => (element['item'] as Item).name == item.name,
      );

      if (existingIndex >= 0) {
        selectedItems[existingIndex]['quantity'] += 1;
      } else {
        selectedItems.add({'item': item, 'quantity': 1});
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      selectedItems.removeAt(index);
    });
  }

  void _increaseQuantity(int index) {
    setState(() {
      selectedItems[index]['quantity'] += 1;
    });
  }

  void _decreaseQuantity(int index) {
    setState(() {
      if (selectedItems[index]['quantity'] > 1) {
        selectedItems[index]['quantity'] -= 1;
      }
    });
  }

  void _clearItems() {
    setState(() {
      selectedItems.clear();
    });
  }

  void _saveMaterialRequest() async {
    // if (!_formKey.currentState!.validate()) return;

    if (scheduleDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد تاريخ الطلب'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedItems.isEmpty) {
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
        reason: selectedReason,
        scheduleDate: scheduleDate!.toIso8601String(),
        warehouse: selectedWarehouse!.name,
        items:
            selectedItems.map((e) {
              final item = e['item'] as Item;
              return MaterialRequestItem(
                itemCode: item.name,
                qty: e['quantity'],
                itemName: item.itemName,
                uom: item.uom,
                rate: item.rate ?? 0.0,
              );
            }).toList(),
        name: '',
        transactionDate: '',
        status: '',
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

  Widget _buildRequestInfoCard() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primaryColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            AbsorbPointer(
              absorbing: true,
              child: DropdownButtonFormField<String>(
                value: selectedReason,
                items:
                    requestReasons.map((reason) {
                      return DropdownMenuItem(
                        value: reason,
                        child: Text(reason),
                      );
                    }).toList(),
                onChanged: (value) {},
                decoration: InputDecoration(
                  labelText: 'سبب الطلب',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  prefixIcon: const Icon(Icons.receipt),
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => scheduleDate = picked);
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
                      : '${scheduleDate!.day}/${scheduleDate!.month}/${scheduleDate!.year}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AbsorbPointer(
              absorbing: true,
              child: DropdownButtonFormField<Warehouse>(
                value: selectedWarehouse,
                items:
                    availableWarehouses.map((w) {
                      return DropdownMenuItem(value: w, child: Text(w.name));
                    }).toList(),
                onChanged: null,
                decoration: InputDecoration(
                  labelText: 'المخزن المستهدف',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                  prefixIcon: const Icon(Icons.warehouse),
                  suffixIcon: const Icon(Icons.lock),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableItemsSection() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'الأصناف المتاحة:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: availableItems.length,
                itemBuilder: (context, index) {
                  final item = availableItems[index];
                  return _buildItemCard(item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Item item) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _addToSelectedItems(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.itemName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text('الكود: ${item.name}', style: const TextStyle(fontSize: 12)),
              Text('الوحدة: ${item.uom}', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedItemsSheet(
    BuildContext context,
    ScrollController scrollController,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [
          // الشريط العلوي لسحب السلة
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'سلة الطلبات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${selectedItems.length} أصناف',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child:
                selectedItems.isEmpty
                    ? const Center(child: Text('لا توجد أصناف مضافة'))
                    : ListView.builder(
                      controller: scrollController,
                      itemCount: selectedItems.length,
                      itemBuilder: (context, index) {
                        final item = selectedItems[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primaryColor.withOpacity(0.2),
                            child: Text('${item['quantity']}'),
                          ),
                          title: Text(item['item'].itemName),
                          subtitle: Text(item['item'].uom),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeItem(index),
                          ),
                        );
                      },
                    ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: selectedItems.isEmpty ? null : _saveMaterialRequest,
              child: const Text(
                'تأكيد الطلب',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب مواد جديد'),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // معلومات الطلب الأساسية
              _buildRequestInfoCard(),

              // الأصناف المتاحة كبطاقات
              _buildAvailableItemsSection(),
            ],
          ),

          // سلة الطلبات كـ DraggableScrollableSheet
          DraggableScrollableSheet(
            initialChildSize: 0.25,
            minChildSize: 0.1,
            maxChildSize: 0.7,
            builder: (context, scrollController) {
              return _buildSelectedItemsSheet(context, scrollController);
            },
          ),
        ],
      ),
    );
  }
}
