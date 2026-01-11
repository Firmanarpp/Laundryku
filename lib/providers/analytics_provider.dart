import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';

class AnalyticsProvider with ChangeNotifier {
  final SupabaseService _service = SupabaseService();
  
  double _dailyRevenue = 0;
  Map<String, int> _serviceBreakdown = {};
  List<Map<String, dynamic>> _customerFrequency = [];
  double _monthlyRevenue = 0;
  int _monthlyTransactionCount = 0;
  bool _isLoading = false;

  double get dailyRevenue => _dailyRevenue;
  Map<String, int> get serviceBreakdown => _serviceBreakdown;
  List<Map<String, dynamic>> get customerFrequency => _customerFrequency;
  double get monthlyRevenue => _monthlyRevenue;
  int get monthlyTransactionCount => _monthlyTransactionCount;
  bool get isLoading => _isLoading;

  Future<void> loadAnalytics() async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      
      _dailyRevenue = await _service.getDailyRevenue(now);
      _serviceBreakdown = await _service.getServiceTypeBreakdown();
      _customerFrequency = await _service.getCustomerFrequency();
      
      final monthlyData = await _service.getMonthlyRevenue(now.year, now.month);
      _monthlyRevenue = monthlyData['total'];
      _monthlyTransactionCount = monthlyData['count'];
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
