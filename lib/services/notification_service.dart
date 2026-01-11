import 'package:flutter/material.dart';

// Simple In-App Notification Service
// Menggunakan SnackBar dan Dialog untuk notifikasi tanpa dependency eksternal
class NotificationService {
  static final NotificationService instance = NotificationService._init();
  
  // Store BuildContext for showing notifications
  BuildContext? _context;
  
  NotificationService._init();

  // Initialize with context
  Future<void> initialize() async {
    // No initialization needed for simple approach
    debugPrint('✅ Simple Notification Service initialized');
  }
  
  // Set context untuk bisa show notifications
  void setContext(BuildContext context) {
    _context = context;
  }

  // Show notification for order ready to pickup
  Future<void> showPickupReadyNotification({
    required String orderId,
    required String customerName,
  }) async {
    if (_context != null && _context!.mounted) {
      // Show snackbar notification
      ScaffoldMessenger.of(_context!).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🧺 Order Siap Diambil!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Order untuk $customerName sudah selesai dan siap diambil',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      
      // Also show dialog for more persistent notification
      await Future.delayed(const Duration(milliseconds: 500));
      if (_context != null && _context!.mounted) {
        showDialog(
          context: _context!,
          builder: (context) => AlertDialog(
            icon: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 48,
            ),
            title: const Text('Order Siap Diambil!'),
            content: Text(
              'Order untuk $customerName (#$orderId) sudah selesai dikerjakan dan siap untuk diambil.\n\nSilakan hubungi customer untuk notifikasi pickup.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
    
    debugPrint('✅ Pickup notification shown for: $customerName');
  }

  // Show notification for payment reminder
  Future<void> showPaymentReminderNotification({
    required String orderId,
    required String customerName,
    required double amount,
  }) async {
    if (_context != null && _context!.mounted) {
      ScaffoldMessenger.of(_context!).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.payment, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '💰 Payment Reminder: $customerName - Rp ${amount.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Show notification for new order received
  Future<void> showNewOrderNotification({
    required String orderId,
    required String customerName,
  }) async {
    if (_context != null && _context!.mounted) {
      ScaffoldMessenger.of(_context!).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.add_shopping_cart, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('📦 Order baru dari $customerName telah ditambahkan'),
              ),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Show simple notification
  Future<void> showSimpleNotification({
    required String title,
    required String body,
  }) async {
    if (_context != null && _context!.mounted) {
      ScaffoldMessenger.of(_context!).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(body),
            ],
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
