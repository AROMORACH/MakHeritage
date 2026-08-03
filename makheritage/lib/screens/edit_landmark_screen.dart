import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../models/landmark.dart';
import '../services/landmark_service.dart';
import 'map_screen.dart';

class EditLandmarkScreen extends StatefulWidget {
  final Landmark landmark;
  const EditLandmarkScreen({super.key, required this.landmark});

  @override
  State<EditLandmarkScreen> createState() => _EditLandmarkScreenState();
}

class _EditLandmarkScreenState extends State<EditLandmarkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = LandmarkService();
  final ImagePicker _picker = ImagePicker();
  
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _descController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _yearController;
  
  XFile? _selectedImage;
  String? _existingImageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.landmark.name);
    _categoryController = TextEditingController(text: widget.landmark.category);
    _descController = TextEditingController(text: widget.landmark.description ?? '');
    _latController = TextEditingController(text: widget.landmark.latitude?.toString() ?? '');
    _lngController = TextEditingController(text: widget.landmark.longitude?.toString() ?? '');
    _yearController = TextEditingController(text: widget.landmark.foundationYear ?? '');
    _existingImageUrl = widget.landmark.imageAssetPath;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        setState(() {
          _selectedImage = picked;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF006633)),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF006633)),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String? imageUrl = _existingImageUrl;
    if (_selectedImage != null) {
      imageUrl = await _service.uploadImage(_selectedImage!);
    }

    final data = {
      "name": _nameController.text.trim(),
      "category": _categoryController.text.trim(),
      "description": _descController.text.trim(),
      "latitude": double.tryParse(_latController.text.trim()),
      "longitude": double.tryParse(_lngController.text.trim()),
      "year": _yearController.text.trim().isNotEmpty ? _yearController.text.trim() : null,
      "foundation_year": _yearController.text.trim().isNotEmpty ? _yearController.text.trim() : null,
      "image_url": imageUrl,
    };

    final success = await _service.updateLandmark(widget.landmark.id, data);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Landmark updated successfully!')),
        );
        Navigator.pop(context, true); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update landmark.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _descController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Widget _buildImagePreview() {
    if (_selectedImage != null) {
      return Image.file(
        File(_selectedImage!.path),
        width: double.infinity,
        height: 160,
        fit: BoxFit.cover,
      );
    } else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      final imgPath = _existingImageUrl!;
      if (imgPath.startsWith('http://') || imgPath.startsWith('https://')) {
        return Image.network(imgPath, width: double.infinity, height: 160, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40));
      } else if (imgPath.startsWith('/') || imgPath.startsWith('file://')) {
        return Image.file(File(imgPath.replaceFirst('file://', '')), width: double.infinity, height: 160, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40));
      } else {
        return Image.asset(imgPath, width: double.infinity, height: 160, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40));
      }
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _selectedImage != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Landmark', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFE5A93C),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF006633), width: 1.5),
                ),
                child: hasImage
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _buildImagePreview(),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                                onPressed: _showImageSourceDialog,
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 40, color: Color(0xFF006633)),
                          SizedBox(height: 8),
                          Text(
                            'Upload Landmark Image',
                            style: TextStyle(color: Color(0xFF006633), fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tap to select from Gallery or Camera',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _yearController,
                    decoration: const InputDecoration(labelText: 'Foundation Year', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.map, color: Colors.white),
              label: const Text('Pick Location on Map', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006633),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final picked = await Navigator.push<LatLng>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MapScreen(isPickingLocation: true),
                  ),
                );
                if (picked != null) {
                  setState(() {
                    _latController.text = picked.latitude.toStringAsFixed(7);
                    _lngController.text = picked.longitude.toStringAsFixed(7);
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latController,
                    decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _lngController,
                    decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 4,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5A93C),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Update Database', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
