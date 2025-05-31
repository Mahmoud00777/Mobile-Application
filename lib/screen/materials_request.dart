import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item.dart';
import '../models/materials_requestM.dart';
import '../models/warehouse.dart';
import '../services/item_service.dart';
import '../services/materials_service.dart';

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

  List<Map<String, dynamic>> cartItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 1. جلب الأصناف
      final items = await ItemService.getItems(
        priceList: 'البيع القياسية',
        includePrices: false,
        includeStock: false,
        includeUOMs: true,
      );

      // 2. جلب بيانات ملف البيع
      final prefs = await SharedPreferences.getInstance();
      final posProfileJson = prefs.getString('selected_pos_profile');

      if (posProfileJson == null) {
        throw Exception('لم يتم تحديد ملف بيع');
      }

      final posProfile = json.decode(posProfileJson) as Map<String, dynamic>;
      final warehouseName = posProfile['warehouse'] as String?;

      if (warehouseName == null || warehouseName.isEmpty) {
        throw Exception('لا يوجد مخزن محدد في ملف البيع');
      }

      // 3. إنشاء كائن المخزن (بدون جلب كل المخازن)
      final warehouse = Warehouse(name: warehouseName);

      if (!mounted) return;

      setState(() {
        availableItems = items;
        availableWarehouses = [warehouse]; // قائمة تحتوي على المخزن الوحيد
        selectedWarehouse = warehouse;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحميل البيانات: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );

      // إعادة تعيين القيم في حالة الخطأ
      setState(() {
        availableItems = [];
        availableWarehouses = [];
        selectedWarehouse = null;
      });
    }
  }

  void _addToSelectedItems(Item product) {
    setState(() {
      final existingIndex = selectedItems.indexWhere(
        (Item) => Item['item_name'] == product.itemName,
      );

      if (existingIndex >= 0) {
        selectedItems[existingIndex]['quantity'] += 1;
      } else {
        selectedItems.add({
          'name': product.name,
          'item_name': product.itemName,
          'price': product.rate,
          'quantity': 1,
          'uom': product.uom,
          'additionalUOMs': product.additionalUOMs,
          'discount_amount': product.discount_amount,
          'discount_percentage': product.discount_percentage,
        });
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
    print(selectedItems);
    try {
      final request = MaterialRequest(
        reason: selectedReason,
        scheduleDate: scheduleDate!.toIso8601String(),
        warehouse: selectedWarehouse!.name,
        items:
            selectedItems
                .where(
                  (e) => e['item'] != null,
                ) // تصفية العناصر التي تحتوي على item غير null
                .map((e) {
                  final item = e['item'] as Item; // الآن نضمن أن item ليس null
                  return MaterialRequestItem(
                    itemCode: item.name,
                    qty: (e['quantity'] as int?) ?? 1, // تحقق من وجود الكمية
                    itemName: item.itemName,
                    uom:
                        (e['uom'] as String?) ??
                        item.uom, // استخدم الوحدة المعدلة أو الأصلية
                    rate: (e['rate'] as num?)?.toDouble() ?? item.rate ?? 0.0,
                  );
                })
                .toList(),
        name: '',
        transactionDate: '',
        status: '',
      );

      await MaterialRequestService.submitMaterialRequest(
        request,
        selectedItems,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب المواد بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      print(e);
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
                    ? const Center(
                      child: Text(
                        'لا توجد أصناف مضافة',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                    : ListView.builder(
                      controller: scrollController,
                      itemCount: selectedItems.length,
                      itemBuilder: (context, index) {
                        final item = selectedItems[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          elevation: 2,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showItemDetails(context, item, index),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: primaryColor.withOpacity(
                                    0.2,
                                  ),
                                  child: Text(
                                    '${item['quantity']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                                title: Text('${item['item_name']}'),
                                subtitle: Text('${item['uom']}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // زر التنقيص
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          if (item['quantity'] > 1) {
                                            selectedItems[index]['quantity']--;
                                          } else {
                                            _removeItem(
                                              index,
                                            ); // حذف العنصر إذا كانت الكمية = 1
                                          }
                                        });
                                      },
                                    ),

                                    // عرض الكمية
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        '${item['quantity']}',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),

                                    // زر الزيادة
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          selectedItems[index]['quantity']++;
                                        });
                                      },
                                    ),

                                    // زر الحذف
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _removeItem(index),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
            children: [_buildRequestInfoCard(), _buildAvailableItemsSection()],
          ),

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

  Future<void> _showItemDetails(
    BuildContext context,
    dynamic item,
    int index,
  ) async {
    if (index < 0 || index >= selectedItems.length) return;

    final itemData = selectedItems[index];
    final TextEditingController quantityController = TextEditingController(
      text: itemData['quantity'].toString(),
    );

    // تحديد الوحدات المتاحة
    Set<String> availableUnits = {item['uom'] ?? 'وحدة'};
    if (itemData['additionalUOMs'] != null) {
      availableUnits.addAll(
        (itemData['additionalUOMs'] as List)
            .where((uom) => uom['uom'] != null)
            .map((uom) => uom['uom'].toString()),
      );
    }
    String updatedUnit = itemData['uom'] ?? itemData['item'].uom;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        // استخدام StatefulBuilder لإدارة حالة الوحدة المحددة
        String currentSelectedUnit = itemData['uom'] ?? itemData['item'].uom;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'تفاصيل الصنف',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),

                    // معلومات الصنف الأساسية
                    _buildDetailRow('الاسم:', itemData['item_name']),
                    _buildDetailRow('الوحدة الحالية:', itemData['uom']),

                    // حقل الكمية
                    TextFormField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الكمية',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.format_list_numbered),
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: currentSelectedUnit,
                      items:
                          availableUnits.map((unit) {
                            return DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit),
                            );
                          }).toList(),
                      onChanged: (newUnit) {
                        setModalState(() {
                          updatedUnit = newUnit!;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'تغيير الوحدة',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.scale),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // أزرار الحفظ والإلغاء
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                            ),
                            onPressed: () {
                              // التحقق من صحة البيانات قبل الحفظ
                              final quantity =
                                  int.tryParse(quantityController.text) ?? 0;
                              if (quantity <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'الكمية يجب أن تكون أكبر من الصفر',
                                    ),
                                  ),
                                );
                                return;
                              }
                              print('the new unit =>$currentSelectedUnit');
                              // حفظ التعديلات
                              setState(() {
                                selectedItems[index]['quantity'] = quantity;
                                selectedItems[index]['uom'] = updatedUnit;
                                selectedItems[index] = {
                                  ...selectedItems[index],
                                  'quantity': quantity,
                                  'uom': updatedUnit,
                                };
                              });
                              print(
                                'بعد التعديل - الوحدة: ${selectedItems[index]['uom']}',
                              );
                              Navigator.pop(context);
                            },
                            child: const Text('حفظ التغييرات'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  String _formatCurrency(dynamic amount) {
    try {
      final num parsedAmount =
          amount is String ? double.tryParse(amount) ?? 0 : (amount as num);
      return NumberFormat.currency(
        symbol: "د.ل",
        decimalDigits: 0,
        locale: 'ar_LY',
      ).format(parsedAmount);
    } catch (e) {
      print('Error formatting currency: $e');
      return 'د.ل‏ 0.00';
    }
  }

  // Widget _buildDetailRow(String label, String value) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 8),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         SizedBox(
  //           width: 80,
  //           child: Text(
  //             label,
  //             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
  //           ),
  //         ),
  //         Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
  //       ],
  //     ),
  //   );
  // }
}
