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
                    final filteredOrders = orders.where((order) {
                      final data = order.data() as Map<String, dynamic>;
                      return data['storeId'] == _auth.currentUser?.uid;
                    }).toList();

                    if (filteredOrders.isEmpty) {
                      return _buildEmptyState();
                    }

                    return _buildOrdersList(filteredOrders);
                  },
                ),
              ),
      ),
    );
  }

  Stream<QuerySnapshot> _getOrdersStream() {
    return _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots();
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
              'قيد التحضير',
              'جاهزة للتوصيل',
              'مكتملة',
              'ملغية',
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
        final order = orders[index];
        final data = order.data() as Map<String, dynamic>;
        final customer = data['customerInfo'] ?? {};
        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        final totalPrice = data['totalPrice'] ?? 0;
        final status = data['status'] ?? 'جديدة';
        final createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

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
                  '${_formatDate(createdAt)} - ${customer['name'] ?? 'بدون اسم'}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                Text(
                  '${items.length} منتج | ${totalPrice.toStringAsFixed(2)} د.ع',
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
      },
    );
  }

  Widget _buildStatusIndicator(String status) {
    Color statusColor;
    switch (status) {
      case 'جديدة':
        statusColor = Colors.blue;
        break;
      case 'قيد التحضير':
        statusColor = Colors.orange;
        break;
      case 'جاهزة للتوصيل':
        statusColor = Colors.purple;
        break;
      case 'مكتملة':
        statusColor = Colors.green;
        break;
      case 'ملغية':
        statusColor = Colors.red;
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
      case 'قيد التحضير':
        return Icons.access_time;
      case 'جاهزة للتوصيل':
        return Icons.local_shipping;
      case 'مكتملة':
        return Icons.check_circle;
      case 'ملغية':
        return Icons.cancel;
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
        _buildInfoRow('الاسم:', customer['name'] ?? 'غير محدد'),
        _buildInfoRow('الهاتف:', customer['phone'] ?? 'غير محدد'),
        _buildInfoRow('العنوان:', customer['address'] ?? 'غير محدد'),
        _buildInfoRow('طريقة الدفع:', 'الدفع عند الاستلام'), // ثابتة دائماً
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
              '${item['name'] ?? 'منتج'}',
              style: TextStyle(color: Colors.black87),
            ),
          ),
          Text(
            '${item['quantity']} × ${item['price']?.toString() ?? '0'} د.ع',
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
