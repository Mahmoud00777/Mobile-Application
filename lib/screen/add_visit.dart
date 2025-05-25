import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

class VisitPage extends StatefulWidget {
  const VisitPage({super.key});

  @override
  State<VisitPage> createState() => _VisitPageState();
}

class _VisitPageState extends State<VisitPage> {
  File? _imageFile;
  Position? _position;
  final TextEditingController _notesController = TextEditingController();
  bool _visited = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    ); // أو .camera

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _position = position;
    });
  }

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('زيارة')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _position != null
                ? Text(
                  'الموقع: ${_position!.latitude}, ${_position!.longitude}',
                )
                : const Text('جاري تحديد الموقع...'),
            const SizedBox(height: 16),
            _imageFile != null
                ? Image.file(_imageFile!, height: 200)
                : const Text('لم يتم اختيار صورة'),
            TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text('اختيار صورة'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('تمت الزيارة'),
              value: _visited,
              onChanged: (value) {
                setState(() {
                  _visited = value ?? false;
                });
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                if (_position == null || _imageFile == null) return;

                // try {
                //   final imageUrl = await VisitService.uploadImage(_imageFile!);
                //   final visit = Visit(
                //     latitude: _position!.latitude,
                //     longitude: _position!.longitude,
                //     image: imageUrl,
                //     note: _notesController.text,
                //     visit: _visited,
                //     customer: '',
                //     posProfile: '',
                //     posOpeningShift: '',
                //     dateTime: DateTime.now(),
                //     select_state: '',
                //     name: '',
                //   );
                //   await VisitService.saveVisit(visit);

                //   ScaffoldMessenger.of(context).showSnackBar(
                //     const SnackBar(content: Text('تم حفظ الزيارة بنجاح')),
                //   );
                //   Navigator.pop(context, true);
                // } catch (e) {
                //   ScaffoldMessenger.of(context).showSnackBar(
                //     SnackBar(content: Text('خطأ: ${e.toString()}')),
                //   );
                // }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
