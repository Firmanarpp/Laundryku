import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';

// Screen untuk add order baru - module 1
// Ada integrasi camera + upload foto ke Supabase Storage
// Form validation lengkap sebelum submit
class AddOrderScreen extends StatefulWidget {
  const AddOrderScreen({super.key});

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _weightController = TextEditingController();
  final _priceController = TextEditingController();
  
  Customer? _selectedCustomer;
  String _selectedService = 'Kiloan';
  bool _isLoading = false;
  String? _photoPath;
  List<Customer> _filteredCustomers = [];

  final List<String> _serviceTypes = ['Kiloan', 'Satuan', 'Express'];
  
  // METHOD Business Logic - Auto-Calculate Price
  // Pricing map untuk setiap jenis layanan (per kg)
  // Digunakan untuk calculate total harga = berat × harga per kg
  final Map<String, double> _servicePrices = {
    'Kiloan': 10000,   // Rp 10.000 per kg
    'Satuan': 15000,   // Rp 15.000 per kg
    'Express': 20000,  // Rp 20.000 per kg
  };

  // METHOD Business Logic - Auto-Calculate Price
  // Flow: parse weight → ambil price per kg → calculate total → update UI dengan setState
  void _calculatePrice() {
    final weight = double.tryParse(_weightController.text);
    if (weight != null && weight > 0) {
      final pricePerKg = _servicePrices[_selectedService] ?? 10000;
      final totalPrice = weight * pricePerKg;
      setState(() {
        _priceController.text = totalPrice.toStringAsFixed(0);
      });
    } else {
      setState(() {
        _priceController.text = '';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // onChanged sudah handle calculation, tidak perlu listener lagi
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).loadCustomers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _weightController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _filterCustomers(String query) {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = [];
      } else {
        _filteredCustomers = provider.customers
            .where((customer) => 
                customer.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  // Fungsi ambil foto pake camera
  // ImagePicker handle semua complexity request camera permission
  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    
    if (photo != null) {
      setState(() {
        _photoPath = photo.path;
      });
    }
  }

  // Complex flow: validation → upload photo → create order → feedback
  // Error handling dengan try-catch biar app ga crash kalo ada masalah
  // Loading state biar user tau prosesnya lagi jalan
  Future<void> _saveOrder() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih customer terlebih dahulu')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Step 1: Upload foto ke Supabase Storage dulu (kalo ada)
      String? photoUrl;
      if (_photoPath != null) {
        final fileName = 'order_${DateTime.now().millisecondsSinceEpoch}.jpg';
        photoUrl = await Provider.of<OrderProvider>(context, listen: false)
            .uploadOrderPhoto(_photoPath!, fileName);
      }

      // Step 2: Create order dengan photo URL dari storage
      // Step 2: Create order dengan photo URL dari storage
      final order = Order(
        id: '',
        customerId: _selectedCustomer!.id,
        weight: double.parse(_weightController.text),
        serviceType: _selectedService,
        price: double.parse(_priceController.text),
        status: 'terima',
        photoUrl: photoUrl, // Simpan URL, bukan local path!
        date: DateTime.now(),
      );

      // Step 3: Save ke database via Provider
      await Provider.of<OrderProvider>(context, listen: false)
          .addOrder(order);

      // Step 4: Kasih feedback ke user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order berhasil ditambahkan')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Order'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Customer Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pilih Customer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Cari nama customer',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _filteredCustomers = [];
                                      _selectedCustomer = null;
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: _filterCustomers,
                      ),
                      if (_filteredCustomers.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _filteredCustomers.length,
                            itemBuilder: (context, index) {
                              final customer = _filteredCustomers[index];
                              return ListTile(
                                title: Text(customer.name),
                                subtitle: Text('${customer.phone} - ${customer.address}'),
                                onTap: () {
                                  setState(() {
                                    _selectedCustomer = customer;
                                    _searchController.text = customer.name;
                                    _filteredCustomers = [];
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                      if (_selectedCustomer != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedCustomer!.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(_selectedCustomer!.phone),
                                    Text(_selectedCustomer!.address),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Order Details
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Berat (kg)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.scale),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _calculatePrice(); // Trigger calculation setiap kali berat berubah
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Berat harus diisi';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedService,
                decoration: const InputDecoration(
                  labelText: 'Jenis Layanan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_laundry_service),
                ),
                items: _serviceTypes.map((service) {
                  return DropdownMenuItem(
                    value: service,
                    child: Text(service),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedService = value!;
                    _calculatePrice(); // Recalculate saat service berubah
                  });
                },
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Harga (Rp)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.attach_money),
                  suffixIcon: const Icon(Icons.info_outline, color: Colors.grey),
                  helperText: 'Rp ${_servicePrices[_selectedService]?.toStringAsFixed(0) ?? '10000'} per kg (otomatis)',
                  helperStyle: const TextStyle(color: Colors.green),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                readOnly: true, // Tidak bisa diedit manual
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Silakan isi berat terlebih dahulu';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Photo
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(_photoPath == null ? 'Ambil Foto Pakaian' : 'Ganti Foto'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  if (_photoPath != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Image.file(
                                File(_photoPath!),
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: CircleAvatar(
                                  backgroundColor: Colors.white,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () {
                                      setState(() => _photoPath = null);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Foto siap disimpan',
                                    style: TextStyle(
                                      color: Colors.grey[700],
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
                  ],
                ],
              ),
              
              const SizedBox(height: 24),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _saveOrder,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Simpan Order', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
