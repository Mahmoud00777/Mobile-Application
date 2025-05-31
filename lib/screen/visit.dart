import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/visit.dart';
import '../services/visit_service.dart';

class VisitScreen extends StatefulWidget {
  const VisitScreen({super.key});

  @override
  State<VisitScreen> createState() => _VisitScreenState();
}

class _VisitScreenState extends State<VisitScreen> {
  late Future<List<Visit>> _visitsFuture;
  String _filterOption = 'all';
  final ScrollController _scrollController = ScrollController();
  final Color primaryColor = const Color(0xFFBDB395);
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = const Color(0xFFF6F0F0);
  final Color pressedColor = const Color(0xFFF2E2B1);
  bool _isMounted = false;
  File? _imageFile;
  Position? _currentPosition;
  final TextEditingController _noteController = TextEditingController();
  final bool _isVisitCompleted = false;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _refreshVisits();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  Future<void> _refreshVisits() async {
    if (!mounted) return; // التحقق من أن الويدجت ما زالت موجودة

    setState(() {
      _visitsFuture = VisitService.getVisits();
    });
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled || !mounted) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || !mounted) return;
      }

      if (permission == LocationPermission.deniedForever || !mounted) return;

      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  // ignore: unused_element
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _showAddVisitForm({required Visit visit}) async {
    // متغيرات النموذج المؤقتة
    File? imageFile;
    bool isVisitCompleted = false;
    final TextEditingController noteController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: backgroundColor,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Future<void> pickImage() async {
              FocusScope.of(context).unfocus();
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(
                source: ImageSource.gallery,
              );
              if (pickedFile != null) {
                setModalState(() => imageFile = File(pickedFile.path));
              }
            }

            return GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'إضافة زيارة جديدة',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Image Picker
                    GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: secondaryColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child:
                            imageFile == null
                                ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt, color: primaryColor),
                                    const SizedBox(height: 8),
                                    Text(
                                      'إضافة صورة',
                                      style: TextStyle(color: primaryColor),
                                    ),
                                  ],
                                )
                                : ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    imageFile!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: secondaryColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child:
                                _isLoadingLocation
                                    ? const Text('جاري تحديد الموقع...')
                                    : Text(
                                      _currentPosition == null
                                          ? 'لم يتم تحديد الموقع'
                                          : '${_currentPosition!.latitude.toStringAsFixed(4)}, '
                                              '${_currentPosition!.longitude.toStringAsFixed(4)}',
                                    ),
                          ),
                          IconButton(
                            icon: Icon(Icons.refresh, color: primaryColor),
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              _getCurrentLocation();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Visit Status
                    SwitchListTile(
                      title: Text(
                        'حالة الزيارة',
                        style: TextStyle(color: primaryColor),
                      ),
                      subtitle: Text(
                        isVisitCompleted ? 'تمت الزيارة' : 'لم تتم',
                        style: TextStyle(
                          color: isVisitCompleted ? Colors.green : Colors.red,
                        ),
                      ),
                      value: isVisitCompleted,
                      onChanged: (value) {
                        FocusScope.of(context).unfocus();
                        setModalState(() => isVisitCompleted = value);
                      },
                      activeColor: Colors.green,
                      inactiveTrackColor: Colors.red.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),

                    // Note
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          FocusScope.of(context).unfocus();

                          if (_currentPosition == null || imageFile == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'الرجاء إضافة صورة والتأكد من تحديد الموقع',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          // try {
                          //   final imageUrl = await VisitService.uploadImage(
                          //     imageFile!,
                          //   );
                          //   final visit = Visit(
                          //     latitude: _currentPosition!.latitude,
                          //     longitude: _currentPosition!.longitude,
                          //     image: imageUrl,
                          //     note: noteController.text,
                          //     visit: isVisitCompleted,
                          //     customer: '',
                          //     posProfile: '',
                          //     posOpeningShift: '',
                          //     dateTime: DateTime(Timeline.now),
                          //     select_state: '',
                          //     name: '',
                          //   );

                          //   await VisitService.saveVisit(visit);

                          //   Navigator.pop(context);
                          //   _refreshVisits();

                          //   ScaffoldMessenger.of(context).showSnackBar(
                          //     SnackBar(
                          //       content: const Text('تم حفظ الزيارة بنجاح'),
                          //       backgroundColor: Colors.green[400],
                          //     ),
                          //   );
                          // } catch (e) {
                          //   ScaffoldMessenger.of(context).showSnackBar(
                          //     SnackBar(
                          //       content: Text('خطأ في الحفظ: ${e.toString()}'),
                          //       backgroundColor: Colors.red,
                          //     ),
                          //   );
                          // }
                        },
                        child: const Text(
                          'حفظ الزيارة',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
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

  Future<List<Visit>> _getFilteredVisits() async {
    final visits = await _visitsFuture;
    return visits.where((visit) {
      if (_filterOption == 'all') return true;
      return visit.select_state == _filterOption;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الزيارات'),
        backgroundColor: primaryColor,
        centerTitle: true,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(25),
            bottomLeft: Radius.circular(25),
          ),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: _refreshVisits,
        child: FutureBuilder<List<Visit>>(
          future: _getFilteredVisits(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'حدث خطأ في تحميل البيانات',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _refreshVisits,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            }

            final visits = snapshot.data!;

            if (visits.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.assignment, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد زيارات مسجلة',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    // ElevatedButton(
                    //   onPressed: _showAddVisitForm,
                    //   child: const Text('إضافة زيارة جديدة'),
                    // ),
                  ],
                ),
              );
            }

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: visits.length,
              itemBuilder: (context, index) {
                return _buildVisitItem(visits[index]);
              },
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // FloatingActionButton(
          //   heroTag: 'addBtn',
          //   onPressed: _showAddVisitForm,
          //   backgroundColor: primaryColor,
          //   child: const Icon(Icons.add, color: Colors.white),
          // ),
          // const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'filterBtn',
            onPressed: () => _showFilterOptions(context),
            backgroundColor: Colors.white,
            child: const Icon(Icons.filter_alt, color: Colors.black),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'فلترة الزيارات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildFilterOption('الكل', 'all', Icons.all_inclusive),
              _buildFilterOption(
                'لم تتم زيارة',
                'لم تتم زيارة',
                Icons.pending_actions,
                Colors.orange,
              ),
              _buildFilterOption(
                'تمت زيارة',
                'تمت زيارة',
                Icons.check_circle,
                Colors.green,
              ),
              _buildFilterOption(
                'فاتورة',
                'فاتورة',
                Icons.receipt,
                Colors.blue,
              ),
              _buildFilterOption(
                'ايصال قبض',
                'ايصال قبض',
                Icons.payment,
                Colors.purple,
              ),
              _buildFilterOption(
                'فاتورة + ايصال قبض',
                'فاتورة + ايصال قبض',
                Icons.receipt_long,
                Colors.indigo,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(
    String title,
    String value,
    IconData icon, [
    Color? iconColor,
  ]) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      trailing:
          _filterOption == value
              ? Icon(Icons.check, color: primaryColor)
              : null,
      onTap: () {
        setState(() {
          _filterOption = value;
        });
        Navigator.pop(context);
      },
      tileColor: _filterOption == value ? primaryColor.withOpacity(0.1) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildVisitItem(Visit visit) {
    Color getStatusColor(String status) {
      switch (status) {
        case 'تمت زيارة':
          return Colors.green;
        case 'لم تتم زيارة':
          return Colors.orange;
        case 'فاتورة':
          return Colors.blue;
        case 'ايصال قبض':
          return Colors.purple;
        case 'فاتورة + ايصال قبض':
          return Colors.indigo;
        default:
          return Colors.grey;
      }
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showVisitDetailsBottomSheet(context, visit),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // صورة الزيارة
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[100],
                ),
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[100],
                  ),
                  child: _buildVisitImage(
                    visit.image,
                  ), // استدعاء دالة مساعدة لعرض الصورة
                ),
              ),
              const SizedBox(width: 12),

              // تفاصيل الزيارة
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // الملاحظات وحالة الزيارة
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            visit.note.isNotEmpty ? visit.note : 'بدون ملاحظات',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: getStatusColor(
                              visit.select_state,
                            ).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            visit.select_state,
                            style: TextStyle(
                              color: getStatusColor(visit.select_state),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // الموقع إن وجد
                    if (visit.latitude != null && visit.longitude != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${visit.latitude}°, ${visit.longitude}°',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    Text('العميل: ${visit.customer}'),

                    if (visit.posProfileName != null)
                      Text('ملف البيع: ${visit.posProfileName}'),

                    Text('الوردية: ${visit.posOpeningShift}'),
                    Text('الحالة: ${visit.select_state}'),
                    Text(
                      'التاريخ: ${DateFormat('yyyy-MM-dd – HH:mm').format(visit.dateTime)}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVisitDetailsBottomSheet(BuildContext context, Visit visit) {
    // ننقل متغيرات التعديل هنا
    final TextEditingController noteController = TextEditingController(
      text: visit.note,
    );
    String selectedState = visit.select_state;
    bool isModified = false;
    bool isCheckingLocation = false;
    print('_showVisitDetailsBottomSheet => visit: ${visit.name}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header مع زر الإغلاق فقط
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'تفاصيل وتعديل الزيارة',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // حقل حالة الزيارة (قابل للتعديل)
                          DropdownButtonFormField<String>(
                            value: selectedState,
                            decoration: InputDecoration(
                              labelText: 'حالة الزيارة',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                [
                                  'لم تتم زيارة',
                                  'تمت زيارة',
                                  'فاتورة',
                                  'ايصال قبض',
                                  'فاتورة + ايصال قبض',
                                ].map((String value) {
                                  return DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              setModalState(() {
                                selectedState = value!;
                                isModified = true;
                              });
                            },
                          ),
                          SizedBox(height: 16),

                          // حقل الملاحظات (قابل للتعديل)
                          TextField(
                            controller: noteController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'ملاحظات',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              setModalState(() => isModified = true);
                            },
                          ),
                          SizedBox(height: 16),

                          _buildReadOnlyInfo(
                            'الموقع',
                            visit.latitude != null && visit.longitude != null
                                ? '${visit.latitude}, ${visit.longitude}'
                                : 'غير متوفر',
                          ),
                          _buildReadOnlyInfo('العميل', visit.customer),
                          _buildReadOnlyInfo('الوردية', visit.posOpeningShift),
                          _buildReadOnlyInfo(
                            'التاريخ',
                            DateFormat(
                              'yyyy-MM-dd HH:mm',
                            ).format(visit.dateTime),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // زر التحقق من الموقع
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.location_on),
                      label: Text('تمت زيارة - التحقق من الموقع'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color.fromARGB(255, 52, 117, 54),
                        minimumSize: Size(double.infinity, 50),
                      ),
                      onPressed: () async {
                        setModalState(() => isCheckingLocation = true);
                        await _verifyVisitLocation(
                          context,
                          visit,
                          setModalState,
                          (newState) {
                            setModalState(() => selectedState = newState);
                          },
                          (modified) {
                            setModalState(() => isModified = modified);
                          },
                        );
                        setModalState(() => isCheckingLocation = false);
                      },
                    ),
                  ),

                  // مؤشر تحميل عند التحقق من الموقع
                  if (isCheckingLocation)
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    ),

                  // زر الحفظ في الأسفل
                  if (isModified)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.save),
                        label: Text('حفظ'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white, //
                          backgroundColor: Color(0xFFBDB395),
                          minimumSize: Size(double.infinity, 50),
                        ),
                        onPressed: () async {
                          final updatedVisit = visit.copyWith(
                            note: noteController.text,
                            select_state: selectedState,
                          );
                          await VisitService.updateVisit(updatedVisit);
                          Navigator.pop(context);
                          _refreshVisits();
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReadOnlyInfo(String title, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey, fontSize: 14)),
          SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildVisitImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return const Icon(Icons.image, size: 30, color: Colors.grey);
    }
    print('imageUrl =======$imageUrl');
    try {
      final fullUrl =
          imageUrl.startsWith('http')
              ? imageUrl
              : 'https://demo2.ababeel.ly/$imageUrl';
      print('fullUrl =======$fullUrl');

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          fullUrl,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value:
                    loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Error loading image: $error');
            return const Icon(Icons.broken_image, size: 30);
          },
        ),
      );
    } catch (e) {
      print('Image loading exception: $e');
      return const Icon(Icons.image_not_supported, size: 30);
    }
  }
}

Future<void> _verifyVisitLocation(
  BuildContext context,
  Visit visit,
  StateSetter setModalState,
  // أضف المتغيرات كمعاملات للدالة
  Function(String) updateSelectedState,
  Function(bool) updateIsModified,
) async {
  try {
    // double? visitLat =
    //     visit.latitude != null ? _dmsToDecimal(visit.latitude!) : null;
    // double? visitLng =
    //     visit.longitude != null ? _dmsToDecimal(visit.longitude!) : null;
    final double? visitLat = double.tryParse(visit.latitude!);
    final double? visitLng = double.tryParse(visit.longitude!);
    final Position currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    print("-------------------------$currentPosition");
    // if (visitLat == null || visitLng == null) {
    //   print("no visit");
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('لا توجد إحداثيات مخزنة لهذه الزيارة')),
    //   );
    //   return;
    // }
    print('visitLat = $visitLat');
    print('visitLng = $visitLng');
    print('currentPosition.latitude = ${currentPosition.latitude}');
    print('currentPosition.longitude =${currentPosition.longitude}');

    final double distance = Geolocator.distanceBetween(
      visitLat!,
      visitLng!,
      currentPosition.latitude,
      currentPosition.longitude,
    );
    print("visit222");

    const double acceptableDistance = 200;
    print('distance = $distance');
    if (distance <= acceptableDistance) {
      // استخدم الدوال الممررة لتعديل الحالة
      updateSelectedState('تمت زيارة');
      updateIsModified(true);
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text("نجاح"),
              content: Text(
                "تم التحقق من الموقع بنجاح - المسافة: ${distance.toStringAsFixed(1)} متر",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    updateSelectedState('تمت زيارة');
                    updateIsModified(true);
                  },
                  child: Text("موافق"),
                ),
              ],
            ),
      );
    } else {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text("تحذير"),
              content: Text(
                "أنت بعيد عن موقع الزيارة (${distance.toStringAsFixed(1)} متر)",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("حاول مرة أخرى"),
                ),
              ],
            ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('خطأ في تحديد الموقع: ${e.toString()}')),
    );
  }
}

double? _dmsToDecimal(String dms) {
  try {
    // إزالة الرموز الزائدة
    String cleaned = dms
        .replaceAll('°', ' ')
        .replaceAll('\'', ' ')
        .replaceAll('"', ' ');
    List<String> parts = cleaned.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty) return null;

    double degrees = double.tryParse(parts[0]) ?? 0;
    double minutes = parts.length > 1 ? double.tryParse(parts[1]) ?? 0 : 0;
    double seconds = parts.length > 2 ? double.tryParse(parts[2]) ?? 0 : 0;

    // التحويل إلى درجات عشرية
    double decimal = degrees + (minutes / 60) + (seconds / 3600);

    // تحديد الاتجاه (إذا كان هناك جزء رابع مثل N/S/E/W)
    if (parts.length > 3) {
      String direction = parts[3].toUpperCase();
      if (direction == 'S' || direction == 'W') {
        decimal = -decimal;
      }
    }

    return decimal;
  } catch (e) {
    debugPrint('خطأ في تحويل الإحداثيات: $e');
    return null;
  }
}
