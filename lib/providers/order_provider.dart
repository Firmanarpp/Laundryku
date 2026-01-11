import 'package:flutter/foundation.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../services/supabase_service.dart';

class OrderProvider with ChangeNotifier {
  final SupabaseService _service = SupabaseService();
  
  List<Order> _orders = [];
  List<Customer> _customers = [];
  bool _isLoading = false;

  List<Order> get orders => _orders;
  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();

    try {
      _orders = await _service.getOrders();
    } catch (e) {
      debugPrint('Error loading orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCustomers() async {
    try {
      _customers = await _service.getCustomers();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading customers: $e');
    }
  }

  Future<void> addOrder(Order order) async {
    await _service.createOrder(order);
    await loadOrders();
  }

  Future<String> uploadOrderPhoto(String filePath, String fileName) async {
    return await _service.uploadPhoto(filePath, fileName);
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _service.updateOrderStatus(orderId, status);
    await loadOrders();
  }

  Future<void> markPickupNotified(String orderId) async {
    await _service.markPickupNotified(orderId);
    await loadOrders();
  }

  Future<Customer?> searchCustomer(String phone) async {
    return await _service.searchCustomerByPhone(phone);
  }

  Future<void> addCustomer(Customer customer) async {
    await _service.createCustomer(customer);
  }
}
