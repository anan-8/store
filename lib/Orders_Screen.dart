import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StoreOrdersScreen extends StatefulWidget {
  @override
  _StoreOrdersScreenState createState() => _StoreOrdersScreenState();
}

class _StoreOrdersScreenState extends State<StoreOrdersScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedStatus = 'الكل';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('طلبات متجري', style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFF8B0000),
          iconTheme: IconThemeData(color: Colors.white),
          actions: [_buildStatusFilterDropdown()],
        ),
        body: _isLoading
            ? _buildLoadingIndicator()
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Color(0xFFF5F5F5)],
                  ),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getOrdersStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildErrorWidget('حدث خطأ في تحميل الطلبات');
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingIndicator();
                    }

                    final orders = snapshot.data?.docs ?? [];
                    if (orders.isEmpty) {
                      return _buildEmptyState();
                    }

                    return _buildOrdersList(orders);
                  },
                ),
              ),
      ),
    );
  }

  Stream<QuerySnapshot> _getOrdersStream() {
    var query = _firestore
        .collection('orders')
        .where('userId', isEqualTo: _auth.currentUser!.uid)
        .orderBy('createdAt', descending: true);

    if (_selectedStatus != 'الكل') {
      query = query.where('status', isEqualTo: _selectedStatus);
    }

    return query.snapshots();
  }

  Widget _buildStatusFilterDropdown() {
    return Padding(
      padding: EdgeInsets.only(left: 16),
      child: DropdownButton<String>(
        value: _selectedStatus,
        dropdownColor: Colors.white,
        underline: Container(),
        icon: Icon(Icons.filter_list, color: Colors.white),
        items:
            [
              'الكل',
              'جديدة',
              'قيد التوصيل',
              'مكتملة', // تم التعديل من "مكتمل" إلى "مكتملة"
            ].map((String status) {
              return DropdownMenuItem<String>(
                value: status,
                child: Text(status, style: TextStyle(color: Color(0xFF8B0000))),
              );
            }).toList(),
        onChanged: (newStatus) {
          if (newStatus != null) {
            setState(() => _selectedStatus = newStatus);
          }
        },
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 50, color: Color(0xFF8B0000)),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Color(0xFF8B0000), fontSize: 18),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF8B0000)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(Color(0xFF8B0000)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment, size: 50, color: Color(0xFF8B0000)),
          SizedBox(height: 16),
          Text(
            'لا توجد طلبات لعرضها',
            style: TextStyle(color: Color(0xFF8B0000), fontSize: 18),
          ),
          if (_selectedStatus != 'الكل') ...[
            SizedBox(height: 8),
            Text(
              'حالة الفلتر: $_selectedStatus',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() => _selectedStatus = 'الكل'),
              child: Text('عرض جميع الطلبات'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF8B0000),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<QueryDocumentSnapshot> orders) {
    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        try {
          final order = orders[index];
          final data = _safeCastMap(order.data());
          final customer = _safeCastMap(data['customerInfo']);
          final items = _safeCastList(data['items']);
          final totalPrice = data['totalPrice']?.toDouble() ?? 0.0;
          final status = data['status']?.toString() ?? 'جديدة';
          final createdAt = _parseTimestamp(data['createdAt']);

          return Card(
            elevation: 2,
            margin: EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              leading: _buildStatusIndicator(status),
              title: Text(
                'طلب #${order.id.substring(0, 8).toUpperCase()}',
                style: TextStyle(
                  color: Color(0xFF8B0000),
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_formatDate(createdAt)} - ${customer['name']?.toString() ?? 'بدون اسم'}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  Text(
                    '${items.length} منتج | ${totalPrice.toStringAsFixed(2)} ريال',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCustomerInfo(customer),
                      SizedBox(height: 16),
                      _buildOrderItems(items),
                      SizedBox(height: 16),
                      _buildOrderStatusInfo(status),
                    ],
                  ),
                ),
              ],
            ),
          );
        } catch (e) {
          print('Error building order item: $e');
          return ListTile(
            title: Text('خطأ في تحميل بيانات الطلب'),
            leading: Icon(Icons.error, color: Colors.red),
          );
        }
      },
    );
  }

  Map<String, dynamic> _safeCastMap(dynamic data) {
    try {
      if (data == null) return {};
      if (data is Map) return Map<String, dynamic>.from(data);
      return {};
    } catch (e) {
      print('Error casting map: $e');
      return {};
    }
  }

  List<Map<String, dynamic>> _safeCastList(dynamic data) {
    try {
      if (data == null) return [];
      if (data is List) {
        return data.map((item) => _safeCastMap(item)).toList();
      }
      return [];
    } catch (e) {
      print('Error casting list: $e');
      return [];
    }
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) return timestamp.toDate();
      return DateTime.now();
    } catch (e) {
      print('Error parsing timestamp: $e');
      return DateTime.now();
    }
  }

  Widget _buildStatusIndicator(String status) {
    Color statusColor;
    switch (status) {
      case 'جديدة':
        statusColor = Colors.blue;
        break;
      case 'قيد التوصيل':
        statusColor = Colors.orange;
        break;
      case 'مكتملة': // تم التعديل هنا
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(_getStatusIcon(status), color: statusColor, size: 18),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'جديدة':
        return Icons.new_releases;
      case 'قيد التوصيل':
        return Icons.local_shipping;
      case 'مكتملة': // تم التعديل هنا
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildCustomerInfo(Map<String, dynamic> customer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'معلومات العميل:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B0000),
          ),
        ),
        SizedBox(height: 8),
        _buildInfoRow('الاسم:', customer['name']?.toString() ?? 'غير محدد'),
        _buildInfoRow('الهاتف:', customer['phone']?.toString() ?? 'غير محدد'),
        _buildInfoRow(
          'العنوان:',
          customer['address']?.toString() ?? 'غير محدد',
        ),
        _buildInfoRow('طريقة الدفع:', 'الدفع عند الاستلام'),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B0000),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItems(List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المنتجات:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B0000),
          ),
        ),
        SizedBox(height: 8),
        ...items.map((item) => _buildOrderItem(item)).toList(),
      ],
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: Color(0xFF8B0000)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              item['name']?.toString() ?? 'منتج',
              style: TextStyle(color: Colors.black87),
            ),
          ),
          Text(
            '${item['quantity']?.toString() ?? '0'} × ${item['price']?.toString() ?? '0'} ريال',
            style: TextStyle(
              color: Color(0xFF8B0000),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusInfo(String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'حالة الطلب:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B0000),
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _buildStatusIndicator(status),
              SizedBox(width: 12),
              Text(
                status,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
