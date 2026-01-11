import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'providers/order_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/analytics_provider.dart';
import 'screens/order_management_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/analytics_screen.dart';
import 'services/local_database_service.dart';
import 'services/notification_service.dart';

// Entry point app - semua dimulai dari sini
// PENTING: Load environment variables & init databases sebelum app jalan
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables dari .env file (Security)
  await dotenv.load(fileName: ".env");
  
  // Initialize Supabase dulu sebelum app jalan
  // Credentials diambil dari .env - security best practice!
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  
  // Initialize Local Database (SQLite) untuk offline support
  await LocalDatabaseService.instance.database;
  
  // Initialize Notification Service untuk local notifications
  await NotificationService.instance.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider: setup state management untuk seluruh app
    // 3 Provider untuk 3 module berbeda - separation of concerns
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
      ],
      child: Builder(
        builder: (context) {
          // Set context untuk notification service setelah MaterialApp ready
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificationService.instance.setContext(context);
          });
          
          return MaterialApp(
            title: 'LaundryKu',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
            ),
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const OrderManagementScreen(),
    const PaymentScreen(),
    const AnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_laundry_service),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payment),
            label: 'Payment',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }
}
