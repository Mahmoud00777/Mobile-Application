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
  List<Map<String, dynamic>> posProfiles = [];
  Map<String, dynamic>? selectedPOSProfile;
  String? selectedPOSProfileName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final profiles = await PosService.getUserPOSProfiles();
      setState(() {
        posProfiles = profiles;
        _isLoading = false;
      });
      await _loadSavedPOSProfile();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل البيانات: ${e.toString()}')),
      );
    }
  }

  Future<void> _loadSavedPOSProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('selected_pos_profile');
    if (saved != null) {
      setState(() {
        selectedPOSProfile = jsonDecode(saved);
        selectedPOSProfileName = selectedPOSProfile?['name'];
      });
    }
  }

  Future<void> _saveSelectedPOSProfile() async {
    if (selectedPOSProfile == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'selected_pos_profile',
      jsonEncode(selectedPOSProfile),
    );
  }

  Future<void> _submitOpening() async {
    if (selectedPOSProfile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى اختيار POS Profile')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final hasOpen = await PosService.hasOpenPosEntry();
      if (hasOpen) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage()),
        );
        return;
      }

      await _saveSelectedPOSProfile();
      await PosService.createOpeningEntry(0, selectedPOSProfile!);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage()),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فتح نقطة البيع'),
        centerTitle: true,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'اختر نقطة البيع لبدء الوردية',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'نقطة البيع المتاحة',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: selectedPOSProfileName,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              hint: const Text('اختر نقطة البيع'),
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedPOSProfileName = newValue;
                                  selectedPOSProfile = posProfiles.firstWhere(
                                    (p) => p['name'] == newValue,
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitOpening,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : const Text(
                                'بدء الوردية',
                                style: TextStyle(fontSize: 18),
                              ),
                    ),
                  ],
                ),
              ),
    );
  }
}
