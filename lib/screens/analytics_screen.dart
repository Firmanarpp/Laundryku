import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/analytics_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AnalyticsProvider>(context, listen: false).loadAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AnalyticsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadAnalytics(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Daily Revenue
                  _buildSectionTitle('Pendapatan Hari Ini'),
                  Card(
                    color: Colors.purple[50],
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet,
                            size: 48,
                            color: Colors.purple,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Rp ${_formatPrice(provider.dailyRevenue)}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                          Text(
                            DateFormat('dd MMMM yyyy').format(DateTime.now()),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Service Type Breakdown
                  _buildSectionTitle('Breakdown Layanan'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: provider.serviceBreakdown.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text('Belum ada data'),
                              ),
                            )
                          : Column(
                              children: [
                                SizedBox(
                                  height: 200,
                                  child: PieChart(
                                    PieChartData(
                                      sections: _buildPieChartSections(
                                        provider.serviceBreakdown,
                                      ),
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 40,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ...provider.serviceBreakdown.entries.map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: _getServiceColor(entry.key),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(entry.key),
                                          ],
                                        ),
                                        Text(
                                          '${entry.value} order',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Customer Frequency
                  _buildSectionTitle('Top Customers'),
                  Card(
                    child: provider.customerFrequency.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: Text('Belum ada data')),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: provider.customerFrequency.length > 5
                                ? 5
                                : provider.customerFrequency.length,
                            separatorBuilder: (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final customer = provider.customerFrequency[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.purple,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(customer['name']),
                                trailing: Chip(
                                  label: Text('${customer['count']} order'),
                                  backgroundColor: Colors.purple[100],
                                ),
                              );
                            },
                          ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Monthly Summary
                  _buildSectionTitle('Ringkasan Bulan Ini'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildSummaryRow(
                            'Total Pendapatan',
                            'Rp ${_formatPrice(provider.monthlyRevenue)}',
                            Colors.green,
                          ),
                          const Divider(height: 24),
                          _buildSummaryRow(
                            'Jumlah Transaksi',
                            '${provider.monthlyTransactionCount}',
                            Colors.blue,
                          ),
                          const Divider(height: 24),
                          _buildSummaryRow(
                            'Rata-rata per Transaksi',
                            'Rp ${_formatPrice(provider.monthlyTransactionCount > 0 ? provider.monthlyRevenue / provider.monthlyTransactionCount : 0)}',
                            Colors.orange,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildPieChartSections(Map<String, int> data) {
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.red,
      Colors.purple,
    ];
    
    int index = 0;
    return data.entries.map((entry) {
      final color = colors[index % colors.length];
      index++;
      
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: entry.value.toString(),
        color: color,
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Color _getServiceColor(String service) {
    switch (service) {
      case 'Kiloan':
        return Colors.blue;
      case 'Satuan':
        return Colors.orange;
      case 'Express':
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
