import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/payment.dart';

// Local Database Service menggunakan SQLite
// Pattern: Singleton - hanya 1 instance database di seluruh app
// Offline-First: semua data disimpan lokal dulu, sync ke Supabase kemudian
class LocalDatabaseService {
  static final LocalDatabaseService instance = LocalDatabaseService._init();
  static Database? _database;

  LocalDatabaseService._init();

  // Lazy initialization - database dibuat saat pertama kali diakses
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('laundrykuu.db');
    return _database!;
  }

  // Initialize database dan buat semua tables
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  // Create all tables - dipanggil saat database pertama kali dibuat
  Future _createDB(Database db, int version) async {
    // ID type: INTEGER untuk auto increment
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const textNullable = 'TEXT';

    // Table: customers
    await db.execute('''
      CREATE TABLE customers (
        id $idType,
        name $textType,
        phone $textType UNIQUE,
        address $textType,
        created_at $textType,
        synced $intType DEFAULT 0
      )
    ''');

    // Table: orders
    await db.execute('''
      CREATE TABLE orders (
        id $idType,
        customer_id $intType,
        weight $realType,
        service_type $textType,
        price $realType,
        status $textType,
        photo_url $textNullable,
        pickup_notified $intType DEFAULT 0,
        pickup_date $textNullable,
        date $textType,
        synced $intType DEFAULT 0,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    // Table: payments
    await db.execute('''
      CREATE TABLE payments (
        id $idType,
        order_id $intType,
        amount $realType,
        payment_method $textType,
        paid_date $textType,
        synced $intType DEFAULT 0,
        FOREIGN KEY (order_id) REFERENCES orders (id)
      )
    ''');

    // Create indexes untuk performance optimization
    await db.execute('CREATE INDEX idx_customers_phone ON customers(phone)');
    await db.execute('CREATE INDEX idx_orders_customer_id ON orders(customer_id)');
    await db.execute('CREATE INDEX idx_orders_status ON orders(status)');
    await db.execute('CREATE INDEX idx_payments_order_id ON payments(order_id)');
  }

  // ==================== CUSTOMERS ====================

  Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    return await db.insert('customers', {
      'name': customer.name,
      'phone': customer.phone,
      'address': customer.address,
      'created_at': customer.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await database;
    final result = await db.query('customers', orderBy: 'created_at DESC');
    
    return result.map((json) => Customer(
      id: json['id'].toString(),
      name: json['name'] as String,
      phone: json['phone'] as String,
      address: json['address'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    )).toList();
  }

  Future<Customer?> searchCustomerByPhone(String phone) async {
    final db = await database;
    final result = await db.query(
      'customers',
      where: 'phone = ?',
      whereArgs: [phone],
    );

    if (result.isEmpty) return null;

    final json = result.first;
    return Customer(
      id: json['id'].toString(),
      name: json['name'] as String,
      phone: json['phone'] as String,
      address: json['address'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // ==================== ORDERS ====================

  Future<int> insertOrder(Order order) async {
    final db = await database;
    return await db.insert('orders', {
      'customer_id': int.parse(order.customerId),
      'weight': order.weight,
      'service_type': order.serviceType,
      'price': order.price,
      'status': order.status,
      'photo_url': order.photoUrl,
      'pickup_notified': order.pickupNotified ? 1 : 0,
      'pickup_date': order.pickupDate?.toIso8601String(),
      'date': order.date.toIso8601String(),
      'synced': 0,
    });
  }

  Future<List<Order>> getAllOrders() async {
    final db = await database;
    
    // JOIN dengan customers untuk dapat nama customer
    final result = await db.rawQuery('''
      SELECT orders.*, customers.name as customer_name
      FROM orders
      LEFT JOIN customers ON orders.customer_id = customers.id
      ORDER BY orders.date DESC
    ''');
    
    return result.map((json) => Order(
      id: json['id'].toString(),
      customerId: json['customer_id'].toString(),
      weight: (json['weight'] as num).toDouble(),
      serviceType: json['service_type'] as String,
      price: (json['price'] as num).toDouble(),
      status: json['status'] as String,
      photoUrl: json['photo_url'] as String?,
      pickupNotified: (json['pickup_notified'] as int) == 1,
      pickupDate: json['pickup_date'] != null 
          ? DateTime.parse(json['pickup_date'] as String) 
          : null,
      date: DateTime.parse(json['date'] as String),
      customerName: json['customer_name'] as String?,
    )).toList();
  }

  Future<List<Order>> getOrdersByCustomer(String customerId) async {
    final db = await database;
    
    final result = await db.rawQuery('''
      SELECT orders.*, customers.name as customer_name
      FROM orders
      LEFT JOIN customers ON orders.customer_id = customers.id
      WHERE orders.customer_id = ?
      ORDER BY orders.date DESC
    ''', [int.parse(customerId)]);
    
    return result.map((json) => Order(
      id: json['id'].toString(),
      customerId: json['customer_id'].toString(),
      weight: (json['weight'] as num).toDouble(),
      serviceType: json['service_type'] as String,
      price: (json['price'] as num).toDouble(),
      status: json['status'] as String,
      photoUrl: json['photo_url'] as String?,
      pickupNotified: (json['pickup_notified'] as int) == 1,
      pickupDate: json['pickup_date'] != null 
          ? DateTime.parse(json['pickup_date'] as String) 
          : null,
      date: DateTime.parse(json['date'] as String),
      customerName: json['customer_name'] as String?,
    )).toList();
  }

  Future<int> updateOrderStatus(String orderId, String status) async {
    final db = await database;
    return await db.update(
      'orders',
      {'status': status, 'synced': 0},
      where: 'id = ?',
      whereArgs: [int.parse(orderId)],
    );
  }

  Future<int> updateOrderPhoto(String orderId, String photoUrl) async {
    final db = await database;
    return await db.update(
      'orders',
      {'photo_url': photoUrl, 'synced': 0},
      where: 'id = ?',
      whereArgs: [int.parse(orderId)],
    );
  }

  Future<int> markPickupNotified(String orderId) async {
    final db = await database;
    return await db.update(
      'orders',
      {
        'pickup_notified': 1,
        'pickup_date': DateTime.now().toIso8601String(),
        'synced': 0,
      },
      where: 'id = ?',
      whereArgs: [int.parse(orderId)],
    );
  }

  // ==================== PAYMENTS ====================

  Future<int> insertPayment(Payment payment) async {
    final db = await database;
    return await db.insert('payments', {
      'order_id': int.parse(payment.orderId),
      'amount': payment.amount,
      'payment_method': payment.paymentMethod,
      'paid_date': payment.paidDate.toIso8601String(),
      'synced': 0,
    });
  }

  Future<List<Payment>> getAllPayments() async {
    final db = await database;
    final result = await db.query('payments', orderBy: 'paid_date DESC');
    
    return result.map((json) => Payment(
      id: json['id'].toString(),
      orderId: json['order_id'].toString(),
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      paidDate: DateTime.parse(json['paid_date'] as String),
    )).toList();
  }

  Future<Payment?> getPaymentByOrder(String orderId) async {
    final db = await database;
    final result = await db.query(
      'payments',
      where: 'order_id = ?',
      whereArgs: [int.parse(orderId)],
    );

    if (result.isEmpty) return null;

    final json = result.first;
    return Payment(
      id: json['id'].toString(),
      orderId: json['order_id'].toString(),
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      paidDate: DateTime.parse(json['paid_date'] as String),
    );
  }

  // ==================== ANALYTICS ====================

  Future<double> getDailyRevenue(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM payments
      WHERE paid_date >= ? AND paid_date < ?
    ''', [
      startOfDay.toIso8601String(),
      endOfDay.toIso8601String(),
    ]);
    
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, int>> getServiceTypeBreakdown() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT service_type, COUNT(*) as count
      FROM orders
      GROUP BY service_type
    ''');
    
    Map<String, int> breakdown = {};
    for (var row in result) {
      breakdown[row['service_type'] as String] = row['count'] as int;
    }
    
    return breakdown;
  }

  // ==================== SYNC MANAGEMENT ====================

  // Mark data as synced setelah berhasil upload ke Supabase
  Future<void> markCustomerSynced(String id) async {
    final db = await database;
    await db.update(
      'customers',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
  }

  Future<void> markOrderSynced(String id) async {
    final db = await database;
    await db.update(
      'orders',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
  }

  Future<void> markPaymentSynced(String id) async {
    final db = await database;
    await db.update(
      'payments',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
  }

  // Get unsynced data untuk di-sync ke Supabase
  Future<List<Map<String, dynamic>>> getUnsyncedCustomers() async {
    final db = await database;
    return await db.query('customers', where: 'synced = ?', whereArgs: [0]);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedOrders() async {
    final db = await database;
    return await db.query('orders', where: 'synced = ?', whereArgs: [0]);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedPayments() async {
    final db = await database;
    return await db.query('payments', where: 'synced = ?', whereArgs: [0]);
  }

  // Close database connection
  Future close() async {
    final db = await database;
    await db.close();
  }
}
