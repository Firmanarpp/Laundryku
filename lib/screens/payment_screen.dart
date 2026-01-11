import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/payment_provider.dart';
import 'payment_form_screen.dart';
import 'transaction_history_screen.dart';

// Screen payment & pickup - module 2
// Handle payment recording + pickup notification
// Ada filter logic yang cukup kompleks disini
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _filterStatus = 'all';
  String _customerSearch = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PaymentProvider>(context, listen: false).loadOrders();
    });
  }

  // Fungsi untuk notify customer bahwa ordernya udah siap diambil
  // Update database dulu (pickup_notified = true), baru kasih feedback ke user
  // Pake Provider.of dengan listen: false karena cuma butuh akses method, ga perlu rebuild
  void _notifyPickup(Order order) async {
    try {
      await Provider.of<PaymentProvider>(context, listen: false)
          .markPickupNotified(order.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notifikasi pickup dikirim untuk ${order.customerName}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim notifikasi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTransactionHistory(BuildContext context, String customerId, String customerName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionHistoryScreen(
          customerId: customerId,
          customerName: customerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment & Pickup'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari customer...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() => _customerSearch = value.toLowerCase());
              },
            ),
          ),
          
          // Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Semua', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Belum Bayar', 'unpaid'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Sudah Bayar', 'paid'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Siap Pickup', 'ready'),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: Consumer<PaymentProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<Order> filteredOrders = _getFilteredOrders(provider);

                // Calculate outstanding summary
                final unpaidOrders = provider.orders.where((o) => 
                  provider.getPaymentForOrder(o.id) == null
                ).toList();
                final totalOutstanding = unpaidOrders.fold<double>(
                  0, (sum, order) => sum + order.price
                );
                final readyOrders = provider.orders.where((o) => 
                  o.status.toLowerCase() == 'selesai' && provider.getPaymentForOrder(o.id) != null
                ).length;

                if (filteredOrders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada order',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => provider.loadOrders(),
                  child: Column(
                    children: [
                      // Outstanding Summary Card
                      if (_filterStatus == 'all' || _filterStatus == 'unpaid')
                        Card(
                          margin: const EdgeInsets.all(8),
                          color: Colors.orange[50],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildOutstandingItem(
                                  'Outstanding',
                                  '${unpaidOrders.length} Order',
                                  Icons.pending_actions,
                                  Colors.orange,
                                ),
                                Container(
                                  height: 40,
                                  width: 1,
                                  color: Colors.grey[300],
                                ),
                                _buildOutstandingItem(
                                  'Total Tagihan',
                                  'Rp ${_formatPrice(totalOutstanding)}',
                                  Icons.attach_money,
                                  Colors.red,
                                ),
                                Container(
                                  height: 40,
                                  width: 1,
                                  color: Colors.grey[300],
                                ),
                                _buildOutstandingItem(
                                  'Ready Pickup',
                                  '$readyOrders Order',
                                  Icons.done_all,
                                  Colors.green,
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      Expanded(
                        child: ListView.builder(
                          itemCount: filteredOrders.length,
                          padding: const EdgeInsets.all(8),
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            final payment = provider.getPaymentForOrder(order.id);
                            return _buildOrderCard(order, payment != null);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterStatus = value);
      },
      selectedColor: Colors.green,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
      ),
    );
  }

  // METHOD Complex Logic dengan Multiple Filter Conditions
  // Filter orders berdasarkan: payment status, ready pickup, customer search
  // Chaining filter dengan .where() - functional programming style
  // Case-insensitive search untuk better UX
  List<Order> _getFilteredOrders(PaymentProvider provider) {
    List<Order> filtered = provider.orders;

    // Filter by payment status (paid/unpaid)
    if (_filterStatus == 'paid') {
      filtered = filtered.where((order) {
        return provider.getPaymentForOrder(order.id) != null;
      }).toList();
    } else if (_filterStatus == 'unpaid') {
      filtered = filtered.where((order) {
        return provider.getPaymentForOrder(order.id) == null;
      }).toList();
    } else if (_filterStatus == 'ready') {
      filtered = filtered.where((order) {
        return order.status.toLowerCase() == 'selesai' && provider.getPaymentForOrder(order.id) != null;
      }).toList();
    }

    // Filter by customer search
    if (_customerSearch.isNotEmpty) {
      filtered = filtered.where((order) {
        return order.customerName?.toLowerCase().contains(_customerSearch) ?? false;
      }).toList();
    }

    return filtered;
  }

  Widget _buildOrderCard(Order order, bool isPaid) {
    final dateFormat = DateFormat('dd MMM yyyy');
    // Case-insensitive comparison untuk status
    final bool isReadyForPickup = order.status.toLowerCase() == 'selesai' && isPaid;
    final bool canNotify = isReadyForPickup && !order.pickupNotified;
    
    // Debug print
    print('Order: ${order.customerName}, Status: "${order.status}", isPaid: $isPaid, isReady: $isReadyForPickup, notified: ${order.pickupNotified}');
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: isPaid ? Colors.green : Colors.orange,
              child: Icon(
                isPaid ? Icons.check : Icons.pending,
                color: Colors.white,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    order.customerName ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isReadyForPickup)
                  const Chip(
                    label: Text('READY', style: TextStyle(fontSize: 9)),
                    backgroundColor: Colors.blue,
                    labelStyle: TextStyle(color: Colors.white),
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${order.serviceType} - ${order.weight} kg'),
                Text('Rp ${_formatPrice(order.price)}'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      dateFormat.format(order.date),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    // TAMPILKAN STATUS UNTUK DEBUG
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: order.status.toLowerCase() == 'selesai' 
                            ? Colors.green[100] 
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Status: ${order.status}',
                        style: TextStyle(
                          fontSize: 11, 
                          color: order.status.toLowerCase() == 'selesai' 
                              ? Colors.green[900] 
                              : Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: isPaid
                ? const Chip(
                    label: Text('LUNAS', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                  )
                : ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaymentFormScreen(order: order),
                        ),
                      ).then((_) {
                        Provider.of<PaymentProvider>(context, listen: false)
                            .loadOrders();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Bayar'),
                  ),
            isThreeLine: true,
          ),
          if (isReadyForPickup || order.customerId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (order.customerId.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _showTransactionHistory(
                        context,
                        order.customerId,
                        order.customerName ?? 'Unknown',
                      ),
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('History'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  // Show "Notify Pickup" if not notified yet, otherwise show "Sudah Pickup"
                  if (canNotify) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _notifyPickup(order),
                      icon: const Icon(Icons.notifications, size: 16),
                      label: const Text('Notify Pickup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ] else if (isReadyForPickup && order.pickupNotified) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Sudah Pickup',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
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

  Widget _buildOutstandingItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
