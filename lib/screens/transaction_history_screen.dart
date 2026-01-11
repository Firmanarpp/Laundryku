import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../providers/payment_provider.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final String customerId;
  final String customerName;

  const TransactionHistoryScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PaymentProvider>(context, listen: false).loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History - ${widget.customerName}'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Consumer<PaymentProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filter orders by customer
          final customerOrders = provider.orders
              .where((order) => order.customerId == widget.customerId)
              .toList();

          // Sort by date descending
          customerOrders.sort((a, b) => b.date.compareTo(a.date));

          if (customerOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada transaksi',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Calculate summary
          final totalOrders = customerOrders.length;
          final totalSpent = customerOrders.fold<double>(
            0,
            (sum, order) {
              final payment = provider.getPaymentForOrder(order.id);
              return payment != null ? sum + payment.amount : sum;
            },
          );
          final unpaidOrders = customerOrders.where((order) {
            return provider.getPaymentForOrder(order.id) == null;
          }).length;

          return Column(
            children: [
              // Summary Card
              Card(
                margin: const EdgeInsets.all(12),
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem(
                            'Total Order',
                            totalOrders.toString(),
                            Icons.shopping_bag,
                            Colors.blue,
                          ),
                          _buildSummaryItem(
                            'Total Belanja',
                            'Rp ${_formatPrice(totalSpent)}',
                            Icons.payment,
                            Colors.green,
                          ),
                          _buildSummaryItem(
                            'Belum Bayar',
                            unpaidOrders.toString(),
                            Icons.pending,
                            Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Transaction List
              Expanded(
                child: ListView.builder(
                  itemCount: customerOrders.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final order = customerOrders[index];
                    final payment = provider.getPaymentForOrder(order.id);
                    return _buildTransactionCard(order, payment);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(Order order, Payment? payment) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final isPaid = payment != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPaid ? Colors.green : Colors.orange,
          child: Icon(
            isPaid ? Icons.check_circle : Icons.pending,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                order.serviceType,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Chip(
              label: Text(
                order.status.toUpperCase(),
                style: const TextStyle(fontSize: 9),
              ),
              backgroundColor: _getStatusColor(order.status),
              labelStyle: const TextStyle(color: Colors.white),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Berat: ${order.weight} kg'),
            Text('Harga: Rp ${_formatPrice(order.price)}'),
            const SizedBox(height: 4),
            Text(
              dateFormat.format(order.date),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (payment != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.payment, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    '${payment.paymentMethod} - ${dateFormat.format(payment.paidDate)}',
                    style: const TextStyle(fontSize: 11, color: Colors.green),
                  ),
                ],
              ),
            ],
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'terima':
        return Colors.blue;
      case 'cuci':
        return Colors.purple;
      case 'setrika':
        return Colors.orange;
      case 'selesai':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
