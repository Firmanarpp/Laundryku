import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';
import '../services/notification_service.dart';

// Order Detail Screen dengan responsive design & local notifications
// Notifikasi lokal akan muncul saat order siap diambil
class OrderDetailScreen extends StatefulWidget {
  final Order order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late String _currentStatus;
  final List<String> _statuses = ['terima', 'cuci', 'setrika', 'selesai'];

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status;
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      await Provider.of<OrderProvider>(context, listen: false)
          .updateOrderStatus(widget.order.id, newStatus);
      
      setState(() => _currentStatus = newStatus);
      
      // Send local notification jika status berubah ke 'selesai'
      if (newStatus == 'selesai') {
        await NotificationService.instance.showPickupReadyNotification(
          orderId: widget.order.id,
          customerName: widget.order.customerName ?? 'Customer',
        );
      } else {
        // Show simple success message untuk status lainnya
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status berhasil diupdate'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');
    // Responsive: Get screen size untuk adaptive layout
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Order'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Customer Info
            Card(
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 24 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.order.customerName ?? 'Unknown',
                      style: TextStyle(
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: isTablet ? 20 : 16),
            
            // Order Info
            Card(
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 24 : 16),
                child: Column(
                  children: [
                    _buildInfoRow('Berat', '${widget.order.weight} kg', isTablet),
                    const Divider(),
                    _buildInfoRow('Layanan', widget.order.serviceType, isTablet),
                    const Divider(),
                    _buildInfoRow('Harga', 'Rp ${_formatPrice(widget.order.price)}'),
                    const Divider(),
                    _buildInfoRow('Tanggal', dateFormat.format(widget.order.date)),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Photo Section
            if (widget.order.photoUrl != null && widget.order.photoUrl!.isNotEmpty) ...[
              const Text(
                'Foto Pakaian',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Display image from URL or local file
                    Container(
                      width: double.infinity,
                      height: 250,
                      color: Colors.grey[200],
                      child: _buildPhotoWidget(widget.order.photoUrl!),
                    ),
                    // Photo info
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Foto dokumentasi saat terima',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: _statuses.map((status) {
                    bool isActive = status == _currentStatus;
                    bool isPast = _statuses.indexOf(status) < 
                                   _statuses.indexOf(_currentStatus);
                    
                    return Column(
                      children: [
                        InkWell(
                          onTap: () => _updateStatus(status),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.blue
                                  : isPast
                                      ? Colors.green
                                      : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isActive || isPast
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isActive || isPast
                                      ? Colors.white
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: isActive || isPast
                                        ? Colors.white
                                        : Colors.grey[700],
                                    fontWeight: isActive
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (status != _statuses.last)
                          const SizedBox(height: 8),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, [bool isTablet = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey,
              fontSize: isTablet ? 16 : 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  Widget _buildPhotoWidget(String photoUrl) {
    // Check if it's a URL or local path
    if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
      // Display from Supabase URL
      return Image.network(
        photoUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  'Foto tidak dapat dimuat',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // Display from local file (backward compatibility)
      final file = File(photoUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Foto tidak dapat ditampilkan',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      } else {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_camera,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'File foto tidak ditemukan',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }
    }
  }
}
