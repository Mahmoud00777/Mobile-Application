import 'package:drsaf/Class/message_service.dart';
import 'package:drsaf/services/payment_service_list.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer.dart';
import '../models/customer_outstanding.dart';
import '../models/payment_entry.dart';
import '../services/customer_service.dart';
import '../services/customer_outstanding_service.dart';
import '../services/payment_entry_service.dart';

class CreatePaymentPage extends StatefulWidget {
  const CreatePaymentPage({super.key});

  @override
  _CreatePaymentPageState createState() => _CreatePaymentPageState();
}

class _CreatePaymentPageState extends State<CreatePaymentPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _paidAmountCtrl = TextEditingController();

  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];
  bool _showList = false;

  Customer? _selectedCustomer;
  CustomerOutstanding? _selectedBalance;
  List<Map<String, String>> _modes = [];
  String? _selectedMode;
  String? _selectedAccount;
  String? _selectedCurrency;
  bool _modesLoading = true;
  List<Map<String, dynamic>> _paymentMethods = [];
  bool _isLoading = true;
  String? _selectedMethod;
  String? _errorMessage;
  final Color primaryColor = Color(0xFF60B245);
  final Color secondaryColor = Color(0xFFFFFFFF);
  final Color backgroundColor = Color(0xFFF2F2F2);
  final Color blackColor = Color(0xFF383838);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterCustomers);
    _loadModes();
    _loadPaymentMethods();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCustomers);
    _searchController.dispose();
    _paidAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadModes() async {
    try {
      _modes = await PaymentEntryService.fetchModesOfPayment();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في تحميل طرق الدفع: \$e')));
    } finally {
      setState(() => _modesLoading = false);
    }
  }

  void _filterCustomers() {
    final query = _searchController.text.toLowerCase();
    final filtered =
        _allCustomers.where((customer) {
          final name = customer.customerName.toLowerCase() ?? '';
          return name.contains(query);
        }).toList();

    setState(() {
      _filteredCustomers = filtered;
    });
  }

  Future<void> _loadCustomers() async {
    try {
      final customers = await CustomerService.getCustomers();
      setState(() {
        _allCustomers = customers;
        _filteredCustomers = customers;
        _showList = true;
      });
    } catch (e) {
      print('Error loading customers: \$e');
    }
  }

  Future<void> _loadPaymentMethods() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final methods = await PaymentService.getPosPaymentMethods();
      setState(() {
        _paymentMethods = methods;
        if (methods.isNotEmpty) {
          // _selectedMethod = methods.first['mode_of_payment']?.toString();
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'فشل في تحميل طرق الدفع: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectPaymentMethod() async {
    if (_paymentMethods.isEmpty) return;

    final selectedMode = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => _buildMethodsBottomSheet(),
    );

    if (selectedMode != null) {
      setState(() => _isLoading = true);

      try {
        final defaultAccount = await PaymentService.getDefaultAccount(
          selectedMode,
        );

        setState(() {
          _selectedMethod = selectedMode;
          _selectedAccount = defaultAccount;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'فشل في جلب الحساب الافتراضي';
        });
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildMethodsBottomSheet() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'اختر طريقة الدفع',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const Divider(height: 1),
        ..._paymentMethods.map(
          (method) => ListTile(
            leading: Icon(_getMethodIcon(method['type'])),
            title: Text(method['mode_of_payment'] ?? 'غير معروف'),
            subtitle:
                method['description'] != null
                    ? Text(method['description'])
                    : null,
            onTap: () => Navigator.pop(context, method['mode_of_payment']),
          ),
        ),
      ],
    );
  }

  IconData _getMethodIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'card':
        return Icons.credit_card;
      case 'bank':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  Future<void> _onCustomerSelected(Customer customer) async {
    setState(() {
      _selectedCustomer = customer;
      _showList = false;
      _searchController.text = customer.customerName ?? customer.name ?? '';
      _selectedBalance = null;
    });

    try {
      final balance = await CustomerOutstandingService.fetchCustomerOutstanding(
        customer.name ?? '',
        DateTime.now().toIso8601String().substring(0, 10),
      );
      setState(() {
        _selectedBalance = balance;
      });
    } catch (e) {
      print('Error fetching balance: \$e');
      setState(() => _selectedBalance = null);
    }
  }

  Future<void> _pickMode() async {
    final choice = await showModalBottomSheet<Map<String, String>>(
      context: context,
      builder:
          (ctx) => ListView(
            children:
                _modes
                    .map(
                      (m) => ListTile(
                        title: Text(m['mode']!),
                        onTap: () => Navigator.pop(ctx, m),
                      ),
                    )
                    .toList(),
          ),
    );
    if (choice != null) {
      setState(() {
        _selectedMode = choice['mode'];
        _selectedAccount = choice['account'];
        _selectedCurrency = choice['currency'];
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedCustomer == null) {
      MessageService.showWarning(context, 'يرجى تحديد العميل');
      return;
    }
    if (_selectedMethod == null) {
      MessageService.showWarning(context, 'يرجى تحديد طريقة الدفع');
      return;
    }

    final text = _paidAmountCtrl.text;
    if (text.isEmpty || double.tryParse(text) == null) return;

    final amount = double.parse(text);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final series = 'PE-\$timestamp';

    final entry = PaymentEntry(
      paymentType: 'Receive',
      namingSeries: '',
      company: 'HR',
      modeOfPayment: _selectedMethod!,
      partyType: 'Customer',
      party: _selectedCustomer!.name,
      partyName: _selectedCustomer!.customerName,
      paidFrom: '1310 - مدينون - HR',
      paidFromAccountCurrency: 'LYD',
      paidTo: _selectedAccount!,
      referenceNo: 'null',
      paidToAccountCurrency: 'LYD',
      referenceDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      receivedAmount: amount,
      paidAmount: amount,
      title: _selectedCustomer!.customerName,
      remarks: '',
    );

    try {
      await PaymentEntryService.createPayment(entry);
      MessageService.showSuccess(context, 'تم إنشاء الدفعة بنجاح');
      Navigator.pop(context);
    } catch (e) {
      MessageService.showError(context, 'خطأ في الحفظ: \$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('إنشاء دفعة'), backgroundColor: primaryColor),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'ابحث عن عميل',
                labelStyle: TextStyle(color: primaryColor),
                suffixIcon: Icon(Icons.search, color: primaryColor),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
                ),
              ),
              cursorColor: primaryColor,
              onTap: () {
                if (!_showList) _loadCustomers();
              },
            ),
            if (_showList)
              Expanded(
                child:
                    _filteredCustomers.isEmpty
                        ? Center(
                          child: Text(
                            'لا يوجد عملاء',
                            style: TextStyle(color: primaryColor),
                          ),
                        )
                        : ListView.builder(
                          itemCount: _filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = _filteredCustomers[index];
                            return ListTile(
                              title: Text(
                                customer.customerName ?? customer.name ?? '',
                                style: TextStyle(color: primaryColor),
                              ),
                              onTap: () => _onCustomerSelected(customer),
                              trailing: Icon(Icons.person, color: primaryColor),
                            );
                          },
                        ),
              )
            else if (_selectedCustomer != null) ...[
              // Text(
              //   'العميل المختار:',
              //   style: TextStyle(
              //     fontWeight: FontWeight.bold,
              //     color: primaryColor,
              //     fontSize: 16,
              //   ),
              // ),

              // SizedBox(height: 8),
              // Text(_selectedCustomer!.customerName),
              // SizedBox(height: 16),
              // Outstanding
              if (_selectedBalance != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الرصيد المستحق:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        fontSize: 16,
                      ),
                    ),

                    SizedBox(height: 8),
                    Text(_selectedBalance!.outstanding.toStringAsFixed(2)),
                    SizedBox(height: 16),
                    // Mode of Payment picker
                    _isLoading
                        ? const CircularProgressIndicator()
                        : _paymentMethods.isEmpty
                        ? const Text('لا توجد طرق دفع متاحة')
                        : GestureDetector(
                          onTap: _selectPaymentMethod,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedMethod ?? 'اختر طريقة الدفع',
                                  style: TextStyle(
                                    color:
                                        _selectedMethod == null
                                            ? Colors.grey
                                            : Colors.black,
                                  ),
                                ),

                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                          ),
                        ),
                    SizedBox(height: 16),
                    // Paid amount field
                    TextField(
                      controller: _paidAmountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'المبلغ المدفوع',
                        labelStyle: TextStyle(color: primaryColor),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryColor, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      cursorColor: primaryColor,
                    ),

                    SizedBox(height: 35),
                    // Submit button
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        minimumSize: Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),

                      child: Text(
                        'إرسال',
                        style: TextStyle(fontSize: 18, color: secondaryColor),
                      ),
                    ),
                  ],
                )
              else
                Text('جاري التحميل ...'),
            ],
          ],
        ),
      ),
    );
  }
}
