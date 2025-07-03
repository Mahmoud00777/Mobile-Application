import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:drsaf/Class/message_service.dart';
import 'package:drsaf/services/api_client.dart';
import 'package:drsaf/services/visit_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sales_invoice.dart';
import '../services/item_service.dart';
import '../services/customer_service.dart';
import '../models/item.dart';
import '../models/customer.dart';

class POSReturnScreen extends StatefulWidget {
  const POSReturnScreen({super.key});

  @override
  _POSReturbScreenState createState() => _POSReturbScreenState();
}

class _POSReturbScreenState extends State<POSReturnScreen> {
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
  final Color primaryColor = Color(0xFFB6B09F);
  final Color secondaryColor = Color(0xFFEAE4D5);
  final Color backgroundColor = Color(0xFFF2F2F2);
  final Color blackColor = Color.fromARGB(255, 85, 84, 84);

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
        // selectedCustomer = results[2] as Customer?;
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
            final matchesSearch = product.itemName.toLowerCase().contains(
              searchTerm,
            );
            product.name.toLowerCase().contains(searchTerm);
            final matchesGroup = selectedItemGroup == null;
            selectedItemGroup!.isEmpty;
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
          'uom': product.uom,
          'additionalUOMs': product.additionalUOMs,
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
      print('paymentData-----------------${paymentData['paid_amount']}');
      final double outstanding = paymentData['outstanding_amount'];

      final invoiceResult = await SalesInvoice.createReturnSalesInvoice(
        customer: selectedCustomer!,
        items: cartItems,
        total: total,
        paymentMethod: paymentData,
        paidAmount: paidAmount,
        outstandingAmount: outstanding,
        notes: paymentData['notes'],
        attachedImages: paymentData['attached_images'],
      );

      if (!invoiceResult['success']) {
        final errorMessage = invoiceResult['success'] ?? 'حدث خطأ غير معروف';
        MessageService.showError(
          context,
          errorMessage,
          title: 'فشل في إنشاء الفاتورة ترجيع',
        );
        throw Exception(errorMessage);
      }

      if (!invoiceResult['result']['success']) {
        final errorMessage =
            invoiceResult['result']['error'] ?? 'حدث خطأ غير معروف';
        MessageService.showError(
          context,
          errorMessage,
          title: 'فشل في تأكيد الفاتورة ترجيع بعد انشائها ',
        );
        throw Exception(errorMessage);
      }

      Navigator.pop(context);
      MessageService.showSuccess(
        context,
        'تم حفظ الفاتورة ترجيع بنجاح ${invoiceResult['full_invoice']['name']}',
      );

      setState(() {
        cartItems.clear();
        total = 0.0;
      });
    } catch (e) {
      Navigator.pop(context);
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('فشل في إتمام البيع: ${e.toString()}')),
      // );
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
    TextEditingController notesController = TextEditingController();
    double paidAmount = invoiceTotal;
    List<File> attachedImages = []; // قائمة لحفظ الصور المرفوعة

    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> pickImages() async {
              final pickedFiles = await ImagePicker().pickMultiImage(
                maxWidth: 800,
                maxHeight: 800,
                imageQuality: 85,
              );
              setState(() {
                attachedImages.addAll(
                  pickedFiles.map((file) => File(file.path)),
                );
              });
            }

            Future<void> takePhoto() async {
              final pickedFile = await ImagePicker().pickImage(
                source: ImageSource.camera,
                maxWidth: 800,
                maxHeight: 800,
                imageQuality: 85,
              );
              if (pickedFile != null) {
                setState(() {
                  attachedImages.add(File(pickedFile.path));
                });
              }
            }

            return AlertDialog(
              title: Text('إتمام عملية الإرجاع'),
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
                        labelText: 'المبلغ المسترد',
                        suffixText: 'د.ر',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          paidAmount = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات الإرجاع',
                        border: OutlineInputBorder(),
                        hintText: 'سبب الإرجاع',
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          'إرفاق صور:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 10),
                        IconButton(
                          icon: Icon(Icons.photo_library, color: Colors.blue),
                          onPressed: pickImages,
                          tooltip: 'اختر من المعرض',
                        ),
                        IconButton(
                          icon: Icon(Icons.camera_alt, color: Colors.green),
                          onPressed: takePhoto,
                          tooltip: 'التقاط صورة',
                        ),
                      ],
                    ),
                    // if (attachedImages.isNotEmpty)
                    //   SizedBox(
                    //     height: 100,
                    //     child: ListView.builder(
                    //       scrollDirection: Axis.horizontal,
                    //       itemCount: attachedImages.length,
                    //       itemBuilder: (context, index) {
                    //         return Stack(
                    //           children: [
                    //             Container(
                    //               width: 100,
                    //               height: 100,
                    //               margin: EdgeInsets.only(right: 8),
                    //               decoration: BoxDecoration(
                    //                 borderRadius: BorderRadius.circular(8),
                    //                 image: DecorationImage(
                    //                   image: FileImage(attachedImages[index]),
                    //                   fit: BoxFit.cover,
                    //                 ),
                    //               ),
                    //             ),
                    //             Positioned(
                    //               top: 0,
                    //               right: 0,
                    //               child: IconButton(
                    //                 icon: Icon(
                    //                   Icons.close,
                    //                   size: 20,
                    //                   color: Colors.red,
                    //                 ),
                    //                 onPressed: () {
                    //                   setState(() {
                    //                     attachedImages.removeAt(index);
                    //                   });
                    //                 },
                    //               ),
                    //             ),
                    //           ],
                    //         );
                    //       },
                    //     ),
                    //   ),
                    if (attachedImages.isNotEmpty)
                      Container(
                        height: 100,
                        width: double.infinity, // Or a fixed width for testing
                        //color: Colors.amber, // Placeholder color
                        alignment: Alignment.center,
                        child: Text("Images: ${attachedImages.length}"),
                      ),
                    SizedBox(height: 20),
                    Text(
                      'إجمالي المبلغ المرتجع: ${invoiceTotal.toStringAsFixed(2)} د.ر',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'المستحق للعميل: ${(invoiceTotal - paidAmount).toStringAsFixed(2)} د.ر',
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
                  onPressed: () async {
                    if (amountController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('الرجاء إدخال المبلغ')),
                      );
                      return;
                    }
                    if (notesController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('الرجاء إدخال سبب الإرجاع')),
                      );
                      return;
                    }

                    final paid = double.tryParse(amountController.text) ?? 0.0;
                    final rounded = paid.roundToDouble();
                    if (rounded < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('المبلغ يجب أن يكون أكبر من الصفر'),
                        ),
                      );
                      return;
                    }

                    // رفع الصور إلى السيرفر والحصول على روابطها
                    List<String> imageUrls = [];
                    if (attachedImages.isNotEmpty) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder:
                            (context) =>
                                Center(child: CircularProgressIndicator()),
                      );

                      try {
                        for (var image in attachedImages) {
                          final url = await VisitService.uploadImage(image);
                          imageUrls.add(url);
                        }
                      } finally {
                        Navigator.pop(context);
                      }
                    }

                    Navigator.pop(context, {
                      'mode_of_payment': selectedMethod,
                      'paid_amount': rounded,
                      'outstanding_amount': invoiceTotal - rounded,
                      'notes': notesController.text,
                      'attached_images': imageUrls, // روابط الصور المرفوعة
                    });
                  },
                  child: Text('تأكيد الإرجاع'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  //البحث و مجموعة الصنف //
  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          // أيقونة البحث
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.search, color: primaryColor),
              tooltip: 'بحث عن منتج',
              onPressed: () {
                _showSearchDialog(); // فتح مربع البحث الكامل
              },
            ),
          ),

          SizedBox(width: 10),

          // Dropdown تصفية حسب المجموعة
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
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.search, color: primaryColor),
              SizedBox(width: 8),
              Text('ابحث عن منتج', style: TextStyle(color: primaryColor)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SearchBar(
                  controller: searchController,
                  hintText: 'ادخل اسم المنتج...',
                  leading: Icon(Icons.search),
                  onChanged: (value) {
                    _filterProducts(); // فلترة مباشرة أثناء الكتابة
                  },
                ),
                SizedBox(height: 10),
                // يمكن إضافة نتائج مباشرة هنا لاحقًا إن أردت
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: primaryColor),
              onPressed: () => Navigator.pop(context),
              child: Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  //---------------------------------------------//

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
          // Header
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
                  'سلة المرتجعات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${total.toStringAsFixed(2)} LYD',
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

          // قائمة العناصر مع تمرير Scroll داخل Expanded
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
                              // لا تستخدم Expanded هنا — فقط Text عادي
                              title: Text(
                                item['item_name'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color.fromARGB(255, 17, 17, 17),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${item['price'].toStringAsFixed(2)} LYD     ${item['uom']}',
                                style: TextStyle(fontSize: 12),
                              ),
                              trailing: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.4,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${(item['price'] * item['quantity']).toStringAsFixed(2)} LYD',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                    SizedBox(width: 8),
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
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
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

          // Footer
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
                            color: Colors.white,
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
                            color: Colors.white,
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

  //---------------------------------------------------//
  Future<void> _showEditItemDialog(BuildContext context, int index) async {
    final item = cartItems[index];
    final TextEditingController quantityController = TextEditingController(
      text: item['quantity'].toString(),
    );
    final TextEditingController priceController = TextEditingController(
      text: item['price'].toStringAsFixed(2),
    );

    // 1. البيانات الأساسية
    String selectedUnit = item['uom'] ?? item['stock_uom'] ?? 'وحدة';
    double currentPrice = item['price'];
    String itemCode = item['name']?.toString() ?? '';
    String priceList = 'البيع القياسية';

    // 2. قائمة الوحدات المتاحة
    Set<String> availableUnits = {item['stock_uom']?.toString() ?? 'وحدة'};
    if (item['additionalUOMs'] != null) {
      availableUnits.addAll(
        (item['additionalUOMs'] as List)
            .where((uom) => uom['uom'] != null)
            .map((uom) => uom['uom'].toString()),
      );
    }

    await showDialog(
      context: context,
      builder: (context) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> updatePriceForNewUnit(String? newUnit) async {
              if (newUnit == null || newUnit == selectedUnit) return;

              setStateDialog(() => isLoading = true);

              try {
                final newPrice = await _getItemPriceForUnit(
                  itemCode,
                  newUnit,
                  priceList,
                );

                if (context.mounted) {
                  setStateDialog(() {
                    selectedUnit = newUnit;
                    currentPrice = newPrice ?? currentPrice;
                    priceController.text = currentPrice.toStringAsFixed(2);
                  });
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ في تحديث السعر: $e')),
                  );
                }
              } finally {
                if (context.mounted) {
                  setStateDialog(() => isLoading = false);
                }
              }
            }

            return AlertDialog(
              title: Text('تعديل العنصر'),
              content: SingleChildScrollView(
                child: Column(
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
                          availableUnits.map((unit) {
                            return DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit),
                            );
                          }).toList(),
                      onChanged: updatePriceForNewUnit,
                      decoration: InputDecoration(
                        labelText: 'الوحدة',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        TextFormField(
                          controller: priceController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'السعر',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (isLoading)
                          Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
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
                    final newQuantity =
                        int.tryParse(quantityController.text) ?? 1;
                    if (newQuantity > 0) {
                      setState(() {
                        cartItems[index] = {
                          ...cartItems[index],
                          'quantity': newQuantity,
                          'uom': selectedUnit,
                          'price': currentPrice,
                        };
                        total = calculateTotal();
                      });
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('الكمية يجب أن تكون أكبر من الصفر'),
                        ),
                      );
                    }
                  },
                  child: Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<double?> _getItemPriceForUnit(
    String itemCode,
    String unit,
    String priceList,
  ) async {
    print(itemCode);
    print(unit);
    print(priceList);
    try {
      final response = await ApiClient.get(
        '/api/resource/Item Price?fields=["price_list_rate"]'
        '&filters=['
        '["item_code","=","$itemCode"],'
        '["uom","=","$unit"],'
        '["price_list","=","$priceList"],'
        '["selling","=",1]'
        ']',
      );
      print(
        'GET Price => status: ${response.statusCode}, body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'] as List;
        if (data.isNotEmpty) {
          return double.tryParse(data[0]['price_list_rate'].toString());
        }
      }
      return null;
    } catch (e) {
      print('Error fetching price: $e');
      return null;
    }
  }

  double calculateTotal() {
    return cartItems.fold(0.0, (sum, item) {
      double factor = 1.0;
      if (item['unit'] != item['stock_uom'] && item['additionalUOMs'] != null) {
        final uom = (item['additionalUOMs'] as List).firstWhere(
          (u) => u['uom'] == item['unit'],
          orElse: () => {'conversion_factor': 1.0},
        );
        factor = uom['conversion_factor'] ?? 1.0;
      }
      return sum + (item['price'] * item['quantity'] * factor);
    });
  }

  //قائمة العميل //
  Future<void> _showCustomerDialog() async {
    TextEditingController searchController = TextEditingController();
    List<Customer> filteredCustomers = List.from(customers);

    final customer = await showDialog<Customer>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Directionality(
              // نلف المحتوى بالـ Directionality مع RTL
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: backgroundColor,
                title: Text('اختر عميل', style: TextStyle(color: Colors.black)),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // حقل البحث مع TextDirection.rtl
                      TextField(
                        controller: searchController,
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          hintText: 'ابحث بالاسم...',
                          hintStyle: TextStyle(
                            color: Colors.black.withOpacity(0.6),
                          ),
                          prefixIcon: Icon(Icons.search, color: Colors.black),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: primaryColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        style: TextStyle(color: Colors.black),
                        onChanged: (value) {
                          setState(() {
                            filteredCustomers =
                                customers
                                    .where(
                                      (c) => c.customerName
                                          .toLowerCase()
                                          .contains(value.toLowerCase()),
                                    )
                                    .toList();
                          });
                        },
                      ),
                      SizedBox(height: 12),
                      // قائمة العملاء بحجم ثابت مع Scroll داخلي وخلفية بيضاء
                      SizedBox(
                        height: 300,
                        child: Container(
                          color: Colors.white,
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: ClampingScrollPhysics(),
                            itemCount: filteredCustomers.length,
                            itemBuilder: (context, index) {
                              final customer = filteredCustomers[index];
                              return ListTile(
                                leading: Icon(
                                  customer.name == 'CASH'
                                      ? Icons.money
                                      : Icons.person,
                                  color:
                                      customer.name == 'CASH'
                                          ? Colors.green
                                          : primaryColor,
                                ),
                                title: Text(
                                  customer.customerName,
                                  style: TextStyle(color: Colors.black),
                                  textDirection:
                                      TextDirection
                                          .rtl, // عنوان العميل من اليمين لليسار
                                ),
                                subtitle:
                                    customer.name == 'CASH'
                                        ? null
                                        : Text(
                                          customer.customerGroup,
                                          style: TextStyle(
                                            color: Colors.black.withOpacity(
                                              0.6,
                                            ),
                                          ),
                                          textDirection:
                                              TextDirection
                                                  .rtl, // المجموعة من اليمين لليسار
                                        ),
                                onTap: () => Navigator.pop(context, customer),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (customer != null) {
      setState(() => selectedCustomer = customer);
    }
  }

  //--------------------------------------------------------------//
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
        title: const Text('مرتجعات', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: primaryColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(25),
            bottomLeft: Radius.circular(25),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 120),
                  child: Text(
                    selectedCustomer?.customerName ?? 'لم يتم اختيار عميل',
                    style: TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 6),
                // أيقونة لتغيير العميل بدلاً من زر النص
                IconButton(
                  icon: Icon(Icons.person, color: Colors.white, size: 20),
                  tooltip:
                      selectedCustomer == null ? 'اختيار عميل' : 'تغيير العميل',
                  onPressed: _showCustomerDialog,
                ),
                // if (selectedCustomer == null)
                // IconButton(
                //   icon: Icon(Icons.add, color: Colors.greenAccent),
                //   onPressed: _addNewCustomer,
                //   tooltip: 'إضافة عميل جديد',
                // ),
              ],
            ),
          ),
        ],
      ),

      body: Column(
        children: [
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

//------------------------------------------------------//

class ProductCard extends StatelessWidget {
  final Item product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  final Color primaryColor = const Color(0xFFBDB395);

  Color _getStockColor(double qty) {
    if (qty <= 0) return Colors.red;
    if (qty < 10) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    // Build image URL
    String? fullImageUrl;
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      String imagePath = product.imageUrl!;
      if (!imagePath.startsWith('/')) {
        imagePath = '/$imagePath';
      }
      fullImageUrl = 'https://demo2.ababeel.ly$imagePath';
      print('→ Trying to load image: $fullImageUrl');
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 170,
              color: Colors.grey.shade200,
              child: Stack(
                children: [
                  // Background image (flipped)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child:
                          fullImageUrl == null
                              ? Image.asset(
                                'assets/images/placeholder.png',
                                fit: BoxFit.cover,
                              )
                              : Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.rotationY(math.pi),
                                child: FadeInImage.assetNetwork(
                                  placeholder: 'assets/images/placeholder.png',
                                  image: fullImageUrl,
                                  fit: BoxFit.cover,
                                  imageErrorBuilder: (
                                    context,
                                    error,
                                    stackTrace,
                                  ) {
                                    return Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 48,
                                        color: Colors.grey.shade600,
                                      ),
                                    );
                                  },
                                ),
                              ),
                    ),
                  ),

                  // Overlay: item name + price + stock
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.itemName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _buildPriceAndStock(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceAndStock() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Price on the left
        Text(
          '${product.rate.toStringAsFixed(0)} LYD',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Quantity on the right
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _getStockColor(product.qty).withOpacity(0.7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            product.qty.toStringAsFixed(0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
