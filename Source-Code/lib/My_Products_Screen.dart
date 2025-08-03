import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class MyProductsScreen extends StatefulWidget {
  @override
  _MyProductsScreenState createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  double? _latitude;
  double? _longitude;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        return;
      }

      final querySnapshot = await _firestore
          .collection('products')
          .where('storeId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      setState(() {
        _products = querySnapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
            .toList();
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      print('Error fetching products: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _getLocation() async {
    try {
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

  Future<void> _deleteProduct(String productId, String? imageUrl) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'تأكيد الحذف',
            style: TextStyle(color: Color(0xFF8B0000)),
          ),
          content: Text('هل أنت متأكد من حذف هذا المنتج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('إلغاء', style: TextStyle(color: Color(0xFF8B0000))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);

      if (imageUrl != null && imageUrl.isNotEmpty) {
        await _storage.refFromURL(imageUrl).delete();
      }

      await _firestore.collection('products').doc(productId).delete();
      await _fetchProducts();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف المنتج بنجاح'),
          backgroundColor: Color(0xFF8B0000),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الحذف: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
          title: Text('منتجاتي', style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFF8B0000),
          iconTheme: IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: Icon(Icons.add, color: Colors.white),
              onPressed: () => _navigateToAddEditProduct(),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFF5F5F5)],
            ),
          ),
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFF8B0000)),
                  ),
                )
              : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'حدث خطأ في تحميل المنتجات',
                        style: TextStyle(color: Color(0xFF8B0000)),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF8B0000),
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: _fetchProducts,
                        child: Text(
                          'إعادة المحاولة',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              : _products.isEmpty
              ? Center(
                  child: Text(
                    'لا يوجد منتجات لعرضها',
                    style: TextStyle(color: Color(0xFF8B0000)),
                  ),
                )
              : RefreshIndicator(
                  color: Color(0xFF8B0000),
                  onRefresh: _fetchProducts,
                  child: ListView.builder(
                    padding: EdgeInsets.all(8),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      return _buildProductCard(product);
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF8B0000).withOpacity(0.2)),
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: product['imageUrl'] != null
                    ? Image.network(
                        product['imageUrl'],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(
                                  Color(0xFF8B0000),
                                ),
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: Icon(Icons.error, color: Color(0xFF8B0000)),
                          );
                        },
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: Icon(Icons.image, color: Colors.grey),
                      ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] ?? 'بدون اسم',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B0000),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${product['price']?.toString() ?? '0'} د.ع',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8B0000),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: Color(0xFF8B0000)),
                    onPressed: () =>
                        _navigateToAddEditProduct(product: product),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red[700]),
                    onPressed: () =>
                        _deleteProduct(product['id'], product['imageUrl']),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAddEditProduct({Map<String, dynamic>? product}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditProductScreen(
          product: product,
          onProductUpdated: _fetchProducts,
          picker: _picker,
        ),
      ),
    ).then((_) => _fetchProducts());
  }
}

class AddEditProductScreen extends StatefulWidget {
  final Map<String, dynamic>? product;
  final VoidCallback onProductUpdated;
  final ImagePicker picker;

  const AddEditProductScreen({
    this.product,
    required this.onProductUpdated,
    required this.picker,
  });

  @override
  _AddEditProductScreenState createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _storeNumberController = TextEditingController();
  double? _latitude;
  double? _longitude;

  File? _imageFile;
  bool _isLoading = false;
  bool _isEditing = false;

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

  Future<void> _getLocation() async {
    try {
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
                                : null),
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
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _storeNameController,
                    decoration: InputDecoration(
                      labelText: 'اسم المتجر',
                      labelStyle: TextStyle(color: Color(0xFF8B0000)),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF8B0000)),
                      ),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'يرجى إدخال اسم المتجر' : null,
                  ),

                  SizedBox(height: 16),
                  TextFormField(
                    controller: _storeNumberController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'رقم المتجر',
                      labelStyle: TextStyle(color: Color(0xFF8B0000)),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF8B0000)),
                      ),
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'يرجى إدخال رقم المتجر' : null,
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

                  SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: 'اسم المنتج',
                      labelStyle: TextStyle(color: Color(0xFF8B0000)),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF8B0000)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF8B0000)),
                      ),
                    ),
                    style: TextStyle(color: Colors.black87),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'يجب إدخال اسم المنتج' : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: 'وصف المنتج',
                      labelStyle: TextStyle(color: Color(0xFF8B0000)),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF8B0000)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF8B0000)),
                      ),
                    ),
                    style: TextStyle(color: Colors.black87),
                    maxLines: 3,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'يجب إدخال وصف المنتج' : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'السعر',
                      labelStyle: TextStyle(color: Color(0xFF8B0000)),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF8B0000)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF8B0000)),
                      ),
                    ),
                    style: TextStyle(color: Colors.black87),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'يجب إدخال السعر';
                      if (double.tryParse(value!) == null)
                        return 'يجب إدخال رقم صحيح';
                      return null;
                    },
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
