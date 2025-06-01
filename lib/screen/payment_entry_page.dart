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
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadModes();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadModes() async {
    try {
      final modes = await PaymentEntryService.fetchModesOfPayment();
      if (mounted) {
        setState(() {
          _modes = modes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل طرق الدفع: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickMode() async {
    if (_modes.isEmpty) return;

    final choice = await showModalBottomSheet<Map<String, String>>(
      context: context,
      builder:
          (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'اختر طريقة الدفع',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _modes.length,
                  itemBuilder: (ctx, index) {
                    final mode = _modes[index];
                    return ListTile(
                      title: Text(mode['mode']!),
                      subtitle:
                          mode['account'] != null
                              ? Text(mode['account']!)
                              : null,
                      trailing: Text(mode['currency'] ?? ''),
                      onTap: () => Navigator.pop(ctx, mode),
                    );
                  },
                ),
              ),
            ],
          ),
    );

    if (choice != null && mounted) {
      setState(() {
        _selectedMode = choice['mode'];
        _selectedAccount = choice['account'];
        _selectedCurrency = choice['currency'];
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار طريقة الدفع')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            width: overlay.size.width,
            height: overlay.size.height,
            child: ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('جاري حفظ البيانات...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );

    Overlay.of(context).insert(overlayEntry);

    try {
      final amount = double.parse(_amountCtrl.text);
      final entry = PaymentEntry(
        paymentType: 'Receive',
        namingSeries: 'PE-${DateTime.now().millisecondsSinceEpoch}',
        company: 'HR',
        modeOfPayment: _selectedMode!,
        partyType: 'Customer',
        party: widget.customerName,
        partyName: widget.customerName,
        paidFrom: '1310 - مدينون - HR',
        paidFromAccountCurrency: 'LYD',
        paidTo: _selectedAccount!,
        paidToAccountCurrency: _selectedCurrency!,
        referenceDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        receivedAmount: amount,
        paidAmount: amount,
        referenceNo: _refNoCtrl.text,
        title: widget.customerName,
        remarks: '',
      );

      await PaymentEntryService.createPayment(entry);
      overlayEntry.remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text('تم الحفظ بنجاح'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      overlayEntry.remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('سداد ${widget.customerName}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('سداد ${widget.customerName}')),
      body: SingleChildScrollView(
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
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'أدخل المبلغ';
                  final amount = double.tryParse(v);
                  if (amount == null) return 'رقم غير صالح';
                  if (amount <= 0) return 'يجب أن يكون المبلغ أكبر من الصفر';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _refNoCtrl,
                decoration: const InputDecoration(
                  labelText: 'رقم الإشارة (اختياري)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickMode,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'طريقة الدفع',
                    border: const OutlineInputBorder(),
                    errorText:
                        _selectedMode == null && _isSubmitting ? 'مطلوب' : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedMode ?? 'اختر طريقة الدفع',
                        style: TextStyle(
                          color:
                              _selectedMode == null
                                  ? Theme.of(context).hintColor
                                  : null,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon:
                    _isSubmitting
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.save),
                label: const Text('حفظ الدفعة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
