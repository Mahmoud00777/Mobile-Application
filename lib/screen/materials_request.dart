import 'dart:convert';
import 'package:flutter/material.dart';
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
  List<Map<String, dynamic>> selectedItems = [];
  bool isLoading = true;
  String errorMessage = '';
  final Color primaryColor = Color(0xFF60B245);
  final Color secondaryColor = Color(0xFFFFFFFF);
  final Color backgroundColor = Color(0xFFF2F2F2);
  final Color blackColor = Color(0xFF383838);

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
      final items = await ItemService.getItems(
        priceList: 'البيع القياسية',
        includePrices: false,
        includeStock: false,
        includeUOMs: true,
      );

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

      final warehouse = Warehouse(name: warehouseName);

      if (!mounted) return;

      setState(() {
        availableItems = items;
        availableWarehouses = [warehouse];
        selectedWarehouse = warehouse;
        isLoading = false;
        errorMessage = '';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        availableItems = [];
        availableWarehouses = [];
        selectedWarehouse = null;
        isLoading = false;
        errorMessage = 'خطأ في تحميل البيانات: ${e.toString()}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحميل البيانات: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
            selectedItems.where((e) => e['item'] != null).map((e) {
              final item = e['item'] as Item;
              return MaterialRequestItem(
                itemCode: item.name,
                qty: (e['quantity'] as int?) ?? 1,
                itemName: item.itemName,
                uom: (e['uom'] as String?) ?? item.uom,
                rate: (e['rate'] as num?)?.toDouble() ?? item.rate ?? 0.0,
              );
            }).toList(),
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
    return SafeArea(
      child: Card(
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
      child: SafeArea(
        child: Column(
          children: [
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
                          return SafeArea(
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              elevation: 2,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap:
                                    () =>
                                        _showItemDetails(context, item, index),
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
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              if (item['quantity'] > 1) {
                                                selectedItems[index]['quantity']--;
                                              } else {
                                                _removeItem(index);
                                              }
                                            });
                                          },
                                        ),

                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          child: Text(
                                            '${item['quantity']}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),

                                        IconButton(
                                          icon: const Icon(Icons.add, size: 20),
                                          onPressed: () {
                                            setState(() {
                                              selectedItems[index]['quantity']++;
                                            });
                                          },
                                        ),

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
                            ),
                          );
                        },
                      ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed:
                      selectedItems.isEmpty ? null : _saveMaterialRequest,
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
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('طلب مواد جديد'),
          centerTitle: true,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: _buildLoadingScreen(),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('طلب مواد جديد'),
          centerTitle: true,
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                errorMessage,
                style: TextStyle(fontSize: 16, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                    errorMessage = '';
                  });
                  _loadData();
                },
                child: Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب مواد جديد'),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.article_outlined),
            tooltip: 'معلومات الطلب',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder:
                    (context) => Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: DraggableScrollableSheet(
                        expand: false,
                        maxChildSize: 0.9,
                        minChildSize: 0.4,
                        builder:
                            (_, controller) => SingleChildScrollView(
                              controller: controller,
                              child: _buildRequestInfoCard(),
                            ),
                      ),
                    ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(children: [_buildAvailableItemsSection()]),
          DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.3,
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
                    _buildDetailRow('الاسم:', itemData['item_name']),
                    _buildDetailRow('الوحدة الحالية:', itemData['uom']),
                    TextFormField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الكمية',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        final qty = int.tryParse(val) ?? 1;
                        setModalState(() {
                          selectedItems[index]['quantity'] = qty > 0 ? qty : 1;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: currentSelectedUnit,
                      items:
                          availableUnits
                              .map(
                                (unit) => DropdownMenuItem<String>(
                                  value: unit,
                                  child: Text(unit),
                                ),
                              )
                              .toList(),
                      onChanged: (newUnit) {
                        setModalState(() {
                          currentSelectedUnit = newUnit!;
                          selectedItems[index]['uom'] = newUnit;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'تغيير الوحدة',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {});
                        },
                        child: const Text('حفظ'),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value ?? '',
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Column(
      children: [
        Card(
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
                Container(
                  height: 20,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 20,
                  width: 150,
                  margin: EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      return _buildItemSkeleton();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        Container(
          height: MediaQuery.of(context).size.height * 0.35,
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
              Container(
                height: 60,
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      height: 20,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 20,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    return _buildSelectedItemSkeleton();
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemSkeleton() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 16,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 12,
              width: 80,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 12,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedItemSkeleton() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            shape: BoxShape.circle,
          ),
        ),
        title: Container(
          height: 14,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        subtitle: Container(
          height: 12,
          width: 120,
          margin: EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        trailing: SizedBox(
          width: MediaQuery.of(context).size.width * 0.4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                height: 14,
                width: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  SizedBox(height: 4),
                  Container(
                    width: 30,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
