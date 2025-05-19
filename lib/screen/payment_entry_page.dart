import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payment_entry.dart';
import '../../services/payment_entry_service.dart';

class PaymentEntryPage extends StatefulWidget {
  final String customerName;
  const PaymentEntryPage({super.key, required this.customerName});

  @override
  _PaymentEntryPageState createState() => _PaymentEntryPageState();
}

class _PaymentEntryPageState extends State<PaymentEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _refNoCtrl = TextEditingController();

  List<Map<String, String>> _modes = [];
  String? _selectedMode;
  String? _selectedAccount;
  String? _selectedCurrency;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadModes();
  }

  Future<void> _loadModes() async {
    try {
      _modes = await PaymentEntryService.fetchModesOfPayment();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في تحميل طرق الدفع: $e')));
    } finally {
      setState(() => _loading = false);
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

  void _submit() async {
    if (!_formKey.currentState!.validate() || _selectedMode == null) return;

    final amount = double.parse(_amountCtrl.text);
    final entry = PaymentEntry(
      paymentType: 'Receive',
      namingSeries: 'PE-${DateTime.now().millisecondsSinceEpoch}',
      company: 'HR',
      modeOfPayment: _selectedMode!,
      partyType: 'Customer',
      party: widget.customerName,
      partyName: widget.customerName,
      paidFrom: '1310 - مدينون - HR', // fixed account
      paidFromAccountCurrency: 'LYD', // fixed currency
      paidTo: _selectedAccount!, // selected mode account
      paidToAccountCurrency: _selectedCurrency!, // selected mode currency
      referenceDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      receivedAmount: amount,
      paidAmount: amount,
      referenceNo: _refNoCtrl.text,
      title: widget.customerName,
      remarks: '',
    );

    try {
      await PaymentEntryService.createPayment(entry);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في الحفظ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text('سداد ${widget.customerName}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'المبلغ المستلم',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'أدخل المبلغ';
                  if (double.tryParse(v) == null) return 'رقم غير صالح';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _refNoCtrl,
                decoration: const InputDecoration(
                  labelText: 'رقم الإشارة (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickMode,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'طريقة الدفع',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_selectedMode ?? 'اختر طريقة الدفع'),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
