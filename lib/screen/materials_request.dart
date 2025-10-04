import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:alkhair_daem/Class/message_service.dart';
import 'package:alkhair_daem/services/pos_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/Item.dart';
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
  List<Item> filteredItems = []; // الأصناف المفلترة
  List<Warehouse> availableWarehouses = [];
  List<Map<String, dynamic>> selectedItems = [];
  bool isLoading = true;
  String errorMessage = '';
  final Color primaryColor = Color(0xFF60B245);
  final Color secondaryColor = Color(0xFFFFFFFF);
  final Color backgroundColor = Color(0xFFF2F2F2);
  final Color blackColor = Color(0xFF383838);

  // متغيرات البحث والتصفية
  TextEditingController searchController = TextEditingController();
  List<String> itemGroups = [];
  String? selectedItemGroup;

  // متغيرات البحث الذكي
  bool _isLoadingMore = false;
  bool _hasMoreItems = true;
  int _currentPage = 0;
  final int _pageSize = 15; // حجم أصغر للشاشة
  final String _currentSearchQuery = '';
  String? _currentItemGroup;
  bool _isSearching = false;
  Timer? _searchDebounceTimer;
  Timer? _loadingTimer;

  final List<String> requestReasons = [
    'الشراء',
    'تحويل المواد',
    'صرف المواد',
    'التصنيع',
    'مقدّم من العميل',
  ];
  String selectedReason = 'تحويل المواد';

  List<Map<String, dynamic>> cartItems = [];
  bool? hasInternet;

  static const Map<String, String> statusLabels = {
    'Pending': 'قيد الانتظار',
    'Draft': 'مسودة',
    'Transferred': 'تم التحويل',
    'Cancelled': 'ملغى',
  };
  String? selectedStatus;
  List<MaterialRequest> allRequests = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    searchController.addListener(_onSearchChanged);
    _fetchProfileAndInitialize();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _loadingTimer?.cancel();
    searchController.dispose();
    ItemService.clearCache();
    super.dispose();
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

  Future<void> _checkInternetAndInitialize() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    bool realInternet = false;
    if (connectivityResult.first == ConnectivityResult.wifi ||
        connectivityResult.first == ConnectivityResult.mobile ||
        connectivityResult.first == ConnectivityResult.ethernet) {
      realInternet = await checkRealInternet();
    }
    setState(() {
      hasInternet = realInternet;
    });
    if (hasInternet == true) {
      _loadData();
    }
  }

  Future<bool> checkRealInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadData() async {
    try {
      // تحميل الأصناف الأساسية في الخلفية
      await _preloadEssentialItemsOnStart();

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
        availableWarehouses = [warehouse];
        selectedWarehouse = warehouse;
        errorMessage = '';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        availableItems = [];
        filteredItems = [];
        itemGroups = [];
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

  // تحميل الأصناف الأساسية في الخلفية
  Future<void> _preloadEssentialItemsOnStart() async {
    try {
      print('🔄 بدء تحميل الأصناف الأساسية لطلب المواد...');

      final results = await Future.wait([
        ItemService.getEssentialItems(limit: 12), // limit أصغر للشاشة
        ItemService.getItemGroups(),
      ]);

      if (mounted) {
        setState(() {
          availableItems = results[0] as List<Item>;
          filteredItems = availableItems;
          itemGroups = results[1] as List<String>;
          isLoading = false;
        });
      }

      print('✅ تم تحميل ${availableItems.length} صنف أساسي لطلب المواد');
    } catch (e) {
      print('❌ خطأ في تحميل الأصناف الأساسية لطلب المواد: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // البحث المحلي السريع
  void _searchLocally() {
    final query = searchController.text.trim();
    final group = selectedItemGroup;

    setState(() {
      _isSearching = false;
      filteredItems = ItemService.searchItemsLocally(
        query: query,
        items: availableItems,
        itemGroup: group,
      );
    });
  }

  // البحث على السيرفر
  Future<void> _searchOnServer() async {
    final query = searchController.text.trim();
    final group = selectedItemGroup;

    if (query.isEmpty && group == null) {
      setState(() {
        filteredItems = availableItems;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final searchResults = await ItemService.getItemsWithSearch(
        query: query,
        itemGroup: group,
        limit: 50,
      );

      if (mounted) {
        setState(() {
          filteredItems = searchResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في البحث على السيرفر: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  // معالج تغيير البحث مع debounce
  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();

    // البحث المحلي فوراً
    _searchLocally();

    // البحث على السيرفر بعد 800ms
    _searchDebounceTimer = Timer(Duration(milliseconds: 800), () {
      _searchOnServer();
    });
  }

  // تحميل المزيد من الأصناف
  Future<void> _loadMoreItems() async {
    if (_isLoadingMore || !_hasMoreItems) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final query = searchController.text.trim();
      final group = selectedItemGroup;

      final moreItems = await ItemService.getItemsPaginated(
        query: query.isEmpty ? null : query,
        itemGroup: group,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          if (moreItems.isNotEmpty) {
            filteredItems.addAll(moreItems);
            _currentPage++;
            _hasMoreItems = moreItems.length == _pageSize;
          } else {
            _hasMoreItems = false;
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل المزيد من الأصناف: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  // تحميل الأصناف حسب المجموعة
  Future<void> _loadItemsByGroup() async {
    if (selectedItemGroup == null) {
      setState(() {
        filteredItems = availableItems;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final groupItems = await ItemService.getItemsByGroup(
        itemGroup: selectedItemGroup!,
      );

      if (mounted) {
        setState(() {
          filteredItems = groupItems;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل الأصناف حسب المجموعة: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
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
              Text('ابحث عن صنف', style: TextStyle(color: primaryColor)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SearchBar(
                  controller: searchController,
                  hintText: 'ادخل اسم الصنف...',
                  leading: Icon(Icons.search),
                  onChanged: (value) {
                    _onSearchChanged();
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
              tooltip: 'بحث عن صنف',
              onPressed: () {
                _showSearchDialog();
              },
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: selectedItemGroup,
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
                });
                _loadItemsByGroup();
              },
            ),
          ),
        ],
      ),
    );
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
      MessageService.showError(context, 'يرجى إختيار تاريخ المطلوب');
      return;
    }

    if (selectedItems.isEmpty) {
      MessageService.showError(context, 'يرجى إضافة أصناف على الأقل');
      return;
    }
    print(selectedItems);
    try {
      await Future.delayed(Duration(milliseconds: 2000));

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

      MessageService.showSuccess(context, 'تم إرسال طلب المواد بنجاح');

      Navigator.pop(context, true);
      Navigator.pop(context, true);
    } catch (e) {
      print(e);
      MessageService.showError(context, 'خطأ أثناء الإرسال: $e');
    }
  }

  Widget _buildRequestInfoCard() {
    return StatefulBuilder(
      builder: (context, setModalState) {
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
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    items:
                        requestReasons.map((reason) {
                          return DropdownMenuItem(
                            value: reason,
                            child: Text(reason),
                          );
                        }).toList(),
                    onChanged: null, // غير نشط بوضوح
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
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() => scheduleDate = picked);
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
                      initialValue: selectedWarehouse,
                      items:
                          availableWarehouses.map((w) {
                            return DropdownMenuItem(
                              value: w,
                              child: Text(w.name),
                            );
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
      },
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
              child:
                  _isSearching
                      ? Center(child: _buildSearchIndicator())
                      : filteredItems.isEmpty
                      ? Center(child: _buildNoResultsMessage())
                      : NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          if (scrollInfo.metrics.pixels ==
                              scrollInfo.metrics.maxScrollExtent) {
                            if (!_isLoadingMore && _hasMoreItems) {
                              _loadMoreItems();
                            }
                          }
                          return false;
                        },
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.8,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemCount:
                              filteredItems.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == filteredItems.length) {
                              // عرض مؤشر التحميل في المنتصف
                              return Container(
                                alignment: Alignment.center,
                                child: _buildLoadMoreIndicator(),
                              );
                            }
                            final item = filteredItems[index];
                            return _buildItemCard(item);
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Item item) {
    // Build image URL
    String? fullImageUrl;
    print("image = $item");
    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      String imagePath = item.imageUrl!;
      print("imagePath = $imagePath");
      if (!imagePath.startsWith('/')) {
        imagePath = '/$imagePath';
      }
      fullImageUrl = 'https://demo2.ababeel.ly$imagePath';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _addToSelectedItems(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 195,
              color: Colors.grey.shade200,
              child: Stack(
                children: [
                  // Background image
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
                              : FadeInImage.assetNetwork(
                                placeholder: 'assets/images/placeholder.png',
                                image: fullImageUrl,
                                fit: BoxFit.cover,
                                imageErrorBuilder: (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return Image.asset(
                                    'assets/images/placeholder.png',
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                    ),
                  ),

                  // Overlay: item name + code + uom
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
                            item.itemName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _buildItemDetails(item),
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

  Widget _buildItemDetails(Item item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            item.uom,
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

  int calculateTotalQuantity() {
    return selectedItems.fold(
      0,
      (sum, item) => sum + (item['quantity'] as int),
    );
  }

  Widget _buildSelectedItemsSheet(
    BuildContext context,
    ScrollController scrollController,
  ) {
    return StatefulBuilder(
      builder: (context, setModalState) {
        // دالة لتحديث السلة
        void updateCart() {
          setModalState(() {});
          setState(() {});
        }

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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
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
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
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
                                        () => _showItemDetails(
                                          context,
                                          item,
                                          index,
                                          () {
                                            setModalState(() {});
                                            setState(() {});
                                          },
                                        ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: primaryColor
                                              .withOpacity(0.2),
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
                                                setModalState(() {});
                                              },
                                            ),

                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                              icon: const Icon(
                                                Icons.add,
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  selectedItems[index]['quantity']++;
                                                });
                                                setModalState(() {});
                                              },
                                            ),

                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              onPressed: () {
                                                _removeItem(index);
                                                setModalState(() {});
                                              },
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
                          (selectedItems.isEmpty || _isSubmitting)
                              ? null
                              : () async {
                                setModalState(() {
                                  _isSubmitting = true;
                                });
                                _saveMaterialRequest();
                              },
                      child:
                          _isSubmitting
                              ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : Text(
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // if (hasInternet == null) {
    //   return Scaffold(body: Center(child: CircularProgressIndicator()));
    // }

    if (hasInternet == false) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('طلب مواد جديد'),
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
                  _fetchProfileAndInitialize();
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
      floatingActionButton: Stack(
        children: [
          FloatingActionButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) {
                  return DraggableScrollableSheet(
                    expand: false,
                    maxChildSize: 0.9,
                    minChildSize: 0.4,
                    builder: (context, scrollController) {
                      return _buildSelectedItemsSheet(
                        context,
                        scrollController,
                      );
                    },
                  );
                },
              );
            },
            backgroundColor: Color(0xFF60B245),
            child: Icon(Icons.shopping_cart, color: Color(0xffffffff)),
          ),
          if (selectedItems.isNotEmpty)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
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
            ),
        ],
      ),

      appBar: AppBar(
        title: const Text('طلب مواد جديد'),
        centerTitle: true,

        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(25),
            bottomLeft: Radius.circular(25),
          ),
        ),
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
          Column(
            children: [_buildFilterSection(), _buildAvailableItemsSection()],
          ),
        ],
      ),
    );
  }

  Future<void> _showItemDetails(
    BuildContext context,
    dynamic item,
    int index, [
    VoidCallback? onUpdate,
  ]) async {
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
                        setState(() {}); // تحديث السلة الرئيسية
                        onUpdate?.call(); // تحديث السلة المفتوحة
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: currentSelectedUnit,
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
                        setState(() {}); // تحديث السلة الرئيسية
                        onUpdate?.call(); // تحديث السلة المفتوحة
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
                          onUpdate?.call(); // تحديث السلة المفتوحة
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

        // قسم التصفية في شاشة التحميل
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
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.21,
            color: Colors.grey[300],
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Container(color: Colors.grey[300]),
                  ),
                ),
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
                        Container(
                          height: 12,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              height: 8,
                              width: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Container(
                              height: 8,
                              width: 30,
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
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
        ],
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

  // مؤشر البحث محسن
  Widget _buildSearchIndicator() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(20),
        margin: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // دائرة التحميل المتحركة
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 3,
                backgroundColor: primaryColor.withOpacity(0.1),
              ),
            ),
            SizedBox(height: 12),
            // النص
            Text(
              'جاري البحث...',
              style: TextStyle(
                fontSize: 13,
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            // نص فرعي
            Text(
              'يرجى الانتظار',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // رسالة عدم وجود نتائج محسنة
  Widget _buildNoResultsMessage() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(24),
        margin: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // أيقونة مع تأثير
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 36,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 16),
            // النص الرئيسي
            Text(
              'لا توجد نتائج',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            // نص فرعي
            Text(
              'جرب تغيير كلمات البحث',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            // نص إضافي
            Text(
              'أو اختر مجموعة مختلفة',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[400],
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // مؤشر تحميل المزيد محسن
  Widget _buildLoadMoreIndicator() {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
          border: Border.all(color: primaryColor.withOpacity(0.1), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // أيقونة التحميل المتحركة
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 2,
                backgroundColor: primaryColor.withOpacity(0.1),
              ),
            ),
            SizedBox(width: 8),
            // النص المختصر
            Flexible(
              child: Text(
                'جاري التحميل...',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: primaryColor,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
