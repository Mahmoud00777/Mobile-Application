import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drsaf/services/pos_service.dart';
import 'package:drsaf/screen/home.dart';

class PosOpeningPage extends StatefulWidget {
  const PosOpeningPage({super.key});

  @override
  State<PosOpeningPage> createState() => _PosOpeningPageState();
}

class _PosOpeningPageState extends State<PosOpeningPage> {
  final TextEditingController _cashController = TextEditingController();
  List<Map<String, dynamic>> posProfiles = [];
  Map<String, dynamic>? selectedPOSProfile;
  String? selectedPOSProfileName;

  @override
  void initState() {
    super.initState();
    _loadPOSProfiles();
  }

  Future<void> _loadPOSProfiles() async {
    try {
      final profiles = await PosService.getUserPOSProfiles();
      setState(() {
        posProfiles = profiles;
      });
      await _loadSavedPOSProfile();
    } catch (e) {
      print('خطأ في تحميل POS Profiles: $e');
    }
  }

  Future<void> _loadSavedPOSProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('selected_pos_profile');
    if (saved != null) {
      final decoded = jsonDecode(saved);
      setState(() {
        selectedPOSProfile = decoded;
      });
    }
  }

  Future<void> _saveSelectedPOSProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_pos_profile', jsonEncode(profile));
  }

  void _submitOpening(BuildContext context) async {
    final cash = _cashController.text.trim();
    if (cash.isEmpty || selectedPOSProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال المبلغ واختيار POS Profile')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final hasOpen = await PosService.hasOpenPosEntry();
      if (hasOpen) {
        Navigator.of(context).pop();
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => HomePage()));
        return;
      }

      final amount = double.tryParse(cash) ?? 0.0;
      await _saveSelectedPOSProfile(selectedPOSProfile!); // حفظ البيانات
      await PosService.createOpeningEntry(
        amount,
        selectedPOSProfile!,
      ); // إرسال البيانات المختارة

      Navigator.of(context).pop();
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => HomePage()));
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فتح نقطة البيع')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'يرجى إدخال المبلغ الابتدائي واختيار POS Profile',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _cashController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ النقدي الابتدائي',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            DropdownButton<String>(
              value: selectedPOSProfileName,
              hint: Text('اختر POS Profile'),
              onChanged: (String? newValue) {
                setState(() {
                  selectedPOSProfileName = newValue;
                  selectedPOSProfile = posProfiles.firstWhere(
                    (p) => p['name'] == newValue,
                    orElse: () => {},
                  );
                });
              },
              items:
                  posProfiles.map((profile) {
                    return DropdownMenuItem<String>(
                      value: profile['name'],
                      child: Text(profile['name']),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _submitOpening(context),
              child: const Text('فتح نقطة البيع'),
            ),
          ],
        ),
      ),
    );
  }
}
