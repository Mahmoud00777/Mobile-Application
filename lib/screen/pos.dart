import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sales_invoice.dart';
import '../services/item_service.dart';
import '../services/customer_service.dart';
import '../models/item.dart';
import '../models/customer.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  _POSScreenState createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  List<Map<String, dynamic>> cartItems = [];
  double total = 0.0;
  Customer? selectedCustomer;
  bool isLoading = true;
  String errorMessage = '';
  Timer? _loadingTimer;
  bool isFirstLoad = true;
  List<Item> products = [];
  List<Item> filteredProducts = [];
  List<Customer> customers = [];
  List<String> itemGroups = [];
  String? selectedItemGroup;
  TextEditingController searchController = TextEditingController();
  final Color primaryColor = const Color(0xFFBDB395);
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = const Color(0xFFF6F0F0);
  final Color pressedColor = const Color(0xFFF2E2B1);

  @override
  void initState() {
    super.initState();
    _initializeData();
    searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    _loadingTimer = Timer(const Duration(seconds: 2), () {
      if (isFirstLoad) {
        setState(() => isFirstLoad = false);
      }
    });

    try {
      final results = await Future.wait([
        _loadProducts(),
        _loadCustomers(),
        _loadPosProfile(),
      ]);

      setState(() {
        products = results[0] as List<Item>;
        filteredProducts = products;
        customers = results[1] as List<Customer>;
        selectedCustomer = results[2] as Customer?;
        isLoading = false;
        isFirstLoad = false;
      });
    } catch (e) {
      _handleError(e);
    } finally {
      _loadingTimer?.cancel();
    }
  }

  Future<List<Item>> _loadProducts() async {
    final items = await ItemService.getItems();
    itemGroups = await ItemService.getItemGroups();
    return items;
  }

  Future<List<Customer>> _loadCustomers() async {
    return await CustomerService.getCustomers();
  }

  Future<Customer?> _loadPosProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final posProfileJson = prefs.getString('selected_pos_profile');
    if (posProfileJson == null) return null;

    final posProfile = json.decode(posProfileJson);
    return Customer(
      name: posProfile['customer'],
      customerName: posProfile['customer'],
      customerGroup: '',
    );
  }

  void _handleError(dynamic error) {
    setState(() {
      isLoading = false;
      errorMessage =
          error is SocketException
              ? 'تحقق من اتصال الإنترنت'
              : error is TimeoutException
              ? 'استغرقت العملية وقتًا أطول من المتوقع'
              : 'حدث خطأ في تحميل البيانات';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
    );
  }

  void _filterProducts() {
    final searchTerm = searchController.text.toLowerCase();

    setState(() {
      filteredProducts =
          products.where((product) {
            final matchesSearch =
                product.itemName.toLowerCase().contains(searchTerm) ||
                product.name.toLowerCase().contains(searchTerm);
            final matchesGroup =
                selectedItemGroup == null ||
                selectedItemGroup!.isEmpty ||
                product.itemGroup == selectedItemGroup;

            return matchesSearch && matchesGroup;
          }).toList();
    });
  }

  void _increaseQuantity(int index) {
    setState(() {
      cartItems[index]['quantity'] += 1;
      total += cartItems[index]['price'];
    });
  }

  void _decreaseQuantity(int index) {
    setState(() {
      if (cartItems[index]['quantity'] > 1) {
        cartItems[index]['quantity'] -= 1;
        total -= cartItems[index]['price'];
      } else {
        total -= cartItems[index]['price'];
        cartItems.removeAt(index);
      }
    });
  }

  void addToCart(Item product) {
    setState(() {
      // البحث باستخدام item_name بدلاً من name
      final existingIndex = cartItems.indexWhere(
        (item) => item['item_name'] == product.itemName,
      );

      if (existingIndex != -1) {
        // إذا وجدنا العنصر، نزيد الكمية
        cartItems[existingIndex]['quantity'] += 1;
      } else {
        // إذا لم نجده، نضيف عنصر جديد
        cartItems.add({
          'name': product.name,
          'item_name': product.itemName,
          'price': product.rate,
          'quantity': 1,
        });
      }
      // تحديث الإجمالي
      total += product.rate;
    });
  }

  void removeFromCart(int index) {
    setState(() {
      total -= cartItems[index]['price'] * cartItems[index]['quantity'];
      cartItems.removeAt(index);
    });
  }

  void clearCart() {
    setState(() {
      cartItems.clear();
      total = 0.0;
      selectedCustomer = null;
    });
  }

  Future<void> _processPayment(BuildContext context) async {
    if (selectedCustomer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('الرجاء اختيار عميل أولاً')));
      return;
    }

    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('السلة فارغة')));
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final posProfileJson = prefs.getString('selected_pos_profile');

      if (posProfileJson == null || posProfileJson.isEmpty) {
        throw Exception('لم يتم تحديد إعدادات نقطة البيع (POS Profile)');
      }
      final posProfile = json.decode(posProfileJson);

      final paymentMethods = List<Map<String, dynamic>>.from(
        posProfile['payments'] ?? [],
      );

      if (paymentMethods.isEmpty) {
        throw Exception('لا توجد طرق دفع متاحة');
      }

      final paymentResult = await _showPaymentDialog(
        context,
        paymentMethods,
        total,
      );

      if (paymentResult != null) {
        await _completeSale(paymentResult);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ: ${e.toString()}')));
    }
  }

  Future<void> _completeSale(Map<String, dynamic> paymentData) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      final double paidAmount = paymentData['paid_amount'];
      final double outstanding = paymentData['outstanding_amount'];

      final invoiceResult = await SalesInvoice.createSalesInvoice(
        customer: selectedCustomer!,
        items: cartItems,
        total: total,
        paymentMethod: paymentData,
        paidAmount: paidAmount,
        outstandingAmount: outstanding,
      );

      if (!invoiceResult['success']) {
        throw Exception(invoiceResult['error']);
      }

      Navigator.pop(context);

      setState(() {
        cartItems.clear();
        total = 0.0;
      });
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل في إتمام البيع: ${e.toString()}')),
      );
    }
  }

  Future<Map<String, dynamic>?> _showPaymentDialog(
    BuildContext context,
    List<Map<String, dynamic>> paymentMethods,
    double invoiceTotal,
  ) async {
    String selectedMethod = paymentMethods.first['mode_of_payment'];
    TextEditingController amountController = TextEditingController(
      text: invoiceTotal.toStringAsFixed(2),
    );
    double paidAmount = invoiceTotal;

    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('إتمام عملية الدفع'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedMethod,
                      items:
                          paymentMethods.map((method) {
                            return DropdownMenuItem<String>(
                              value: method['mode_of_payment'],
                              child: Text(method['mode_of_payment']),
                            );
                          }).toList(),
                      onChanged: (value) => selectedMethod = value!,
                      decoration: InputDecoration(labelText: 'طريقة الدفع'),
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'المبلغ المدفوع',
                        suffixText: 'ر.س',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          paidAmount = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                    SizedBox(height: 20),
                    Text(
                      'إجمالي الفاتورة: ${invoiceTotal.toStringAsFixed(2)} ر.س',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'المتبقي: ${(invoiceTotal - paidAmount).toStringAsFixed(2)} ر.س',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () {
                    if (amountController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('الرجاء إدخال مبلغ الدفع')),
                      );
                      return;
                    }

                    final paid = double.tryParse(amountController.text) ?? 0.0;
                    if (paid <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('المبلغ يجب أن يكون أكبر من الصفر'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context, {
                      'mode_of_payment': selectedMethod,
                      'paid_amount': paid,
                      'outstanding_amount': invoiceTotal - paid,
                    });
                  },
                  child: Text('تأكيد الدفع'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCustomerInfoBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: primaryColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline, color: primaryColor),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              selectedCustomer?.customerName ?? 'لم يتم اختيار عميل',
              style: TextStyle(fontSize: 16),
            ),
          ),
          FilledButton.tonal(
            onPressed: () => _showCustomerDialog(),
            style: FilledButton.styleFrom(backgroundColor: primaryColor),
            child: Text(
              selectedCustomer == null ? 'اختيار عميل' : 'تغيير',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          if (selectedCustomer == null)
            IconButton(
              icon: Icon(Icons.add, color: Colors.green),
              onPressed: _addNewCustomer,
            ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          SearchBar(
            controller: searchController,
            hintText: 'ابحث عن منتج...',
            leading: Icon(Icons.search),
          ),

          SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedItemGroup,
                  decoration: InputDecoration(
                    labelText: 'تصفية حسب المجموعة',
                    labelStyle: TextStyle(color: primaryColor),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: primaryColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: primaryColor),
                    ),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text('كل المجموعات')),
                    ...itemGroups.map((group) {
                      return DropdownMenuItem(value: group, child: Text(group));
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedItemGroup = value;
                      _filterProducts();
                    });
                  },
                ),
              ),

              SizedBox(width: 8),

              IconButton(
                icon: Icon(Icons.refresh),
                tooltip: 'إعادة تعيين الفلترة',
                onPressed: () {
                  setState(() {
                    selectedItemGroup = null;
                    searchController.clear();
                    filteredProducts = products;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartSection() {
    return Card(
      margin: EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: primaryColor, width: 1.0),
      ),
      elevation: 2,
      child: Column(
        children: [
          // Header يبقى كما هو
          Container(
            padding: EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'سلة المشتريات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${total.toStringAsFixed(0)} LYD',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // قائمة العناصر المعدلة
          Expanded(
            child:
                cartItems.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'لا توجد عناصر في السلة',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: EdgeInsets.only(top: 8),
                      itemCount: cartItems.length,
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        return InkWell(
                          onTap: () => _showEditItemDialog(context, index),
                          child: Container(
                            margin: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue[100],
                                child: Text(
                                  '${item['quantity']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              ),
                              title: Expanded(
                                flex: 4, // 40%
                                child: Text(
                                  item['item_name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: const Color.fromARGB(
                                      255,
                                      17,
                                      17,
                                      17,
                                    ),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                              subtitle: Text(
                                '${item['price'].toStringAsFixed(0)} LYD',
                                style: TextStyle(fontSize: 12),
                              ),
                              trailing: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.4,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${(item['price'] * item['quantity']).toStringAsFixed(0)} LYD',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    // زر الحذف
                                    Material(
                                      color: Colors.grey[200],
                                      shape: CircleBorder(),
                                      elevation: 1,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () => removeFromCart(index),
                                        child: Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    // أزرار التحكم في الكمية
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // زر النقصان
                                        Material(
                                          color: Colors.red[100],
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          elevation: 1,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            onTap:
                                                () => _decreaseQuantity(index),
                                            child: Container(
                                              width: 30,
                                              height: 24,
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons.remove,
                                                size: 16,
                                                color: Colors.red[800],
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        // زر الزيادة
                                        Material(
                                          color: Colors.green[100],
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          elevation: 1,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            onTap:
                                                () => _increaseQuantity(index),
                                            child: Container(
                                              width: 30,
                                              height: 24,
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons.add,
                                                size: 16,
                                                color: Colors.green[800],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
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

          // Footer يبقى كما هو
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: clearCart,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'إفراغ السلة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xffffffff),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _processPayment(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment, size: 20, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'إتمام البيع',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xffffffff),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditItemDialog(BuildContext context, int index) async {
    final item = cartItems[index];
    final TextEditingController quantityController = TextEditingController(
      text: item['quantity'].toString(),
    );
    String? selectedUnit =
        item['unit'] ?? 'وحدة'; // يمكنك استبدالها بقائمة الوحدات الفعلية

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('تعديل العنصر'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'الكمية',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedUnit,
                items:
                    ['وحدة', 'كيلو', 'جرام', 'لتر', 'علبة'].map((String unit) {
                      return DropdownMenuItem<String>(
                        value: unit,
                        child: Text(unit),
                      );
                    }).toList(),
                onChanged: (value) {
                  selectedUnit = value;
                },
                decoration: InputDecoration(
                  labelText: 'الوحدة',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final newQuantity = int.tryParse(quantityController.text) ?? 1;
                if (newQuantity > 0) {
                  setState(() {
                    // تحديث الكمية والوحدة
                    cartItems[index]['quantity'] = newQuantity;
                    cartItems[index]['unit'] = selectedUnit;

                    // إعادة حساب الإجمالي
                    total = cartItems.fold(0.0, (sum, item) {
                      return sum + (item['price'] * item['quantity']);
                    });
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('الكمية يجب أن تكون أكبر من الصفر')),
                  );
                }
              },
              child: Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCustomerDialog() async {
    final customer = await showDialog<Customer>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('اختر عميل'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: customers.length,
                itemBuilder: (context, index) {
                  final customer = customers[index];
                  return ListTile(
                    leading: Icon(
                      customer.name == 'CASH' ? Icons.money : Icons.person,
                      color:
                          customer.name == 'CASH' ? Colors.green : Colors.blue,
                    ),
                    title: Text(customer.customerName),
                    subtitle:
                        customer.name == 'CASH'
                            ? null
                            : Text(customer.customerGroup),
                    onTap: () => Navigator.pop(context, customer),
                  );
                },
              ),
            ),
          ),
    );

    if (customer != null) {
      setState(() => selectedCustomer = customer);
    }
  }

  void _addNewCustomer() {}

  void _showSettings(BuildContext context) {}

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return Center(child: Text(errorMessage));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('نقطة البيع', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: primaryColor,
        // actions: [
        //   IconButton(icon: Icon(Icons.refresh), onPressed: _initializeData),
        //   IconButton(
        //     icon: Icon(Icons.settings),
        //     onPressed: () => _showSettings(context),
        //   ),
        // ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(25),
            bottomLeft: Radius.circular(25),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildCustomerInfoBar(),
          _buildFilterSection(),
          Expanded(
            flex: 4,
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              padding: EdgeInsets.all(8),
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                return ProductCard(
                  product: filteredProducts[index],
                  onTap: () => addToCart(filteredProducts[index]),
                );
              },
            ),
          ),
          Expanded(flex: 6, child: _buildCartSection()),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Item product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  final Color primaryColor = const Color(0xFFBDB395);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_bag, size: 40, color: primaryColor),
              SizedBox(height: 8),
              Flexible(
                child: Text(
                  product.itemName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                '${product.rate.toStringAsFixed(0)} LYD',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              if (product.itemGroup.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    product.itemGroup,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
