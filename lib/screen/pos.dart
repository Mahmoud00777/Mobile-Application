import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:drsaf/Class/message_service.dart';
import 'package:drsaf/models/sales_invoice_summary.dart';
import 'package:drsaf/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunmi_printer_plus/core/enums/enums.dart';
import 'package:sunmi_printer_plus/core/styles/sunmi_text_style.dart';
import 'package:sunmi_printer_plus/core/sunmi/sunmi_printer.dart';
import 'package:sunmi_printer_plus/core/types/sunmi_column.dart';
import '../services/sales_invoice.dart';
import '../services/item_service.dart';
import '../services/customer_service.dart';
import '../models/Item.dart';
import '../models/customer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/pos_service.dart';

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
  String? invoDraftName;
  TextEditingController searchController = TextEditingController();
  final Color primaryColor = Color(0xFF60B245);
  final Color secondaryColor = Color(0xFFFFFFFF);
  final Color backgroundColor = Color(0xFFF2F2F2);
  final Color blackColor = Color(0xFF383838);
  bool? hasInternet;

  @override
  void initState() {
    super.initState();
    _fetchProfileAndInitialize();
    searchController.addListener(_filterProducts);
  }

  Future<void> _fetchProfileAndInitialize() async {
    await _checkInternetAndInitialize();
    if (hasInternet == true) {
      try {
        await PosService.fetchAndUpdatePosProfile();
      } catch (e) {
        print('تعذر تحديث POS Profile من السيرفر: $e');
      }
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _checkInternetAndInitialize() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    print("************${connectivityResult.first}");

    bool realInternet = false;
    if (connectivityResult.first == ConnectivityResult.wifi ||
        connectivityResult.first == ConnectivityResult.mobile ||
        connectivityResult.first == ConnectivityResult.ethernet) {
      realInternet = await checkRealInternet();
    }
    setState(() {
      hasInternet = realInternet;
      print("************$hasInternet");
    });
    if (hasInternet == true) {
      _initializeData();
    }
  }

  Future<void> _initializeData() async {
    _loadingTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (isFirstLoad) {
        setState(() => isFirstLoad = false);
      }
    });

    try {
      final results = await Future.wait([
        _loadProducts(),
        _loadCustomers(),
        // _loadPosProfile(),
      ]);

      if (!mounted) return;
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
    itemGroups = await ItemService.getItemGroups();
    final items = await ItemService.getItemsForPOS();
    final filteredItems =
        items.where((item) => itemGroups.contains(item.itemGroup)).toList();
    return filteredItems;
  }

  Future<List<Customer>> _loadCustomers() async {
    final customers = await CustomerService.getCustomers();
    if (!mounted) return [];
    return customers;
  }

  Future<Customer?> _loadPosProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final posProfileJson = prefs.getString('selected_pos_profile');
    if (posProfileJson == null) return null;

    final posProfile = json.decode(posProfileJson);
    if (!mounted) return null;
    return Customer(
      name: posProfile['customer'],
      customerName: posProfile['customer'],
      customerGroup: '',
    );
  }

  void _handleError(dynamic error) {
    if (hasInternet == false) return;
    if (!mounted) return;
    setState(() {
      isLoading = false;
      errorMessage =
          error is SocketException
              ? 'تحقق من اتصال الإنترنت'
              : error is TimeoutException
              ? 'استغرقت العملية وقتًا أطول من المتوقع'
              : 'حدث خطأ في تحميل البيانات';
    });

    if (!mounted) return;
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

  void _increaseQuantity(int index, [Function? setModalState]) {
    final availableQty = productQtyFromCartOrProducts(cartItems[index]);
    final currentQuantity = cartItems[index]['quantity'];
    print(
      "_increaseQuantity - current quantity: $currentQuantity, available: $availableQty",
    );

    // التحقق من أن الكمية الجديدة (الحالية + 1) لا تتجاوز الكمية المتاحة
    if ((currentQuantity + 1) > (availableQty ?? 0)) {
      MessageService.showWarning(
        context,
        "الكمية المطلوبة أكبر من الكمية المتوفرة في المخزن (${availableQty?.toStringAsFixed(2) ?? 'غير معروف'})",
        title: "خطأ في الكمية",
      );
      return;
    }
    setState(() {
      cartItems[index]['quantity'] += 1;
      total += cartItems[index]['price'];
    });
    setModalState?.call(() {});
  }

  void _decreaseQuantity(int index, [Function? setModalState]) {
    setState(() {
      if (cartItems[index]['quantity'] > 1) {
        cartItems[index]['quantity'] -= 1;
        total -= cartItems[index]['price'];
      } else {
        total -= cartItems[index]['price'];
        cartItems.removeAt(index);
      }
    });
    setModalState?.call(() {});
  }

  void addToCart(Item product) {
    final String? costCenter;
    print("product => ${product.Item_Default}");
    if (product.Item_Default != null) {
      var firstItem = product.Item_Default?[0];
      print("المستودع الافتراضي: ${firstItem?['default_warehouse']}");
      print("حساب الإيرادات: ${firstItem?['income_account']}");
      costCenter = firstItem?['selling_cost_center'];
    } else {
      costCenter = null;
    }
    print(costCenter);

    final existingIndex = cartItems.indexWhere(
      (item) => item['item_name'] == product.itemName,
    );
    int currentCartQty = 0;
    if (existingIndex != -1) {
      currentCartQty = cartItems[existingIndex]['quantity'];
    }

    // حساب الكمية المتاحة مع معامل التحويل
    final selectedUOM = product.uom;
    final conversionFactor = getConversionFactor(
      product.additionalUOMs ?? [],
      selectedUOM,
    );
    final availableQty = product.qty / conversionFactor;

    print(
      "product.qty: ${product.qty}, conversionFactor: $conversionFactor, availableQty: $availableQty",
    );

    print(
      "addToCart - currentCartQty: $currentCartQty, availableQty: $availableQty",
    );
    if (currentCartQty + 1 > availableQty) {
      MessageService.showWarning(
        context,
        "الكمية المطلوبة أكبر من الكمية المتوفرة في المخزن (${availableQty.toStringAsFixed(2)})",
        title: "خطأ في الكمية",
      );
      return;
    }
    setState(() {
      print("product.additionalUOMs =>${product.additionalUOMs}");
      final selectedUOM = product.uom;
      final conversionFactor = getConversionFactor(
        product.additionalUOMs ?? [],
        selectedUOM,
      );
      if (existingIndex != -1) {
        cartItems[existingIndex]['quantity'] += 1;
      } else {
        cartItems.add({
          'name': product.name,
          'item_name': product.itemName,
          'price': product.rate,
          'original_price': product.rate,
          'conversion_factor': conversionFactor,
          'quantity': 1,
          'uom': product.uom,
          'additionalUOMs': product.additionalUOMs,
          'discount_amount': product.discount_amount,
          'discount_percentage': product.discount_percentage,
          'cost_center': costCenter,
        });
      }
      total += product.rate;
    });
  }

  double getConversionFactor(List<dynamic> additionalUOMs, String selectedUOM) {
    try {
      final uom = additionalUOMs.firstWhere(
        (uom) => uom['uom'] == selectedUOM,
        orElse: () => {'conversion_factor': 1.0},
      );
      return (uom['conversion_factor'] as num).toDouble();
    } catch (e) {
      return 1.0;
    }
  }

  void removeFromCart(int index, [Function? setModalState]) {
    setState(() {
      total -= cartItems[index]['price'] * cartItems[index]['quantity'];
      cartItems.removeAt(index);
    });
    setModalState?.call(() {});
  }

  void clearCart([Function? setModalState]) {
    setState(() {
      cartItems.clear();
      total = 0.0;
      selectedCustomer = null;
      invoDraftName = null;
    });
    setModalState?.call(() {});
  }

  Future<void> _processPayment(BuildContext context) async {
    if (selectedCustomer == null) {
      MessageService.showWarning(
        context,
        'الرجاء اختيار عميل أولاً',
        title: 'فشل في إتمام البيع',
      );
      return;
    }

    if (cartItems.isEmpty) {
      MessageService.showWarning(
        context,
        'السلة فارغة',
        title: 'فشل في إتمام البيع',
      );
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
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final double paidAmount = paymentData['paid_amount'];
      final double outstanding = paymentData['outstanding_amount'];
      final double? discountAmount = paymentData['discount_amount'] ?? 0.0;
      final double? discountPercentage =
          paymentData['additional_discount_percentage'] ?? 0.0;
      final double totalAfterDiscount =
          paymentData['total_after_discount'] ?? total;

      print('''
    بيانات الدفع:
    المبلغ المدفوع: $paidAmount
    المتبقي: $outstanding
    الخصم: ${discountAmount ?? discountPercentage} ${discountAmount != null ? 'د.ر' : '%'}
    الإجمالي بعد الخصم: $totalAfterDiscount
    ''');

      final Map<String, dynamic> invoiceResult;
      print(invoDraftName);
      if (invoDraftName == null) {
        print("add");
        invoiceResult = await SalesInvoice.createSalesInvoice(
          customer: selectedCustomer!,
          items: cartItems,
          total: totalAfterDiscount,
          paymentMethod: paymentData,
          paidAmount: paidAmount,
          outstandingAmount: outstanding,
          discountAmount: discountAmount,
          discountPercentage: discountPercentage,
        );
      } else {
        print("update");
        invoiceResult = await SalesInvoice.updateSalesInvoice(
          customer: selectedCustomer!,
          items: cartItems,
          total: totalAfterDiscount,
          paymentMethod: paymentData,
          paidAmount: paidAmount,
          outstandingAmount: outstanding,
          discountAmount: discountAmount,
          discountPercentage: discountPercentage,
          invoName: invoDraftName,
        );
      }

      if (!invoiceResult['success']) {
        final errorMessage = invoiceResult['success'] ?? 'حدث خطأ غير معروف';
        MessageService.showError(
          context,
          errorMessage,
          title: 'فشل في إنشاء الفاتورة',
        );
        throw Exception(errorMessage);
      }
      if (!invoiceResult['result']['success']) {
        final errorMessage =
            invoiceResult['result']['details'] ?? 'حدث خطأ غير معروف';
        MessageService.showError(
          context,
          errorMessage.toString(),
          title: 'فشل في تأكيد الفاتورة بعد انشائها ',
        );
        throw Exception(errorMessage);
      }
      print('=== DEBUG COMPLETE SALE ===');
      print('cartItems before printTest: ${cartItems.length}');
      print('cartItems content: $cartItems');
      final cartItemsCopy = List<Map<String, dynamic>>.from(cartItems);
      print('=== DEBUG CART COPY ===');
      print('Original cartItems length: ${cartItems.length}');
      print('Copied cartItems length: ${cartItemsCopy.length}');
      print('Copied cartItems: $cartItemsCopy');
      printSalesInvoice(
        selectedCustomer,
        cartItemsCopy,
        invoiceResult['full_invoice']['name'],
        invoiceResult['customer_outstanding'],
      );
      print('=== END DEBUG COMPLETE SALE ===');

      // إغلاق الحوارات
      Navigator.pop(context);
      Navigator.pop(context);

      // عرض رسالة النجاح
      MessageService.showSuccess(
        context,
        '${invoiceResult['full_invoice']['name']}تم إنشاء الفاتورة بنجاح',
      );

      final itemNames =
          cartItems.map((item) => item['name'].toString()).toList();
      final prefs = await SharedPreferences.getInstance();
      final posProfileJson = prefs.getString('selected_pos_profile');
      final posProfile = json.decode(posProfileJson!);
      final warehouse = posProfile['warehouse'];

      try {
        final quantities = await ItemService.updateItemsQuantities(
          itemNames: itemNames,
          warehouse: warehouse,
        );

        for (int i = 0; i < products.length; i++) {
          final itemName = products[i].name;
          if (quantities.containsKey(itemName)) {
            products[i] = products[i].copyWith(qty: quantities[itemName]!);
          }
        }

        for (int i = 0; i < filteredProducts.length; i++) {
          final itemName = filteredProducts[i].name;
          if (quantities.containsKey(itemName)) {
            filteredProducts[i] = filteredProducts[i].copyWith(
              qty: quantities[itemName]!,
            );
          }
        }
      } catch (e) {
        print('خطأ في تحديث الكميات: $e');
        ItemService.clearCache();
        final updatedProducts = await ItemService.getItems();
        setState(() {
          products = updatedProducts;
          filteredProducts = updatedProducts;
        });
      }

      print('=== DEBUG BEFORE CLEARING CART ===');
      print('cartItems before clearing: ${cartItems.length}');
      setState(() {
        cartItems.clear();
        total = 0.0;
        selectedCustomer = null;
        invoDraftName = null;
      });
      print('=== DEBUG AFTER CLEARING CART ===');
    } catch (e, stack) {
      Navigator.pop(context);
      print('خطأ في إتمام البيع: $e\n$stack');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في إتمام البيع: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _showPaymentDialog(
    BuildContext context,
    List<Map<String, dynamic>> paymentMethods,
    double invoiceTotal,
  ) async {
    String selectedMethod = paymentMethods.first['mode_of_payment'];
    final TextEditingController amountController = TextEditingController(
      text: invoiceTotal.toStringAsFixed(2),
    );
    final TextEditingController discountController = TextEditingController();
    double paidAmount = invoiceTotal;
    String discountType = 'fixed'; // 'fixed' or 'percentage'
    double invoiceDiscount = 0.0;
    double invoiceAfterDiscount = invoiceTotal;

    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void updateInvoice() {
              final discountValue =
                  double.tryParse(discountController.text) ?? 0.0;

              if (discountType == 'percentage') {
                invoiceDiscount = invoiceTotal * (discountValue / 100);
              } else {
                invoiceDiscount = discountValue;
              }

              if (invoiceDiscount > invoiceTotal) {
                invoiceDiscount = invoiceTotal;
              }

              invoiceAfterDiscount = invoiceTotal - invoiceDiscount;

              if (paidAmount > invoiceAfterDiscount) {
                paidAmount = invoiceAfterDiscount;
                amountController.text = paidAmount.toStringAsFixed(2);
              }

              setState(() {});
            }

            void toggleDiscountType() {
              setState(() {
                discountType = discountType == 'fixed' ? 'percentage' : 'fixed';
                updateInvoice();
              });
            }

            return AlertDialog(
              title: const Text('إتمام عملية الدفع'),
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
                      onChanged: (value) {
                        setState(() {
                          selectedMethod = value!;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'طريقة الدفع',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: discountController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText:
                                          discountType == 'fixed'
                                              ? 'قيمة الخصم'
                                              : 'نسبة الخصم %',
                                      border: const OutlineInputBorder(),
                                      prefixIcon: Icon(
                                        discountType == 'fixed'
                                            ? Icons.attach_money
                                            : Icons.percent,
                                      ),
                                    ),
                                    onChanged: (_) => updateInvoice(),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    discountType == 'fixed'
                                        ? Icons.percent
                                        : Icons.attach_money,
                                  ),
                                  onPressed: toggleDiscountType,
                                  tooltip: 'تبديل نوع الخصم',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              discountType == 'fixed'
                                  ? 'خصم بقيمة ثابتة'
                                  : 'خصم بنسبة مئوية',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'المبلغ المدفوع',
                        suffixText: 'د.ر',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          paidAmount = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'إجمالي الفاتورة: ${invoiceTotal.toStringAsFixed(2)} د.ر',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'الخصم: ${invoiceDiscount.toStringAsFixed(2)} د.ر',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'الإجمالي بعد الخصم: ${invoiceAfterDiscount.toStringAsFixed(2)} د.ر',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'المتبقي: ${(invoiceAfterDiscount - paidAmount).toStringAsFixed(2)} د.ر',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                (invoiceAfterDiscount - paidAmount) > 0
                                    ? Colors.red
                                    : Colors.green,
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
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () {
                    if (amountController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('الرجاء إدخال مبلغ الدفع'),
                        ),
                      );
                      return;
                    }

                    final paid = double.tryParse(amountController.text) ?? 0.0;
                    if (paid < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('المبلغ يجب أن يكون أكبر من الصفر'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context, {
                      'mode_of_payment': selectedMethod,
                      'paid_amount': paid,
                      'outstanding_amount': invoiceAfterDiscount - paid,
                      'discount_amount':
                          discountType == 'fixed' ? invoiceDiscount : null,
                      'additional_discount_percentage':
                          discountType == 'percentage'
                              ? double.tryParse(discountController.text) ?? 0.0
                              : null,
                      'total_after_discount': invoiceAfterDiscount,
                    });
                  },
                  child: const Text('تأكيد الدفع'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
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
                _showSearchDialog();
              },
            ),
          ),

          SizedBox(width: 10),

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
                    _filterProducts();
                  },
                ),
                SizedBox(height: 10),
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
  Widget _buildCartSection([Function? setModalState]) {
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
                  'سلة المشتريات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2,
                            size: 16,
                            color: Colors.green[700],
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${calculateTotalQuantity()}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
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
              ],
            ),
          ),

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
                          onTap:
                              () => _showEditItemDialog(
                                context,
                                index,
                                setModalState,
                              ),
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
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '${(item['price'] * item['quantity']).toStringAsFixed(2)} LYD',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Colors.blue[800],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Material(
                                      color: Colors.grey[200],
                                      shape: CircleBorder(),
                                      elevation: 1,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap:
                                            () => removeFromCart(
                                              index,
                                              setModalState,
                                            ),
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
                                                () => _decreaseQuantity(
                                                  index,
                                                  setModalState,
                                                ),
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
                                                () => _increaseQuantity(
                                                  index,
                                                  setModalState,
                                                ),
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
                    onPressed: () => clearCart(setModalState),
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
  Future<void> _showEditItemDialog(
    BuildContext context,
    int index, [
    Function? setModalState,
  ]) async {
    final item = cartItems[index];
    print("item: $item");
    double originalPrice = (item['original_price'] ?? item['price']) as double;

    final controllers = {
      'quantity': TextEditingController(text: item['quantity'].toString()),
      'price': TextEditingController(text: item['price'].toStringAsFixed(2)),
      'discount': TextEditingController(
        text:
            (item['discount_amount'] ?? item['discount_percentage'] ?? 0)
                .toString(),
      ),
    };

    String selectedUnit = item['uom'];
    print('''selectedUnit ===>>>$selectedUnit''');
    String discountType =
        item['discount_amount'] != null ? 'amount' : 'percentage';
    bool isLoading = false;

    Set<String> availableUnits = {item['uom']?.toString() ?? 'وحدة'};
    if (item['additionalUOMs'] != null) {
      availableUnits.addAll(
        (item['additionalUOMs'] as List)
            .where((uom) => uom['uom'] != null)
            .map((uom) => uom['uom'].toString()),
      );
    }
    print('''availableUnits ===>>>$availableUnits''');

    double selectedConversionFactor = item['conversion_factor'] ?? 1.0;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void updatePrice() {
              final discountValue =
                  double.tryParse(controllers['discount']!.text) ?? 0;
              double newPrice = originalPrice;

              if (discountType == 'percentage') {
                newPrice = originalPrice * (1 - discountValue / 100);
              } else {
                newPrice = originalPrice - discountValue;
              }

              if (newPrice < 0) newPrice = 0;
              print("newPrice after discount ===>>$newPrice");

              final finalPrice = newPrice;
              print("finalPrice after conversion ===>>$finalPrice");
              controllers['price']!.text = finalPrice.toStringAsFixed(2);
            }

            Future<void> updatePriceForNewUnit(String? newUnit) async {
              if (newUnit == null || newUnit == selectedUnit) return;

              setStateDialog(() => isLoading = true);

              try {
                double factor = 1.0;
                if (item['additionalUOMs'] != null) {
                  final uom = (item['additionalUOMs'] as List)
                      .cast<Map<String, dynamic>>()
                      .firstWhere(
                        (u) => u['uom'] == newUnit,
                        orElse: () => {'conversion_factor': 1.0},
                      );
                  factor =
                      (uom['conversion_factor'] as num?)?.toDouble() ?? 1.0;
                  print("////////////////////////////");
                }
                print("conversion_factor for $newUnit: $factor");
                print(
                  "price ===>>${item['price']?.toString()} ${item['original_price']}",
                );
                final priceList =
                    await getPriceListFromPosProfile() ?? 'البيع القياسية';
                final newPrice = await _getItemPriceForUnit(
                  item['name']?.toString() ?? '',
                  newUnit,
                  priceList,
                );
                print("newPrice ===>>$newPrice");
                setStateDialog(() {
                  selectedUnit = newUnit;
                  selectedConversionFactor = factor;

                  // تحديث السعر الأصلي بناءً على الوحدة الجديدة
                  double basePrice;
                  if (newPrice != null) {
                    print("newPrice != null: $newPrice");
                    basePrice = newPrice;
                  } else {
                    print("newPrice == null, using original price");
                    basePrice =
                        (item['original_price'] ?? item['price']) as double;
                  }

                  // تحديث السعر الأصلي للاستخدام في حسابات الخصم
                  originalPrice = basePrice;
                  print("originalPrice updated to: $originalPrice");

                  // تطبيق معامل التحويل
                  final finalPrice = basePrice * selectedConversionFactor;
                  controllers['price']!.text = finalPrice.toStringAsFixed(2);

                  print(
                    "selectedConversionFactor ===>>$selectedConversionFactor",
                  );
                  print("basePrice ===>>$basePrice");
                  print("finalPrice ===>>$finalPrice");
                  print(
                    "controllers['price']!.text ===>>${controllers['price']!.text}",
                  );

                  // التحقق من الكمية المتاحة مع الوحدة الجديدة
                  final currentQuantity =
                      int.tryParse(controllers['quantity']!.text) ?? 1;
                  final availableQty = productQtyFromCartOrProducts({
                    ...item,
                    'conversion_factor': selectedConversionFactor,
                    'uom': selectedUnit,
                  });

                  if (availableQty != null && currentQuantity > availableQty) {
                    print("Warning: Quantity exceeds available stock");
                    print(
                      "currentQuantity: $currentQuantity, availableQty: $availableQty",
                    );
                    // لا نعرض رسالة خطأ هنا لأن المستخدم قد يريد تعديل الكمية لاحقاً
                  }

                  // تطبيق الخصم إذا كان موجوداً
                  updatePrice();
                });
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

            void toggleDiscountType() {
              setStateDialog(() {
                discountType =
                    discountType == 'percentage' ? 'amount' : 'percentage';
                updatePrice();
              });
            }

            return AlertDialog(
              title: const Text('تعديل العنصر'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: controllers['quantity'],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الكمية',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.format_list_numbered),
                      ),
                      onChanged: (value) {
                        final qty = int.tryParse(value) ?? 1;
                        if (qty <= 0) {
                          controllers['quantity']!.text = '1';
                        }
                      },
                    ),

                    const SizedBox(height: 16),

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
                      decoration: const InputDecoration(
                        labelText: 'الوحدة',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.scale),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: controllers['discount'],
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText:
                                          discountType == 'percentage'
                                              ? 'نسبة الخصم %'
                                              : 'قيمة الخصم',
                                      border: const OutlineInputBorder(),
                                      prefixIcon: Icon(
                                        discountType == 'percentage'
                                            ? Icons.percent
                                            : Icons.currency_exchange,
                                      ),
                                    ),
                                    onChanged: (_) => updatePrice(),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    discountType == 'percentage'
                                        ? Icons.percent
                                        : Icons.currency_exchange,
                                  ),
                                  onPressed: toggleDiscountType,
                                  tooltip: 'تبديل نوع الخصم',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              discountType == 'percentage'
                                  ? 'يتم تطبيق الخصم كنسبة مئوية'
                                  : 'يتم تطبيق الخصم كمبلغ ثابت',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.price_change,
                            color: Colors.green,
                          ),
                          title: const Text('السعر النهائي'),
                          subtitle: Text(
                            'السعر الأصلي: ${originalPrice.toStringAsFixed(2)}',
                          ),
                          trailing: Text(
                            controllers['price']!.text,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        if (isLoading)
                          const Padding(
                            padding: EdgeInsets.only(right: 16),
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
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () {
                    final newQuantity =
                        int.tryParse(controllers['quantity']!.text) ?? 1;
                    final discountValue =
                        double.tryParse(controllers['discount']!.text) ?? 0;
                    final availableQty = productQtyFromCartOrProducts(item);
                    print(
                      "_showEditItemDialog - newQuantity: $newQuantity, availableQty: $availableQty",
                    );
                    if (newQuantity > availableQty!) {
                      MessageService.showWarning(
                        context,
                        "الكمية المطلوبة أكبر من الكمية المتوفرة في المخزن (${availableQty.toStringAsFixed(2)})",
                        title: "خطأ في الكمية",
                      );
                      return;
                    }
                    if (newQuantity <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('الكمية يجب أن تكون أكبر من الصفر'),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      cartItems[index] = {
                        ...cartItems[index],
                        'quantity': newQuantity,
                        'uom': selectedUnit,
                        'conversion_factor': selectedConversionFactor,
                        'price': double.parse(controllers['price']!.text),
                        'original_price': originalPrice,
                        'discount_amount':
                            discountType == 'amount' ? discountValue : null,
                        'discount_percentage':
                            discountType == 'percentage' ? discountValue : null,
                      };
                      total = calculateTotal();
                    });
                    setModalState?.call(() {});
                    Navigator.pop(context);
                  },
                  child: const Text('حفظ التغييرات'),
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
      // double factor = item['conversion_factor'] ?? 1.0;
      return sum + (item['price'] * item['quantity']);
    });
  }

  int calculateTotalQuantity() {
    return cartItems.fold(0, (sum, item) => sum + (item['quantity'] as int));
  }

  Future<void> _showCustomerDialog() async {
    TextEditingController searchController = TextEditingController();
    List<Customer> filteredCustomers = List.from(customers);

    final customer = await showDialog<Customer>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: backgroundColor,
                title: Text('اختر عميل', style: TextStyle(color: Colors.black)),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                                  textDirection: TextDirection.rtl,
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
    // if (hasInternet == null) {
    //   return Scaffold(body: Center(child: CircularProgressIndicator()));
    // }

    if (hasInternet == false) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('نقطة البيع'),
          backgroundColor: primaryColor,
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
                onPressed: () {
                  _checkInternetAndInitialize();
                },
              ),
            ],
          ),
        ),
      );
    }

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'نقطة البيع',
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: primaryColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomRight: Radius.circular(25),
              bottomLeft: Radius.circular(25),
            ),
          ),
        ),
        body: _buildLoadingScreen(),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(child: Text(errorMessage));
    }

    return WillPopScope(
      onWillPop: () async {
        if (cartItems.isNotEmpty) {
          final shouldExit = await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text('تحذير'),
                  content: Text(
                    'لديك عناصر في سلة التسوق. هل تريد الخروج دون حفظ؟',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text('نعم، خروج'),
                    ),
                  ],
                ),
          );
          return shouldExit ?? false;
        }
        return true;
      },
      child: Scaffold(
        floatingActionButton: Stack(
          children: [
            Positioned(
              bottom: 150,
              right: 5,
              child: FloatingActionButton(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    barrierColor: Colors.black54,
                    isDismissible: true,
                    enableDrag: false, // Prevent dragging
                    builder: (context) => Container(
                      height: MediaQuery.of(context).size.height * 0.7, // Fixed height
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(25),
                        ),
                      ),
                      child: FutureBuilder<Widget>(
                        future: _ShowListDraftInvoices(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          return snapshot.data ??
                              Center(child: Text('حدث خطأ غير متوقع'));
                        },
                      ),
                    ),
                  );
                },
                backgroundColor: Colors.blue,
                heroTag: 'list_button',
                child: Icon(Icons.list, color: Colors.white),
              ),
            ),
            Positioned(
              bottom: 80,
              right: 5,
              child: FloatingActionButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _saveInvoice();
                },
                backgroundColor: Colors.blue,
                heroTag: 'save_button',
                child: Icon(Icons.save, color: Colors.white),
              ),
            ),
            Positioned(
              bottom: 16,
              right: 5,
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  FloatingActionButton(
                    heroTag: 'cart_button',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (context) {
                          final screenHeight =
                              MediaQuery.of(context).size.height;
                          return StatefulBuilder(
                            builder: (context, setModalState) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      MediaQuery.of(context).viewInsets.bottom,
                                ),
                                child: SizedBox(
                                  height: screenHeight * 0.5,
                                  child: _buildCartSection(setModalState),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                    backgroundColor: Color(0xFF60B245),
                    child: Icon(Icons.shopping_cart, color: Colors.white),
                  ),
                  if (cartItems.isNotEmpty)
                    Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(minWidth: 22, minHeight: 22),
                      child: Text(
                        '${calculateTotalQuantity()}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),

        appBar: AppBar(
          title: const Text(
            'نقطة البيع',
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: primaryColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomRight: Radius.circular(25),
              bottomLeft: Radius.circular(25),
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
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
                  IconButton(
                    icon: Icon(Icons.person, color: Colors.white, size: 20),
                    tooltip:
                        selectedCustomer == null
                            ? 'اختيار عميل'
                            : 'تغيير العميل',
                    onPressed: _showCustomerDialog,
                  ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),

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
            itemCount: 12,
            itemBuilder: (context, index) {
              return _buildProductSkeleton();
            },
          ),
        ),

        Expanded(flex: 6, child: _buildCartSkeleton()),
      ],
    );
  }

  Widget _buildProductSkeleton() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.grey[300]!,
                            Colors.grey[100]!,
                            Colors.grey[300]!,
                          ],
                          stops: [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 12,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[500],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                height: 10,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey[500],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Container(
                                height: 10,
                                width: 20,
                                decoration: BoxDecoration(
                                  color: Colors.grey[500],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSkeleton() {
    return Card(
      margin: EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: primaryColor, width: 1.0),
      ),
      elevation: 2,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
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
              itemCount: 5,
              itemBuilder: (context, index) {
                return _buildCartItemSkeleton();
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
    );
  }

  Widget _buildCartItemSkeleton() {
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

  double? productQtyFromCartOrProducts(Map<String, dynamic> item) {
    print("=== productQtyFromCartOrProducts ===");
    print("item: $item");
    try {
      final found = products.firstWhere((p) => p.itemName == item['item_name']);
      final conversionFactor = item['conversion_factor'] ?? 1.0;
      final availableQty = found.qty / conversionFactor;
      print(
        "found.qty: ${found.qty}, conversionFactor: $conversionFactor, availableQty: $availableQty",
      );
      print("=== END productQtyFromCartOrProducts ===");
      return availableQty;
    } catch (e) {
      print("Error in productQtyFromCartOrProducts: $e");
      return null;
    }
  }

  Future<void> _saveInvoice() async {
    if (invoDraftName != null) {
      MessageService.showWarning(context, "لايمكنك حفظ فاتورة معلقة");
      return;
    }
    if (selectedCustomer == null) {
      MessageService.showWarning(
        context,
        'الرجاء اختيار عميل أولاً',
        title: 'فشل في إتمام البيع',
      );
      return;
    }

    if (cartItems.isEmpty) {
      MessageService.showWarning(
        context,
        'السلة فارغة',
        title: 'فشل في إتمام البيع',
      );
      return;
    }

    final invoiceResult = await SalesInvoice.createDraftSalesInvoice(
      customer: selectedCustomer!,
      items: cartItems,
      total: 0,
      paidAmount: 0,
      outstandingAmount: 0,
      discountAmount: 0,
      discountPercentage: 0,
    );

    MessageService.showSuccess(context, 'تم إنشاء الفاتورة معلقة بنجاح');
    setState(() {
      cartItems.clear();
      total = 0.0;
      selectedCustomer = null;
    });
  }

  Future<Widget> _ShowListDraftInvoices() async {
    try {
      final List<SalesInvoiceSummary>? invoices =
          await SalesInvoice.getDraftSalesinvoice();

      if (invoices == null || invoices.isEmpty) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'لا توجد فواتير مسودة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'الفواتير المسودة ستظهر هنا',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    color: Colors.blue[700],
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الفواتير المسودة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        '${invoices.length} فاتورة',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Text(
                    'مسودة',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.all(16),
              itemCount: invoices.length,
              separatorBuilder: (_, __) => SizedBox(height: 12),
              itemBuilder: (context, index) {
                final invoice = invoices[index];
                return Dismissible(
                  key: Key(invoice.invoiceNumber),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red[500],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.delete_forever,
                                color: Colors.white,
                                size: 24,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'حذف',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    return await _confirmDelete(context, invoice.invoiceNumber);
                  },
                  onDismissed: (direction) {
                    _deleteInvoice(context, invoice.invoiceNumber);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap:
                            () => _loadInvoiceDetails(
                              context,
                              invoice.invoiceNumber,
                            ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.receipt,
                                      color: Colors.blue[700],
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'فاتورة رقم',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          '#${invoice.invoiceNumber}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.green[200]!,
                                      ),
                                    ),
                                    child: Text(
                                      '${invoice.grandTotal} د.ر',
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.touch_app,
                                    size: 16,
                                    color: Colors.grey[500],
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'اضغط لتحميل الفاتورة',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  Spacer(),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: Colors.grey[400],
                                  ),
                                ],
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
        ],
      );
    } catch (e) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[600],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'حدث خطأ في جلب الفواتير',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'يرجى المحاولة مرة أخرى',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Future<void> _loadInvoiceDetails(
    BuildContext context,
    String invoiceName,
  ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      final detailedInvoice = await SalesInvoice.getSalesInvoiceByName(
        invoiceName,
      );
      print(detailedInvoice);
      print('''
      === معلومات الفاتورة ===
      الرقم: ${detailedInvoice['name']}
      العميل: ${detailedInvoice['customer_name']}
      الشركة: ${detailedInvoice['company']}
      التاريخ: ${detailedInvoice['posting_date']}
      الحالة: ${detailedInvoice['docstatus'] == 0 ? 'مسودة' : 'مؤكدة'}
      تم الإنشاء بواسطة: ${detailedInvoice['owner']}
      آخر تعديل: ${detailedInvoice['modified_by']} في ${detailedInvoice['modified']}
      ${detailedInvoice['items']}
      ''');
      setState(() {
        invoDraftName = detailedInvoice['name'];
        print('''الرقم: ${detailedInvoice['name']}''');
        selectedCustomer = Customer(
          name: detailedInvoice['customer_name'],
          customerName: detailedInvoice['customer_name'],
          customerGroup: '',
        );
        final List<dynamic> rawItems = detailedInvoice['items'] ?? [];
        cartItems =
            rawItems.whereType<Map<String, dynamic>>().map((item) {
              return {
                'id': item['name'],
                'name': item['item_code']?.toString() ?? '',
                'item_name': item['item_name']?.toString(),
                'price': (item['rate'] ?? item['price'] ?? 0.0) as double,
                'quantity': (item['qty'] as num).toInt(),
                'uom': item['uom']?.toString(),
                'additionalUOMs': item['additionalUOMs'],
                'discount_amount': (item['discount_amount'] ?? 0.0) as double,
                'discount_percentage':
                    (item['discount_percentage'] ?? 0.0) as double,
                'cost_center': item['cost_center']?.toString(),
                'income_account': item['income_account'],
              };
            }).toList();
        total = calculateTotal();
      });

      Navigator.pop(context);
      Navigator.pop(context);
      MessageService.showSuccess(context, "تم  تحميل بيانات الفاتورة ");
    } catch (e) {
      Navigator.pop(context);
      print(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل الفاتورة: ${e.toString()}')),
      );
    }
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    String invoiceNumber,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('تأكيد الحذف'),
            content: Text(
              'هل أنت متأكد من حذف الفاتورة #$invoiceNumber؟ لا يمكن التراجع عن هذا الإجراء.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('حذف', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    return confirmed ?? false;
  }

  Future<void> _deleteInvoice(
    BuildContext context,
    String invoiceNumber,
  ) async {
    try {
      final success = await SalesInvoice.deleteInvoice(invoiceNumber);
      if (success) {
        MessageService.showSuccess(context, "تم حذف الفاتورة المعلقة بنجاح");
        setState(() {});
      }
    } catch (e) {
      MessageService.showWarning(context, "لم يتم حذف الفاتورة المعلقة ");
    }
  }
}

void printSalesInvoice(
  Customer? selectedCustomer,
  List<Map<String, dynamic>> cartItems,
  invoName,
  outstanding,
) async {
  print('=== DEBUG PRINT TEST ===');
  print('selectedCustomer: ${selectedCustomer?.customerName}');
  print('cartItems length: ${cartItems.length}');
  print('cartItems: $cartItems');
  print('cartItems is empty: ${cartItems.isEmpty}');
  print('cartItems is null: ${cartItems == null}');
  print('invoName: $invoName');
  print('outstanding: $outstanding');
  print('=== END DEBUG ===');

  if (!await isSunmiDevice()) {
    print('🚫 ليس جهاز Sunmi. إلغاء الطباعة.');
    return;
  }
  print(invoName);
  print(outstanding);
  final ByteData logoBytes = await rootBundle.load('assets/images/test.png');
  final Uint8List imageBytes = logoBytes.buffer.asUint8List();
  final now = DateTime.now();
  final formattedDate = DateFormat('yyyy-MM-dd – HH:mm').format(now);
  // ignore: deprecated_member_use
  await SunmiPrinter.initPrinter();
  // ignore: deprecated_member_use
  await SunmiPrinter.startTransactionPrint(true);
  await SunmiPrinter.printImage(imageBytes, align: SunmiPrintAlign.CENTER);

  await SunmiPrinter.printText(
    'فاتورة',
    style: SunmiTextStyle(
      bold: true,
      align: SunmiPrintAlign.CENTER,
      fontSize: 50,
    ),
  );
  await SunmiPrinter.printText(
    '--------------------------------',
    style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true),
  );
  await SunmiPrinter.line();
  await SunmiPrinter.printText(
    'الزبون: ${selectedCustomer?.customerName ?? "غير معروف"}',
  );
  await SunmiPrinter.printText('');
  await SunmiPrinter.printText('التاريخ والوقت: $formattedDate');
  await SunmiPrinter.printText('رقم الفاتورة : $invoName');

  await SunmiPrinter.printText('');
  await SunmiPrinter.lineWrap(3);

  // // طباعة جدول العناصر
  // await SunmiPrinter.printText(
  //   'المنتج       الكمية   السعر   الإجمالي',
  //   style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER),
  // );
  await SunmiPrinter.printRow(
    cols: [
      SunmiColumn(
        text: 'الإجمالي',
        width: 3,
        style: SunmiTextStyle(align: SunmiPrintAlign.LEFT, bold: true),
      ),
      SunmiColumn(
        text: 'السعر',
        width: 2,
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true),
      ),
      SunmiColumn(
        text: 'الكمية',
        width: 2,
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true),
      ),
      SunmiColumn(
        text: 'الوحدة',
        width: 2,
        style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true),
      ),
      SunmiColumn(
        text: 'المنتج',
        width: 4,
        style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true),
      ),
    ],
  );
  await SunmiPrinter.printText(
    '--------------------------------',
    style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
  );
  double total = 0.0;

  print('=== DEBUG PRINTING ITEMS ===');
  print('cartItems length in printTest: ${cartItems.length}');

  for (final item in cartItems) {
    print('Processing item: $item');
    final name = item['item_name'] ?? '';
    final qty = item['quantity'] ?? 0;
    final rate = item['price'].toInt();
    final amount = (qty * rate).toInt();
    final uom = item['uom'];

    print('name: $name, qty: $qty, rate: $rate, amount: $amount, uom: $uom');

    total += amount;

    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: amount.toStringAsFixed(0),
          width: 2,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: rate.toStringAsFixed(0),
          width: 2,
          style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
        ),
        SunmiColumn(
          text: '×$qty',
          width: 2,
          style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
        ),
        SunmiColumn(
          text: uom,
          width: 2,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
        SunmiColumn(
          text: name,
          width: 6,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );
    await SunmiPrinter.printText(
      '--------------------------------',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
    );
  }

  await SunmiPrinter.printText(
    'الإجمالي: ${total.toStringAsFixed(1)} LYD',
    style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.RIGHT),
  );
  await SunmiPrinter.printText(
    'ديون: ${outstanding.toStringAsFixed(1)} LYD',
    style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.RIGHT),
  );
  await SunmiPrinter.printText(
    '--------------------------------',
    style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
  );
  await SunmiPrinter.printText(
    'شكرًا لزيارتكم!',
    style: SunmiTextStyle(
      bold: true,
      fontSize: 35,
      align: SunmiPrintAlign.CENTER,
    ),
  );

  await SunmiPrinter.printText(
    'نتمنى أن نراكم مجددًا 😊',
    style: SunmiTextStyle(fontSize: 35, align: SunmiPrintAlign.CENTER),
  );

  await SunmiPrinter.lineWrap(3);
  await SunmiPrinter.cutPaper();
}

Future<bool> checkRealInternet() async {
  try {
    final result = await InternetAddress.lookup('google.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<bool> isSunmiDevice() async {
  if (!Platform.isAndroid) return false;

  final deviceInfo = DeviceInfoPlugin();
  final androidInfo = await deviceInfo.androidInfo;

  final brand = androidInfo.brand.toLowerCase() ?? '';
  final manufacturer = androidInfo.manufacturer.toLowerCase() ?? '';

  return brand.contains('sunmi') || manufacturer.contains('sunmi');
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
        Text(
          '${product.rate.toStringAsFixed(0)} LYD',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          product.uom,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 4,
            fontWeight: FontWeight.bold,
          ),
        ),
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

Future<String?> getPriceListFromPosProfile() async {
  final prefs = await SharedPreferences.getInstance();
  final posProfileJson = prefs.getString('selected_pos_profile');
  if (posProfileJson == null) return null;
  final posProfile = json.decode(posProfileJson);
  return posProfile['price_list'] as String?;
}
