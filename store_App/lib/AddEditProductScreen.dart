import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

class AddEditProduct extends StatefulWidget {
  final Map<String, dynamic>? product;
  final VoidCallback onProductUpdated;
  final ImagePicker picker;

  const AddEditProduct({
    this.product,
    required this.onProductUpdated,
    required this.picker,
  });

  @override
  _AddEditProductState createState() => _AddEditProductState();
}

class _AddEditProductState extends State<AddEditProduct> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _storeNumberController = TextEditingController();

  File? _imageFile;
  bool _isLoading = false;
  bool _isEditing = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.product != null;
    if (_isEditing) {
      _nameController.text = widget.product!['name'] ?? '';
      _descriptionController.text = widget.product!['description'] ?? '';
      _priceController.text = widget.product!['price']?.toString() ?? '';
      _storeNameController.text = widget.product!['storeName'] ?? '';
      _storeNumberController.text =
          widget.product!['storeNumber']?.toString() ?? '';
      _latitude = widget.product!['latitude'];
      _longitude = widget.product!['longitude'];
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await widget.picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء اختيار الصورة: $e'),
          backgroundColor: Color(0xFF8B0000),
        ),
      );
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('product_images')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(_imageFile!);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم رفض إذن الموقع بشكل دائم.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في تحديد الموقع: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final imageUrl = _imageFile != null
          ? await _uploadImage()
          : widget.product?['imageUrl'];

      final productData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': double.tryParse(_priceController.text) ?? 0,
        'imageUrl': imageUrl,
        'storeId': user.uid,
        'storeName': _storeNameController.text,
        'storeNumber': _storeNumberController.text,
        'latitude': _latitude,
        'longitude': _longitude,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product!['id'])
            .update(productData);
      } else {
        await FirebaseFirestore.instance
            .collection('products')
            .add(productData);
      }

      widget.onProductUpdated();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'تم التعديل بنجاح' : 'تم الإضافة بنجاح'),
          backgroundColor: Color(0xFF8B0000),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            _isEditing ? 'تعديل المنتج' : 'إضافة منتج جديد',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Color(0xFF8B0000),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFF5F5F5)],
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (widget.product?['imageUrl'] != null
                                    ? NetworkImage(widget.product!['imageUrl'])
                                    : null)
                                as ImageProvider?,
                      child:
                          _imageFile == null &&
                              widget.product?['imageUrl'] == null
                          ? Icon(
                              Icons.add_a_photo,
                              size: 40,
                              color: Color(0xFF8B0000),
                            )
                          : null,
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildTextField(_nameController, 'اسم المنتج'),
                  SizedBox(height: 16),
                  _buildTextField(
                    _descriptionController,
                    'وصف المنتج',
                    maxLines: 3,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(
                    _priceController,
                    'السعر',
                    isNumber: true,
                    textDirection: TextDirection.ltr,
                  ),
                  SizedBox(height: 16),
                  _buildTextField(_storeNameController, 'اسم المتجر'),
                  SizedBox(height: 16),
                  _buildTextField(
                    _storeNumberController,
                    'رقم المتجر',
                    isNumber: true,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _getLocation,
                    icon: Icon(Icons.location_on),
                    label: Text('تحديد الموقع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF8B0000),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (_latitude != null && _longitude != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('الموقع: $_latitude, $_longitude'),
                    ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF8B0000),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isLoading ? null : _saveProduct,
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _isEditing ? 'حفظ التعديلات' : 'إضافة المنتج',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    bool isNumber = false,
    TextDirection textDirection = TextDirection.rtl,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      textDirection: textDirection,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Color(0xFF8B0000)),
        border: OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF8B0000)),
        ),
      ),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: (value) =>
          value == null || value.isEmpty ? 'يرجى إدخال $label' : null,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _storeNameController.dispose();
    _storeNumberController.dispose();
    super.dispose();
  }
}
