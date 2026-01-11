import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/payment.dart';
import 'local_database_service.dart';

// Service layer untuk handle semua operasi database
// Hybrid Architecture: SQLite (local) + Supabase (cloud backup & sync)
// Pattern: Repository pattern - satu source untuk data access
// Offline-First: semua operasi ke local DB dulu, sync ke Supabase di background
class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final LocalDatabaseService _localDb = LocalDatabaseService.instance;

  // ==================== CUSTOMERS ====================
  
  // Offline-First: Read dari local DB untuk kecepatan
  // Background sync: fetch dari Supabase untuk update data terbaru
  Future<List<Customer>> getCustomers() async {
    try {
      // Try fetch dari Supabase untuk get latest data
      final response = await _client
          .from('customers')
          .select()
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => Customer.fromJson(json))
          .toList();
    } catch (e) {
      // Kalau offline/error, fallback ke local database
      try {
        return await _localDb.getAllCustomers();
      } catch (localError) {
        throw Exception('Failed to fetch customers: $e');
      }
    }
  }

  Future<Customer> createCustomer(Customer customer) async {
    try {
      // Save to local DB first (offline support)
      await _localDb.insertCustomer(customer);
      
      // Then sync to Supabase (jika online)
      final response = await _client
          .from('customers')
          .insert(customer.toJson())
          .select()
          .single();
      
      return Customer.fromJson(response);
    } catch (e) {
      // Jika gagal sync ke Supabase, data tetap ada di local
      // Akan di-sync nanti saat online
      throw Exception('Failed to create customer: $e');
    }
  }

  Future<Customer?> searchCustomerByPhone(String phone) async {
    try {
      // Try local DB first (faster)
      final localResult = await _localDb.searchCustomerByPhone(phone);
      if (localResult != null) return localResult;
      
      // If not found locally, try Supabase
      final response = await _client
          .from('customers')
          .select()
          .eq('phone', phone)
          .maybeSingle();
      
      return response != null ? Customer.fromJson(response) : null;
    } catch (e) {
      throw Exception('Failed to search customer: $e');
    }
  }

  // ==================== ORDERS ====================
  
  // Offline-First with fallback: Try Supabase first, fallback to local DB
  // JOIN operation untuk get customer name along with order data
  Future<List<Order>> getOrders() async {
    try {
      final response = await _client
          .from('orders')
          .select('*, customers(name)') // JOIN dengan table customers
          .order('date', ascending: false);
      
      return (response as List)
          .map((json) => Order.fromJson(json))
          .toList();
    } catch (e) {
      // Fallback to local DB if offline
      try {
        return await _localDb.getAllOrders();
      } catch (localError) {
        throw Exception('Failed to fetch orders: $e');
      }
    }
  }

  Future<List<Order>> getOrdersByCustomer(String customerId) async {
    try {
      final response = await _client
          .from('orders')
          .select('*, customers(name)')
          .eq('customer_id', customerId)
          .order('date', ascending: false);
      
      return (response as List)
          .map((json) => Order.fromJson(json))
          .toList();
    } catch (e) {
      // Fallback to local DB
      try {
        return await _localDb.getOrdersByCustomer(customerId);
      } catch (localError) {
        throw Exception('Failed to fetch customer orders: $e');
      }
    }
  }

  Future<Order> createOrder(Order order) async {
    try {
      // Save to local DB first
      await _localDb.insertOrder(order);
      
      // Then sync to Supabase
      final response = await _client
          .from('orders')
          .insert(order.toJson())
          .select('*, customers(name)')
          .single();
      
      return Order.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      // Update local DB first
      await _localDb.updateOrderStatus(orderId, status);
      
      // Then sync to Supabase
      await _client
          .from('orders')
          .update({'status': status})
          .eq('id', orderId);
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  Future<void> updateOrderPhoto(String orderId, String photoUrl) async {
    try {
      // Update local DB first
      await _localDb.updateOrderPhoto(orderId, photoUrl);
      
      // Then sync to Supabase
      await _client
          .from('orders')
          .update({'photo_url': photoUrl})
          .eq('id', orderId);
    } catch (e) {
      throw Exception('Failed to update order photo: $e');
    }
  }

  Future<void> markPickupNotified(String orderId) async {
    try {
      // Update local DB first
      await _localDb.markPickupNotified(orderId);
      
      // Then sync to Supabase
      await _client
          .from('orders')
          .update({
            'pickup_notified': true,
            'pickup_date': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);
    } catch (e) {
      throw Exception('Failed to mark pickup notified: $e');
    }
  }

  // ==================== PAYMENTS ====================
  
  Future<List<Payment>> getPayments() async {
    try {
      final response = await _client
          .from('payments')
          .select()
          .order('paid_date', ascending: false);
      
      return (response as List)
          .map((json) => Payment.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch payments: $e');
    }
  }

  Future<Payment?> getPaymentByOrder(String orderId) async {
    try {
      final response = await _client
          .from('payments')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();
      
      return response != null ? Payment.fromJson(response) : null;
    } catch (e) {
      throw Exception('Failed to fetch payment: $e');
    }
  }

  Future<Payment> createPayment(Payment payment) async {
    try {
      final response = await _client
          .from('payments')
          .insert(payment.toJson())
          .select()
          .single();
      
      return Payment.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create payment: $e');
    }
  }

  // ==================== ANALYTICS ====================
  
  Future<double> getDailyRevenue(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final response = await _client
          .from('payments')
          .select('amount')
          .gte('paid_date', startOfDay.toIso8601String())
          .lt('paid_date', endOfDay.toIso8601String());
      
      double total = 0;
      for (var payment in response) {
        total += (payment['amount'] ?? 0).toDouble();
      }
      
      return total;
    } catch (e) {
      throw Exception('Failed to fetch daily revenue: $e');
    }
  }

  Future<Map<String, int>> getServiceTypeBreakdown() async {
    try {
      final response = await _client
          .from('orders')
          .select('service_type');
      
      Map<String, int> breakdown = {};
      for (var order in response) {
        String serviceType = order['service_type'] ?? 'Unknown';
        breakdown[serviceType] = (breakdown[serviceType] ?? 0) + 1;
      }
      
      return breakdown;
    } catch (e) {
      throw Exception('Failed to fetch service breakdown: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCustomerFrequency() async {
    try {
      final response = await _client
          .from('orders')
          .select('customer_id, customers(name)')
          .order('customer_id');
      
      Map<String, dynamic> frequency = {};
      
      for (var order in response) {
        String customerId = order['customer_id'].toString();
        String customerName = order['customers']?['name'] ?? 'Unknown';
        
        if (frequency.containsKey(customerId)) {
          frequency[customerId]['count']++;
        } else {
          frequency[customerId] = {
            'name': customerName,
            'count': 1,
          };
        }
      }
      
      List<Map<String, dynamic>> result = frequency.entries.map((entry) {
        return {
          'customer_id': entry.key,
          'name': entry.value['name'],
          'count': entry.value['count'],
        };
      }).toList();
      
      result.sort((a, b) => b['count'].compareTo(a['count']));
      
      return result;
    } catch (e) {
      throw Exception('Failed to fetch customer frequency: $e');
    }
  }

  Future<Map<String, dynamic>> getMonthlyRevenue(int year, int month) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 1);
      
      final response = await _client
          .from('payments')
          .select('amount, paid_date')
          .gte('paid_date', startDate.toIso8601String())
          .lt('paid_date', endDate.toIso8601String());
      
      double total = 0;
      int count = 0;
      
      for (var payment in response) {
        total += (payment['amount'] ?? 0).toDouble();
        count++;
      }
      
      return {
        'total': total,
        'count': count,
      };
    } catch (e) {
      throw Exception('Failed to fetch monthly revenue: $e');
    }
  }

  // ==================== UPLOAD IMAGE ====================
  
  Future<String> uploadPhoto(String filePath, String fileName) async {
    try {
      // Read file as bytes
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      
      // Upload to Supabase Storage
      await _client.storage
          .from('order-photos')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              upsert: true, // Replace if exists
              contentType: 'image/jpeg',
            ),
          );
      
      // Get public URL
      final url = _client.storage
          .from('order-photos')
          .getPublicUrl(fileName);
      
      return url;
    } catch (e) {
      throw Exception('Failed to upload photo: $e');
    }
  }
}
