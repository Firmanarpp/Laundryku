import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../services/supabase_service.dart';

// Provider untuk manage state payment & pickup
// Pakai ChangeNotifier biar UI otomatis update pas data berubah
// Pattern: Observer pattern - UI listen perubahan data
class PaymentProvider with ChangeNotifier {
  final SupabaseService _service = SupabaseService();
  
  List<Order> _orders = [];
  List<Payment> _payments = [];
  bool _isLoading = false;

  List<Order> get orders => _orders;
  List<Payment> get payments => _payments;
  bool get isLoading => _isLoading;

  // METHOD State Management Implementation
  // Ini contoh reactive programming - data berubah, UI auto update
  // Flow: set loading → fetch data → update state → notify UI
  // notifyListeners() trigger rebuild semua widget yang listen provider ini
  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners(); // UI bakal show loading indicator

    try {              
      _orders = await _service.getOrders();                                          
      _payments = await _service.getPayments();
    } catch (e) {
      debugPrint('Error loading orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners(); // UI bakal refresh dengan data baru
    }
  }

  // METHOD Business Logic - Find Payment by Order
  // Method ini cari payment berdasarkan order ID
  // Return null kalau belum bayar, return Payment object kalau sudah bayar
  // Dipakai untuk cek status payment dan tampilkan badge di UI
  Payment? getPaymentForOrder(String orderId) {
    try {
      return _payments.firstWhere((payment) => payment.orderId == orderId);
    } catch (e) {
      return null; // Kalau ga ketemu, berarti belum bayar
    }
  }

  Future<void> addPayment(Payment payment) async {
    await _service.createPayment(payment);
    await loadOrders();
  }

  // METHOD Update Operation - Mark Pickup Notified
  // Method ini update status pickup_notified jadi true di database
  // Setelah update, langsung refresh data biar UI dapat data terbaru
  // Flow: update DB → refresh data → notifyListeners (dari loadOrders)
  Future<void> markPickupNotified(String orderId) async {
    await _service.markPickupNotified(orderId); 
    await loadOrders(); // Refresh data setelah update biar UI sync
  }
}
