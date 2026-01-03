import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:resturant/HomeScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

// Add this constant
const String REFERER_HEADER = 'https://api-cloudchef.sltcloud.lk';     

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cloud Chef POS',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: Colors.blue.withOpacity(0.3),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const AuthCheckScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final token = await AuthService.getToken();
  
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => token != null ? const DashboardScreen() : const LoginScreen(),
        ),
      );
    }
  
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator.adaptive(),
            const SizedBox(height: 20),
            Text(
              'Cloud Chef POS',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 10),
            const Text('Loading...'),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter username and password'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true); 

    try {
      final response = await http.post(
        Uri.parse('https://api-cloudchef.sltcloud.lk/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'referer': REFERER_HEADER,
        },
        body: json.encode({
          'name': _usernameController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String? token = data['data']?['token'] ?? data['token'] ?? data['access_token'];
      
        if (token != null && token.isNotEmpty) {
          await AuthService.saveToken(token);
          
          final userResponse = await http.get(
            Uri.parse('https://api-cloudchef.sltcloud.lk/api/user'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'referer': REFERER_HEADER,
            },
          ).timeout(const Duration(seconds: 10));

          if (userResponse.statusCode == 200) {
            final userData = json.decode(userResponse.body);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_data', json.encode(userData));
          } else {
            throw Exception('Failed to fetch user data: ${userResponse.statusCode}');
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            );
          }
        } else {
          throw Exception('Login successful but no token received');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Login failed with status ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            margin: const EdgeInsets.all(20),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.point_of_sale, size: 64, color: Colors.blue),
                    ).animate().fadeIn(duration: 600.ms),
                  
                    const SizedBox(height: 20),
                  
                    Text(
                      'Cloud Chef POS',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  
                    const SizedBox(height: 8),
                  
                    Text(
                      'Welcome back! Please sign in',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  
                    const SizedBox(height: 24),
                  
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onSubmitted: (_) => _login(),
                    ),
                  
                    const SizedBox(height: 16),
                  
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onSubmitted: (_) => _login(),
                    ),
                  
                    const SizedBox(height: 24),
               
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'SIGN IN',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



class AuthService {
  static const String _tokenKey = 'auth_token';
 
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove('user_data');
  }

  static Future<bool> validateToken() async {
    final token = await getToken();
    if (token == null) return false;
  
    try {
      final response = await http.get(
        Uri.parse('https://api-cloudchef.sltcloud.lk/api/customers?page=1&limit=1'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'referer': REFERER_HEADER,
        },
      ).timeout(const Duration(seconds: 10));
    
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }
}

enum OrderType {
  retail('DINE IN', Icons.store, Colors.blue),
  whole('TAKE AWAY', Icons.warehouse, Colors.green),
  uber('UBER', Icons.directions_car, Colors.black),
  pickMe('PICK ME', Icons.handyman, Colors.orange),
  callOrder('CALL ORDER', Icons.phone, Colors.purple),
  onlineOrder('ONLINE ORDER', Icons.shopping_cart, Colors.red);

  final String displayName;
  final IconData icon;
  final Color color;

  const OrderType(this.displayName, this.icon, this.color);
}

class Customer {
  final int? id;
  final String name;
  final String phone;
  final String email;
  final String nic;
  final String address;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.nic,
    required this.address,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as int? ?? json['customer_id'] as int?,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      nic: json['nic'] ?? '',
      address: json['address'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'nic': nic,
        'address': address,
      };
}

class Waiter {
  final int id;
  final String name;

  Waiter({
    required this.id,
    required this.name,
  });

  factory Waiter.fromJson(Map<String, dynamic> json) {
    return Waiter(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
  };
}

class Product {
  final int id;
  final String name;
  final String unit;
  final String barCode;
  final int tblStockId;
  final int tblCategoryId;
  final String? productImage;
  final String stockName;
  int availableQuantity; 
  final double price;
  final double cost;
  final double wsPrice;
  final String lotNumber;
  final String? expiryDate;
  List<dynamic> lotsqty; 

  Product({
    required this.id,
    required this.name,
    required this.unit,
    required this.barCode,
    required this.tblStockId,
    required this.tblCategoryId,
    required this.productImage,
    required this.stockName,
    required this.availableQuantity,
    required this.price,
    required this.cost,
    required this.wsPrice,
    required this.lotNumber,
    required this.expiryDate,
    required this.lotsqty,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    List<dynamic> lotsqty = json['lotsqty'] ?? [];
    Map<String, dynamic>? selectedLot;
  
    if (lotsqty.isNotEmpty) {
      for (var lot in lotsqty) {
        final qty = int.tryParse(lot['qty']?.toString() ?? '0') ?? 0;
        if (qty > 0) {
          selectedLot = lot;
          break;
        }
      }
      if (selectedLot == null && lotsqty.isNotEmpty) {
        selectedLot = lotsqty[0];
      }
    }

    double price = 0.0;
    double cost = 0.0;
    double wsPrice = 0.0;
    String lotNumber = '';
    String? expiryDate;

    if (selectedLot != null) {
      price = double.tryParse(selectedLot['retail_price']?.toString() ?? '0') ?? 0.0;
      cost = double.tryParse(selectedLot['cost']?.toString() ?? '0') ?? 0.0;
      wsPrice = double.tryParse(selectedLot['ws_price']?.toString() ?? '0') ?? 0.0;
      lotNumber = selectedLot['lot_number']?.toString() ?? '';
      expiryDate = selectedLot['ex_date']?.toString();
    }

    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      unit: json['unit'] ?? '',
      barCode: json['bar_code'] ?? '',
      tblStockId: json['tbl_stock_id'] ?? 0,
      tblCategoryId: json['tbl_category_id'] ?? 0,
      productImage: json['product_image'],
      stockName: json['stock'] != null ? json['stock']['stock_name'] ?? 'Main' : 'Main',
      availableQuantity: _calculateAvailableQuantity(lotsqty),
      price: price,
      cost: cost,
      wsPrice: wsPrice,
      lotNumber: lotNumber,
      expiryDate: expiryDate,
      lotsqty: lotsqty,
    );
  }

  static int _calculateAvailableQuantity(List<dynamic> lotsqty) {
    if (lotsqty.isEmpty) return 0;
    return lotsqty.fold(0, (sum, lot) => sum + (int.tryParse(lot['qty']?.toString() ?? '0') ?? 0));
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'unit': unit,
    'bar_code': barCode,
    'tbl_stock_id': tblStockId,
    'tbl_category_id': tblCategoryId,
    'product_image': productImage,
    'stock_name': stockName,
    'available_quantity': availableQuantity,
    'price': price,
    'cost': cost,
    'ws_price': wsPrice,
    'lot_number': lotNumber,
    'expiry_date': expiryDate,
    'lotsqty': lotsqty,
  };

  void updateStock(int quantity) {
    availableQuantity = quantity;
  }

  void reduceStock(int quantityToReduce) {
    if (quantityToReduce <= availableQuantity) {
      availableQuantity -= quantityToReduce;
    }
  }
}

class CartItem {
  final Product product;
  int quantity;
  String discountType;
  double discountValue;
  bool isNewItem; // Track if this is a newly added item (for due tables)

  CartItem({
    required this.product,
    required this.quantity,
    this.discountType = 'none',
    this.discountValue = 0.0,
    this.isNewItem = true, // Default to true for new items
  });

  double getPriceByOrderType(OrderType orderType) {
    switch (orderType) {
      case OrderType.whole:
        return product.wsPrice;
      default:
        return product.price;
    }
  }

  double getSubtotal(OrderType orderType) => getPriceByOrderType(orderType) * quantity;

  double getDiscount(OrderType orderType) => discountType == '%'
      ? getSubtotal(orderType) * (discountValue / 100)
      : (discountType == 'value' ? discountValue : 0.0);

  double getTotalPrice(OrderType orderType) => getSubtotal(orderType) - getDiscount(orderType);
}

class Category {
  final int id;
  final String categoryName;

  Category({
    required this.id,
    required this.categoryName,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      categoryName: json['category_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category_name': categoryName,
  };
}

class Table {
  final int id;
  final String name;
  final double serviceCharge;
  bool hasDueOrders;
  String specialNote; // ADDED: Special note for table

  Table({
    required this.id,
    required this.name,
    required this.serviceCharge,
    this.hasDueOrders = false,
    this.specialNote = '', // ADDED: Default empty special note
  });

  factory Table.fromJson(Map<String, dynamic> json) {
    return Table(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      serviceCharge: double.tryParse(json['service_charge']?.toString() ?? '0') ?? 0.0,
      hasDueOrders: json['has_due_orders'] ?? false,
      specialNote: json['special_note'] ?? '', // ADDED: Load special note from JSON
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'service_charge': serviceCharge,
    'has_due_orders': hasDueOrders,
    'special_note': specialNote, // ADDED: Include special note in JSON
  };
}

class Order {
  final int id;
  final String orderNumber;
  final double totalAmount;
  final String status;
  final DateTime orderDate;
  final String? customerName;
  final String? tableName;
  final String? invoiceNumber; 

  Order({
    required this.id,
    required this.orderNumber,
    required this.totalAmount,
    required this.status,
    required this.orderDate,
    this.customerName,
    this.tableName,
    this.invoiceNumber, 
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? '',
      orderDate: DateTime.parse(json['order_date'] ?? DateTime.now().toString()),
      customerName: json['customer_name'],
      tableName: json['table_name'],
      invoiceNumber: json['invoice_code'] ?? json['invoice_number'] ?? '', 
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order_number': orderNumber,
    'total_amount': totalAmount,
    'status': status,
    'order_date': orderDate.toIso8601String(),
    'customer_name': customerName,
    'table_name': tableName,
    'invoice_number': invoiceNumber,
  };
}

class PrinterType {
  static const String cashier = 'CASHIER';
  static const String kitchen = 'KITCHEN';
}

class NumPad extends StatelessWidget {
  final TextEditingController controller;
  final bool allowDecimal;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final VoidCallback? onValueChanged;

  const NumPad({
    super.key,
    required this.controller,
    this.allowDecimal = true,
    this.onConfirm,
    this.onCancel,
    this.onValueChanged,
  });

  void _addText(String text) {
    if (text == '.' && !allowDecimal) return;
    if (text == '.' && controller.text.contains('.')) return;
  
    controller.text += text;
    onValueChanged?.call();
  }

  void _backspace() {
    if (controller.text.isNotEmpty) {
      controller.text = controller.text.substring(0, controller.text.length - 1);
    }
    onValueChanged?.call();
  }

  void _clear() {
    controller.text = ''; 
    onValueChanged?.call();
  }

  Widget _buildKeypadButton(String text, {Color color = Colors.blue, double fontSize = 20}) {
    return ElevatedButton(
      onPressed: () {
        if (text == '<') {
          _backspace();
        } else if (text == 'C') {
          _clear();
        } else if (text == 'OK' && onConfirm != null) {
          onConfirm!();
        } else if (text == 'Cancel' && onCancel != null) {
          onCancel!();
        } else {
          _addText(text);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.all(16),
        elevation: 2,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildKeypadButton('7')),
                const SizedBox(width: 8),
                Expanded(child: _buildKeypadButton('8')),
                const SizedBox(width: 8),
                Expanded(child: _buildKeypadButton('9')),
                const SizedBox(width: 8),
                Expanded(child: _buildKeypadButton('C', color: Colors.red)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildKeypadButton('4')),
                const SizedBox(width: 8),
                Expanded(child: _buildKeypadButton('5')),
                const SizedBox(width: 8),
                Expanded(child: _buildKeypadButton('6')),
                const SizedBox(width: 8),
                Expanded(child: _buildKeypadButton('<', color: Colors.orange)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildKeypadButton('1')),
                const SizedBox(width: 8),
                Expanded(child: _buildKeypadButton('2')),
                const SizedBox(width: 8),
                Expanded(child: _buildKeypadButton('3')),
                const SizedBox(width: 8),
                Expanded(child: _buildKeypadButton('00')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildKeypadButton('0')),
                const SizedBox(width: 8),
                if (allowDecimal) Expanded(child: _buildKeypadButton('.')),
                if (!allowDecimal) const Expanded(child: SizedBox()),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKeypadButton(
                    'Cancel',
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKeypadButton(
                    'OK',
                    color: Colors.green,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      )
    );
    }
  }


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  List<Waiter> _waiters = [];
  List<Waiter> _filteredWaiters = [];
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<CartItem> _cartItems = [];
  List<Category> _categories = [];
  List<Table> _tables = [];
  List<Table> _filteredTables = [];
  List<Order> _orders = [];
  Category? _selectedCategory;
  
  // FIXED: Add flags to track what data has been loaded
  bool _dataLoaded = false;
  bool _isInitialLoading = true;
  bool _isLoading = false;
  bool _isLoadingProducts = false;
  
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _productSearchController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _tableSearchController = TextEditingController();
  final TextEditingController _waiterSearchController = TextEditingController();
  Customer? _selectedCustomer;
  Waiter? _selectedWaiter;
  Table? _selectedTable;
  OrderType _selectedOrderType = OrderType.retail;
  int? _currentInvoiceId;
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  List<BluetoothDevice> _devices = [];
  List<BluetoothDevice> _connectedCashierDevices = [];
  List<BluetoothDevice> _connectedKitchenDevices = [];
  List<BluetoothConnection> _connections = [];
  bool _isScanning = false;
  bool _isBluetoothEnabled = false;
  int _orderNumber = 1;
  static const String defaultCashierPrinterName = 'Printer001';
  static const String defaultKitchenPrinterName = '4B-2023PA-EE15';
  double _serviceAmountOverride = 0.0;
  Map<String, dynamic>? _cartDataForPrinting;
  bool _showListView = true;
  
  // Add this variable to track if we're editing a due table
  bool _isEditingDueTable = false;
  // Add this variable to store the existing items from due table
  List<Map<String, dynamic>> _existingDueTableItems = [];
  // Add this flag to track if we're processing due table payment
  bool _isProcessingDueTablePayment = false;
  
  // Add this map to store special notes locally
  Map<int, String> _tableSpecialNotes = {};

  @override
  void initState() {
    super.initState();
    // Start loading data immediately
    _initializeApp();
    _discountController.addListener(_updateCartTotals);
    _checkBluetoothStatus();
    _requestPermissions();
    _loadLocalTableNotes();
  }

  @override
  void dispose() {
    for (var connection in _connections) {
      connection.finish();
    }
    super.dispose();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _isInitialLoading = true;
      _dataLoaded = false;
    });
    
    final token = await AuthService.getToken();
    if (token == null) {
      await _handleUnauthorized();
      return;
    }
    
    // Load data in parallel where possible
    await Future.wait([
      _loadCategories(),
      _loadProducts(),
      _loadTables(),
      _loadWaiters(),
      _loadOrders(),
    ]);
    
    setState(() {
      _isInitialLoading = false;
      _dataLoaded = true;
    });
  }

  Future<void> _loadOrders() async {
    if (!_dataLoaded) return;
    
    setState(() => _isLoading = true);
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('https://api-cloudchef.sltcloud.lk/api/order'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> ordersData = data is List ? data : (data['data'] ?? []);
      
        _orders = ordersData.map((e) => Order.fromJson(e)).toList();
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
      } else {
        throw Exception('Failed to load orders: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load orders: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _findTableBill(String tableName) async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Products not loaded yet. Please wait.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
  
    try {
      final headers = await _getAuthHeaders();
    
      final endpoints = [
        'https://api-cloudchef.sltcloud.lk/api/invoice-create/table-bill-find',
        'https://api-cloudchef.sltcloud.lk/api/table-bill-find',
        'https://api-cloudchef.sltcloud.lk/api/invoices/table/$tableName',
      ];

      http.Response? response;
      for (var endpoint in endpoints) {
        try {
          response = await http.post(
            Uri.parse(endpoint),
            headers: headers,
            body: json.encode({'table_name': tableName, 'tableFindInput': tableName}),
          ).timeout(const Duration(seconds: 10));
        
          if (response.statusCode == 200) break;
        } catch (e) {
          continue;
        }
      }

      if (response == null || response.statusCode != 200) {
        setState(() {
          _cartItems.clear();
          _currentInvoiceId = null;
          _selectedCustomer = null;
          _selectedWaiter = null;
          _discountController.text = '0';
          _serviceAmountOverride = 0.0;
          _isEditingDueTable = false;
          _existingDueTableItems.clear();
        });
      
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No active bill found for table "$tableName". Starting fresh order.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final jsonData = json.decode(response.body);
      final data = jsonData['data'] ?? jsonData;
    
      setState(() {
        _cartItems.clear();
        _currentInvoiceId = null;
        _serviceAmountOverride = 0.0;
        _isEditingDueTable = true; // Set to true since we're loading a due table
        _existingDueTableItems.clear();
      });

      final inv = data['inv'] ?? data['invoice'] ?? {};
      _currentInvoiceId = inv['id'] ?? inv['invoice_id'];
    
      final waiterId = inv['waiter_id'] ?? 0;
      final waiterName = inv['waiter_name'] ?? '';
      if (waiterId > 0) {
        _selectedWaiter = _waiters.firstWhere(
          (w) => w.id == waiterId,
          orElse: () => Waiter(id: waiterId, name: waiterName),
        );
      }

      final customerName = inv['customer_name'] ?? inv['customer'] ?? '';
      final customerId = inv['customer_id'] ?? inv['tbl_customer_id'] ?? null;
      if (customerName.isNotEmpty) {
        _selectedCustomer = _customers.firstWhere(
          (c) => c.name == customerName,
          orElse: () => Customer(
            id: customerId,
            name: customerName,
            phone: inv['phone'] ?? '',
            email: inv['email'] ?? '',
            nic: inv['nic'] ?? '',
            address: inv['address'] ?? '',
          ),
        );
      }

      final saleType = inv['sale_type'] ?? 'RETAIL';
      _selectedOrderType = OrderType.values.firstWhere(
        (ot) => ot.displayName == saleType,
        orElse: () => OrderType.retail,
      );

      final billDis = double.tryParse(inv['bill_dis']?.toString() ?? '0') ?? 0.0;
      _discountController.text = billDis.toString();

      final serviceAmount = double.tryParse(inv['service_charge']?.toString() ?? '0') ?? 0.0;
      _serviceAmountOverride = serviceAmount;

      List<dynamic> itemsData = data['invB'] ?? data['items'] ?? data['order_items'] ?? [];
    
      // Store the existing items for reference
      _existingDueTableItems = List<Map<String, dynamic>>.from(itemsData);
    
      int loadedItems = 0;
      for (var itemData in itemsData) {
        try {
          var productId = itemData['product_id'] ?? itemData['tbl_product_id'];
          final barCode = itemData['bar_code'];
          final productName = itemData['name'] ?? 'Unknown Product';
        
          Product product = _products.firstWhere(
            (p) => p.id == productId || p.barCode == barCode,
            orElse: () => Product(
              id: productId ?? 0,
              name: productName,
              unit: itemData['unit'] ?? '',
              barCode: barCode ?? '',
              tblStockId: itemData['tbl_stock_id'] ?? 0,
              tblCategoryId: itemData['tbl_category_id'] ?? 0,
              productImage: null,
              stockName: itemData['stock']?['stock_name'] ?? itemData['stock_name'] ?? 'Main',
              availableQuantity: int.tryParse(itemData['qty']?.toString() ?? '0') ?? 0,
              price: double.tryParse(itemData['price']?.toString() ?? '0') ?? 0.0,
              cost: double.tryParse(itemData['cost']?.toString() ?? '0') ?? 0.0,
              wsPrice: double.tryParse(itemData['ws_price']?.toString() ?? itemData['price']?.toString() ?? '0') ?? 0.0,
              lotNumber: itemData['lot_id']?.toString() ?? itemData['lot_number'] ?? '',
              expiryDate: itemData['ex_date'] ?? itemData['expiry_date'],
              lotsqty: [],
            ),
          );

          final quantity = int.tryParse(itemData['qty']?.toString() ?? '1') ?? 1;
          String discountType = itemData['discount_type'] ?? 'none';
          double discountValue = double.tryParse(itemData['discount_value']?.toString() ?? '0') ?? 0.0;

          if (discountType == 'none') {
            final dis = double.tryParse(itemData['dis']?.toString() ?? '0') ?? 0.0;
            final disVal = double.tryParse(itemData['disVal']?.toString() ?? '0') ?? 0.0;
            if (dis > 0) {
              discountType = '%';
              discountValue = dis;
            } else if (disVal > 0) {
              discountType = 'value';
              discountValue = disVal;
            }
          }

          _cartItems.add(CartItem(
            product: product,
            quantity: quantity,
            discountType: discountType,
            discountValue: discountValue,
            isNewItem: false, // These are existing items, not new
          ));
          loadedItems++;
        } catch (e) {
          print('Error loading item: $e');
        }
      }

      _updateCartTotals();
    
    
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading table bill: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

Future<void> _loadTableItems() async {
  if (_selectedTable == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please select a table first'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  // Clear cart items first when selecting any table
  _clearCart();

  try {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('https://api-cloudchef.sltcloud.lk/api/invoice-create/table-bill-find'),
      headers: headers,
      body: json.encode({'table_name': _selectedTable!.name}),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      // If table has existing bill, load it
      await _findTableBill(_selectedTable!.name);
      return;
    }
  } catch (e) {
    // No existing bill found - this is a fresh table
    print('No existing bill for table ${_selectedTable!.name}: $e');
  }

  // If no existing bill or error, clear everything and set fresh table
  setState(() {
    _cartItems.clear();
    _currentInvoiceId = null;
    _serviceAmountOverride = 0.0;
    _isEditingDueTable = false;
    _existingDueTableItems.clear();
    
    // IMPORTANT: Keep the table with its special note when fresh
    if (_selectedTable != null) {
      // Check if we have a local special note for this table
      final localNote = _tableSpecialNotes[_selectedTable!.id];
      _selectedTable = Table(
        id: _selectedTable!.id,
        name: _selectedTable!.name,
        serviceCharge: _selectedTable!.serviceCharge,
        hasDueOrders: false, // Explicitly set to false for fresh table
        specialNote: localNote ?? '', // Keep existing special note or empty
      );
    }
  });
}

  // NEW: Show special note dialog when saving invoice
  Future<String?> _showSaveInvoiceNoteDialog() async {
    final noteController = TextEditingController();
    
    // Load existing special note if any
    if (_selectedTable != null && _selectedTable!.specialNote.isNotEmpty) {
      noteController.text = _selectedTable!.specialNote;
    }
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Special Note for Table ${_selectedTable?.name ?? ''}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: noteController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Enter special note for this table...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, null),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final note = noteController.text.trim();
                              Navigator.pop(context, note);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'OK',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _requestPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
    
      if (statuses.values.any((status) => !status.isGranted)) {
        _showMessage('Please grant all Bluetooth permissions');
      }
    } catch (e) {
      _showMessage('Permission error: $e');
    }
  }

  Future<void> _checkBluetoothStatus() async {
    try {
      bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      setState(() {
        _isBluetoothEnabled = isEnabled ?? false;
      });
    
      if (_isBluetoothEnabled) {
        _autoConnectToDefaultPrinters();
      }
    } catch (e) {
      _showMessage('Bluetooth status check error: $e');
    }
  }

  Future<void> _autoConnectToDefaultPrinters() async {
    try {
      List<BluetoothDevice> bondedDevices = await _bluetooth.getBondedDevices();
    
      BluetoothDevice? cashierPrinter;
      BluetoothDevice? kitchenPrinter;
    
      for (var device in bondedDevices) {
        if (device.name == defaultCashierPrinterName) {
          cashierPrinter = device;
        } else if (device.name == defaultKitchenPrinterName) {
          kitchenPrinter = device;
        }
      }
    
      if (cashierPrinter != null) {
        await _connectToDevice(cashierPrinter, PrinterType.cashier, isAutoConnect: true);
      }
    
      if (kitchenPrinter != null) {
        await _connectToDevice(kitchenPrinter, PrinterType.kitchen, isAutoConnect: true);
      }
    } catch (e) {
      print('Auto-connect error: $e');
    }
  }

  Future<void> _scanDevices() async {
    if (!_isBluetoothEnabled) {
      _showMessage('Please enable Bluetooth');
      return;
    }

    setState(() {
      _isScanning = true;
      _devices = [];
    });

    try {
      _devices = await _bluetooth.getBondedDevices();
    
      final stream = _bluetooth.startDiscovery();
      stream.listen((BluetoothDiscoveryResult result) {
        final device = result.device;
        if (device.name != null && !_devices.any((d) => d.address == device.address)) {
          setState(() {
            _devices.add(device);
          });
        }
      });

      await Future.delayed(const Duration(seconds: 10));
      await _bluetooth.cancelDiscovery();
    } catch (e) {
      _showMessage('Scan error: $e');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device, String printerType, {bool isAutoConnect = false}) async {
    bool isAlreadyConnected = false;
    if (printerType == PrinterType.cashier) {
      isAlreadyConnected = _connectedCashierDevices.any((d) => d.address == device.address);
    } else {
      isAlreadyConnected = _connectedKitchenDevices.any((d) => d.address == device.address);
    }
  
    if (isAlreadyConnected) {
      if (!isAutoConnect) {
        _showMessage('Already connected to ${device.name} as $printerType printer');
      }
      return;
    }

    try {
      final connection = await BluetoothConnection.toAddress(device.address);
      connection.input!.listen((data) {
       
      }).onDone(() {
        setState(() {
          _connections.removeWhere((conn) => _getDeviceForConnection(conn)?.address == device.address);
          _connectedCashierDevices.removeWhere((d) => d.address == device.address);
          _connectedKitchenDevices.removeWhere((d) => d.address == device.address);
        });
        if (!isAutoConnect) {
          _showMessage('${device.name} disconnected');
        }
      });

      setState(() {
        _connections.add(connection);
        if (printerType == PrinterType.cashier) {
          _connectedCashierDevices.add(device);
        } else {
          _connectedKitchenDevices.add(device);
        }
      });
    
      if (!isAutoConnect) {
        _showMessage('Connected to ${device.name} as $printerType printer');
      }
    } catch (e) {
      if (!isAutoConnect) {
        _showMessage('Failed to connect to ${device.name}: $e');
      }
    }
  }

  BluetoothDevice? _getDeviceForConnection(BluetoothConnection connection) {
    try {
      int cashierIndex = _connections.indexOf(connection);
      if (cashierIndex >= 0 && cashierIndex < _connectedCashierDevices.length) {
        return _connectedCashierDevices[cashierIndex];
      }
    
      int kitchenIndex = _connections.indexOf(connection) - _connectedCashierDevices.length;
      if (kitchenIndex >= 0 && kitchenIndex < _connectedKitchenDevices.length) {
        return _connectedKitchenDevices[kitchenIndex];
      }
    
      return null;
    } catch (e) {
      return null;
    }
  }

  String _getPrinterTypeForDevice(BluetoothDevice device) {
    if (_connectedCashierDevices.any((d) => d.address == device.address)) {
      return PrinterType.cashier;
    } else if (_connectedKitchenDevices.any((d) => d.address == device.address)) {
      return PrinterType.kitchen;
    }
    return 'UNKNOWN';
  }

  Future<void> _disconnectDevice(BluetoothDevice device) async {
    try {
      final String printerType = _getPrinterTypeForDevice(device);
      List<BluetoothDevice> targetList = printerType == PrinterType.cashier
          ? _connectedCashierDevices
          : _connectedKitchenDevices;
        
      final index = targetList.indexWhere((d) => d.address == device.address);
      if (index >= 0) {
        int connectionIndex = printerType == PrinterType.cashier
            ? index
            : _connectedCashierDevices.length + index;
          
        if (connectionIndex < _connections.length) {
          await _connections[connectionIndex].finish();
          setState(() {
            _connections.removeAt(connectionIndex);
            targetList.removeAt(index);
          });
          _showMessage('Disconnected from ${device.name}');
        }
      }
    } catch (e) {
      _showMessage('Error disconnecting: $e');
    }
  }

  Future<void> _disconnectAllDevices() async {
    for (var connection in _connections) {
      await connection.finish();
    }
    setState(() {
      _connections.clear();
      _connectedCashierDevices.clear();
      _connectedKitchenDevices.clear();
    });
    _showMessage('Disconnected from all printers');
  }

Future<List<int>> _generateReceipt(Map<String, dynamic> cartData) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    String printerType = cartData['printerType'];
    List<CartItem> cartItems = cartData['cartItems'];
    OrderType selectedOrderType = cartData['selectedOrderType'];
    Customer? selectedCustomer = cartData['selectedCustomer'];
    Table? selectedTable = cartData['selectedTable'];
    double totalSubtotal = cartData['totalSubtotal'];
    double totalItemDiscount = cartData['totalItemDiscount'];
    double discountPercentage = cartData['discountPercentage'];
    double globalDiscountValue = cartData['globalDiscountValue'];
    double serviceAmount = cartData['serviceAmount'];
    double netAmount = cartData['netAmount'];
    int orderNumber = cartData['orderNumber'];
    String? invoiceNumber = cartData['invoiceNumber'];
    bool isBillCopy = cartData['isBillCopy'] ?? false;

    if (printerType == PrinterType.cashier) {
      // ================= HEADER =================
      bytes += generator.text(
        'KAFENIO COLOMBO',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size3, // INCREASED from size2 to size3
          width: PosTextSize.size2, // ADDED width for larger font
        ),
      );

      bytes += generator.text(
        'NO-32, Hospital Street, Colombo 1',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2, // INCREASED font size
        ),
      );

      bytes += generator.text(
        'Tel: 0712901901',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2, // INCREASED font size
        ),
      );

      bytes += generator.hr();

      // Bill Copy Header if it's a copy
      if (isBillCopy) {
        bytes += generator.text(
          '*** BILL COPY ***',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            reverse: true,
            height: PosTextSize.size2, // INCREASED font size
          ),
        );
        bytes += generator.hr();
      }

      // FIXED: Always print the invoice number from system
      bytes += generator.text(
        'Invoice No: ${invoiceNumber ?? 'INV-${DateTime.now().millisecondsSinceEpoch}'}',
        styles: const PosStyles(
          align: PosAlign.left,
          bold: true,
          height: PosTextSize.size2, // INCREASED font size
        ),
      );
      
      bytes += generator.text(
        'Cashier: POS User',
        styles: const PosStyles(
          align: PosAlign.left,
          height: PosTextSize.size2, // INCREASED font size
        ),
      );
      
      bytes += generator.text(
        'Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
        styles: const PosStyles(
          align: PosAlign.right,
          height: PosTextSize.size2, // INCREASED font size
        ),
      );

      bytes += generator.text(
        'Time: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
        styles: const PosStyles(
          align: PosAlign.right,
          height: PosTextSize.size2, // INCREASED font size
        ),
      );

      if (selectedCustomer != null) {
        bytes += generator.text(
          'Customer: ${selectedCustomer.name}',
          styles: const PosStyles(
            align: PosAlign.left,
            height: PosTextSize.size2, // INCREASED font size
          ),
        );
      }

      if (selectedTable != null) {
        bytes += generator.text(
          'Table: ${selectedTable.name}',
          styles: const PosStyles(
            align: PosAlign.left,
            height: PosTextSize.size2, // INCREASED font size
          ),
        );
        // ADDED: Print special note if exists
        if (selectedTable!.specialNote.isNotEmpty) {
          bytes += generator.text(
            'Note: ${selectedTable!.specialNote}',
            styles: const PosStyles(
              align: PosAlign.left,
              fontType: PosFontType.fontB,
              height: PosTextSize.size2, // INCREASED font size
            ),
          );
        }
      }

      bytes += generator.text(
        'Order Type: ${selectedOrderType.displayName}',
        styles: const PosStyles(
          align: PosAlign.left,
          height: PosTextSize.size2, // INCREASED font size
        ),
      );

      bytes += generator.hr(ch: '-');

      // ================= TABLE HEADER =================
      bytes += generator.row([
        PosColumn(
          text: 'Qty',
          width: 2,
          styles: const PosStyles(
            bold: true,
            height: PosTextSize.size2, // INCREASED font size
          ),
        ),
        PosColumn(
          text: 'Unit Price',
          width: 3,
          styles: const PosStyles(
            bold: true,
            align: PosAlign.center,
            height: PosTextSize.size2, // INCREASED font size
          ),
        ),
        PosColumn(
          text: 'Dis',
          width: 3,
          styles: const PosStyles(
            bold: true,
            align: PosAlign.center,
            height: PosTextSize.size2, // INCREASED font size
          ),
        ),
        PosColumn(
          text: 'Amount',
          width: 4,
          styles: const PosStyles(
            bold: true,
            align: PosAlign.right,
            height: PosTextSize.size2, // INCREASED font size
          ),
        ),
      ]);

      bytes += generator.hr(ch: '-');

      // ================= ITEMS =================
      for (var item in cartItems) {
        final price = item.getPriceByOrderType(selectedOrderType);
        final total = item.getTotalPrice(selectedOrderType);
        final itemDiscount = 0.00; 

        
        bytes += generator.text(
          item.product.name.toUpperCase(),
          styles: const PosStyles(
            align: PosAlign.left,
            height: PosTextSize.size2, // INCREASED font size
          ),
        );

       
        bytes += generator.row([
          PosColumn(
            text: item.quantity.toString(),
            width: 2,
            styles: const PosStyles(
              align: PosAlign.left,
              height: PosTextSize.size2, // INCREASED font size
            ),
          ),
          PosColumn(
            text: price.toStringAsFixed(2),
            width: 3,
            styles: const PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size2, // INCREASED font size
            ),
          ),
          PosColumn(
            text: itemDiscount.toStringAsFixed(2),
            width: 3,
            styles: const PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size2, // INCREASED font size
            ),
          ),
          PosColumn(
            text: total.toStringAsFixed(2),
            width: 4,
            styles: const PosStyles(
              align: PosAlign.right,
              height: PosTextSize.size2, // INCREASED font size
            ),
          ),
        ]);
      }

      bytes += generator.hr();

      // ================= TOTALS =================
      bytes += generator.row([
        PosColumn(
          text: 'Gross Amount',
          width: 7,
          styles: const PosStyles(
            height: PosTextSize.size2, // INCREASED font size
          ),
        ),
        PosColumn(
          text: totalSubtotal.toStringAsFixed(2),
          width: 5,
          styles: const PosStyles(
            align: PosAlign.right,
            height: PosTextSize.size2, // INCREASED font size
          ),
        ),
      ]);

      if (globalDiscountValue > 0) {
        bytes += generator.row([
          PosColumn(
            text: 'Discount (${discountPercentage.toStringAsFixed(0)}%)',
            width: 7,
            styles: const PosStyles(
              height: PosTextSize.size2, // INCREASED font size
            ),
          ),
          PosColumn(
            text: '-${globalDiscountValue.toStringAsFixed(2)}',
            width: 5,
            styles: const PosStyles(
              align: PosAlign.right,
              height: PosTextSize.size2, // INCREASED font size
            ),
          ),
        ]);
      }

      if (serviceAmount > 0) {
        bytes += generator.row([
          PosColumn(
            text: 'Service Charge',
            width: 7,
            styles: const PosStyles(
              height: PosTextSize.size2, // INCREASED font size
            ),
          ),
          PosColumn(
            text: serviceAmount.toStringAsFixed(2),
            width: 5,
            styles: const PosStyles(
              align: PosAlign.right,
              height: PosTextSize.size2, // INCREASED font size
            ),
          ),
        ]);
      }

      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(
          text: 'NET AMOUNT',
          width: 7,
          styles: const PosStyles(
            bold: true,
            height: PosTextSize.size2, // INCREASED font size
          ),
        ),
        PosColumn(
          text: netAmount.toStringAsFixed(2),
          width: 5,
          styles: const PosStyles(
            bold: true,
            align: PosAlign.right,
            height: PosTextSize.size2, // INCREASED font size
          ),
        ),
      ]);

      bytes += generator.hr();

      // ================= FOOTER =================
      // Add Bill Copy notice at bottom
      if (isBillCopy) {
        bytes += generator.text(
          '*** BILL COPY - NOT ORIGINAL ***',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2, // INCREASED font size
          ),
        );
        bytes += generator.hr();
      }

      bytes += generator.text(
        'THANK YOU, COME AGAIN',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2, // INCREASED font size
        ),
      );

      bytes += generator.text(
        'Software By (e) SLT Cloud POS',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2, // INCREASED font size
        ),
      );

      bytes += generator.text(
        '0252264723 | 0702967270',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2, // INCREASED font size
        ),
      );

      bytes += generator.text(
        'www.posmasters.lk',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2, // INCREASED font size
        ),
      );
    } else {
      // Kitchen Printer (KOT)
      bytes += generator.text(
        'KITCHEN ORDER TICKET',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size3, // INCREASED from size2 to size3
          width: PosTextSize.size2, // ADDED width for larger font
        ),
      );
      
      if (isBillCopy) {
        bytes += generator.text(
          '*** BILL COPY ***',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            reverse: true,
            height: PosTextSize.size2, // INCREASED font size
          ),
        );
      }
      
      // FIXED: Always print the invoice number from system
      bytes += generator.text(
        'Invoice #${invoiceNumber ?? 'INV-${DateTime.now().millisecondsSinceEpoch}'}',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2, // INCREASED font size
        ),
      );
      
      bytes += generator.text(
        'Time: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2, // INCREASED font size
        ),
      );
  
      if (selectedTable != null) {
        bytes += generator.text(
          'Table: ${selectedTable.name}',
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2, // INCREASED font size
          ),
        );
        // ADDED: Print special note in KOT
        if (selectedTable!.specialNote.isNotEmpty) {
          bytes += generator.text(
            'Note: ${selectedTable!.specialNote}',
            styles: const PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size2, // INCREASED font size
            ),
          );
        }
      }
  
      bytes += generator.hr();
      
      // For due tables, only print new items
      final itemsToPrint = cartData['onlyNewItems'] == true 
          ? cartItems.where((item) => item.isNewItem).toList()
          : cartItems;
      
      final foodItems = itemsToPrint.where((item) =>
        item.product.unit.toLowerCase().contains('food') ||
        !item.product.unit.toLowerCase().contains('beverage')
      ).toList();
  
      if (foodItems.isEmpty) {
        bytes += generator.text(
          'No food items in this order',
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2, // INCREASED font size
          ),
        );
      } else {
        bytes += generator.text(
          'ITEMS:',
          styles: const PosStyles(
            bold: true,
            align: PosAlign.left,
            height: PosTextSize.size2, // INCREASED font size
          ),
        );
      
        for (var item in foodItems) {
          bytes += generator.text(
            '${item.quantity}x ${item.product.name}',
            styles: const PosStyles(
              align: PosAlign.left,
              height: PosTextSize.size2, // INCREASED font size
            ),
          );
      
          if (item.product.unit.toLowerCase().contains('main')) {
            bytes += generator.text(
              ' - Please prepare fresh',
              styles: const PosStyles(
                align: PosAlign.left,
                height: PosTextSize.size2, // INCREASED font size
              ),
            );
          }
        }
      }
  
      bytes += generator.hr();
      bytes += generator.text(
        'Priority: Normal',
        styles: const PosStyles(
          align: PosAlign.left,
          height: PosTextSize.size2, // INCREASED font size
        ),
      );
      bytes += generator.text(
        'Status: CONFIRMED',
        styles: const PosStyles(
          align: PosAlign.left,
          bold: true,
          height: PosTextSize.size2, // INCREASED font size
        ),
      );
      bytes += generator.feed(1);
      bytes += generator.text(
        '--- END OF KOT ---',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2, // INCREASED font size
        ),
      );
    }
  
    bytes += generator.feed(2);
    bytes += generator.cut();
    return bytes;
  }

  Future<void> _printReceipt({bool isBillCopy = false, bool skipKOT = false}) async {
    if (_connectedCashierDevices.isEmpty) {
      _showMessage('Please connect to a cashier printer first');
      return;
    }

    if (_cartItems.isEmpty && _cartDataForPrinting == null) {
      _showMessage('No items to print');
      return;
    }

    try {
      Map<String, dynamic> cartData;
      
      if (_cartDataForPrinting != null) {
        cartData = Map<String, dynamic>.from(_cartDataForPrinting!);
        cartData['isBillCopy'] = isBillCopy;
      } else {
        cartData = {
          'printerType': PrinterType.cashier,
          'cartItems': List<CartItem>.from(_cartItems),
          'selectedOrderType': _selectedOrderType,
          'selectedCustomer': _selectedCustomer,
          'selectedTable': _selectedTable,
          'totalSubtotal': _totalSubtotal,
          'totalItemDiscount': _totalItemDiscount,
          'discountPercentage': _discountPercentage,
          'globalDiscountValue': _globalDiscountValue,
          'serviceAmount': _serviceAmount,
          'netAmount': _netAmount,
          'orderNumber': _orderNumber,
          'isBillCopy': isBillCopy,
        };
      }

      final List<int> cashierBytes = await _generateReceipt({...cartData, 'printerType': PrinterType.cashier});
      final List<int> kitchenBytes = await _generateReceipt({...cartData, 'printerType': PrinterType.kitchen});
    
      // Print to cashier printers
      for (int i = 0; i < _connectedCashierDevices.length; i++) {
        try {
          _connections[i].output.add(Uint8List.fromList(cashierBytes));
          await _connections[i].output.allSent;
          print('Receipt sent to ${_connectedCashierDevices[i].name}');
          _showMessage(isBillCopy ? 'Bill copy printed to ${_connectedCashierDevices[i].name}' : 'Receipt sent to ${_connectedCashierDevices[i].name}');
        } catch (e) {
          // _showMessage('Error printing to ${_connectedCashierDevices[i].name}: $e');
        }
      }
    
      // Print to kitchen printers only if not a bill copy and not skipping KOT
      if (!isBillCopy && !skipKOT && _connectedKitchenDevices.isNotEmpty) {
        for (int i = 0; i < _connectedKitchenDevices.length; i++) {
          try {
            int connectionIndex = _connectedCashierDevices.length + i;
            _connections[connectionIndex].output.add(Uint8List.fromList(kitchenBytes));
            await _connections[connectionIndex].output.allSent;
            print('KOT sent to ${_connectedKitchenDevices[i].name}');
            // _showMessage('KOT sent to ${_connectedKitchenDevices[i].name}');
          } catch (e) {
            _showMessage('Error printing to ${_connectedKitchenDevices[i].name}: $e');
          }
        }
      }
    
      if (cartData.isNotEmpty && !isBillCopy) {
        setState(() {
          _orderNumber++;
        });
      }
    
    } catch (e) {
      _showMessage('Error generating receipt: $e');
    }
  }

  Future<void> _printKOT({bool onlyNewItems = false}) async {
    if (_connectedKitchenDevices.isEmpty) {
      _showMessage('No kitchen printer connected. Cannot print KOT.');
      return;
    }

    if (_cartItems.isEmpty) {
      _showMessage('No items to print');
      return;
    }

    try {
      final cartData = {
        'printerType': PrinterType.kitchen,
        'cartItems': List<CartItem>.from(_cartItems),
        'selectedOrderType': _selectedOrderType,
        'selectedCustomer': _selectedCustomer,
        'selectedTable': _selectedTable,
        'totalSubtotal': _totalSubtotal,
        'totalItemDiscount': _totalItemDiscount,
        'discountPercentage': _discountPercentage,
        'globalDiscountValue': _globalDiscountValue,
        'serviceAmount': _serviceAmount,
        'netAmount': _netAmount,
        'orderNumber': _orderNumber,
        'onlyNewItems': onlyNewItems, // Pass this parameter
      };
      
      final List<int> kitchenBytes = await _generateReceipt(cartData);
    
      for (int i = 0; i < _connectedKitchenDevices.length; i++) {
        try {
          int connectionIndex = _connectedCashierDevices.length + i;
          _connections[connectionIndex].output.add(Uint8List.fromList(kitchenBytes));
          await _connections[connectionIndex].output.allSent;
          _showMessage('KOT sent to ${_connectedKitchenDevices[i].name}');
        } catch (e) {
          _showMessage('Error printing to ${_connectedKitchenDevices[i].name}: $e');
        }
      }
    
      await _updateStockAfterKOT(onlyNewItems);
    
    } catch (e) {
      _showMessage('Error generating KOT: $e');
    }
  }

  Future<void> _updateStockAfterKOT(bool onlyNewItems) async {
    if (_cartItems.isEmpty) return;
    
    try {
      final headers = await _getAuthHeaders();
      
      // Filter items to update - only new items for due tables
      final itemsToUpdate = onlyNewItems
          ? _cartItems.where((item) => item.isNewItem).toList()
          : _cartItems;
      
      for (var cartItem in itemsToUpdate) {
        final product = cartItem.product;
        
        if (product.lotsqty.isNotEmpty) {
          product.lotsqty.sort((a, b) {
            int qtyA = int.tryParse(a['qty']?.toString() ?? '0') ?? 0;
            int qtyB = int.tryParse(b['qty']?.toString() ?? '0') ?? 0;
            return qtyB.compareTo(qtyA);
          });
          
          final selectedLot = product.lotsqty.first;
          final lotId = selectedLot['id'];
          final currentQty = int.tryParse(selectedLot['qty']?.toString() ?? '0') ?? 0;
          
          if (currentQty >= cartItem.quantity) {
            final newQty = currentQty - cartItem.quantity;
            
            final response = await http.post(
              Uri.parse('https://api-cloudchef.sltcloud.lk/api/lot/update-qty'),
              headers: headers,
              body: json.encode({
                'lot_id': lotId,
                'qty': newQty,
              }),
            ).timeout(const Duration(seconds: 10));
            
            if (response.statusCode == 200) {
              final productIndex = _products.indexWhere((p) => p.id == product.id);
              if (productIndex != -1) {
                _products[productIndex].availableQuantity = newQty;
                
                final filteredIndex = _filteredProducts.indexWhere((p) => p.id == product.id);
                if (filteredIndex != -1) {
                  _filteredProducts[filteredIndex].availableQuantity = newQty;
                }
              }
              
              final cartIndex = _cartItems.indexWhere((item) => item.product.id == product.id);
              if (cartIndex != -1) {
                _cartItems[cartIndex].product.availableQuantity = newQty;
              }
            }
          }
        }
      }
      
      setState(() {});
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _printDueTableBillCopy(Table table) async {
    if (_connectedCashierDevices.isEmpty) {
      _showMessage('Please connect to a cashier printer first');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // First load the table bill
      await _findTableBill(table.name);
      
      if (_cartItems.isEmpty) {
        _showMessage('No items found for table ${table.name}');
        return;
      }
      
      // Create cart data for printing
      final cartData = {
        'printerType': PrinterType.cashier,
        'cartItems': List<CartItem>.from(_cartItems),
        'selectedOrderType': _selectedOrderType,
        'selectedCustomer': _selectedCustomer,
        'selectedTable': _selectedTable,
        'totalSubtotal': _totalSubtotal,
        'totalItemDiscount': _totalItemDiscount,
        'discountPercentage': _discountPercentage,
        'globalDiscountValue': _globalDiscountValue,
        'serviceAmount': _serviceAmount,
        'netAmount': _netAmount,
        'orderNumber': _orderNumber,
        'isBillCopy': true,
        'invoiceNumber': 'COPY-${DateTime.now().millisecondsSinceEpoch}',
      };
      
      // Generate and print bill copy
      final List<int> cashierBytes = await _generateReceipt(cartData);
      
      // Print to cashier printers
      for (int i = 0; i < _connectedCashierDevices.length; i++) {
        try {
          _connections[i].output.add(Uint8List.fromList(cashierBytes));
          await _connections[i].output.allSent;
          // _showMessage('Bill copy printed for table ${table.name}');
        } catch (e) {
          _showMessage('Error printing bill copy: $e');
        }
      }
      
      // IMPORTANT: Clear the cart after printing bill copy
      _clearCart();
      
    } catch (e) {
      _showMessage('Error generating bill copy: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _printBillCopyFromInvoice(Map<String, dynamic> invoiceData) async {
    if (_connectedCashierDevices.isEmpty) {
      _showMessage('Please connect to a cashier printer first');
      return;
    }

    try {
      // Extract data from invoice response
      final invoiceHead = invoiceData['data']?['invoice_head'] ?? invoiceData['invoice_head'];
      final items = invoiceData['data']?['items'] ?? invoiceData['items'] ?? [];
      final customer = invoiceData['data']?['customer'] ?? invoiceData['customer'];
      final table = invoiceData['data']?['table'] ?? invoiceData['table'];
      
      if (items.isEmpty) {
        _showMessage('No invoice data to print');
        return;
      }
      
      // Create cart items from invoice data
      List<CartItem> cartItems = [];
      double totalSubtotal = 0.0;
      
      for (var item in items) {
            final product = Product(
          id: item['id'] ?? 0,
          name: item['name'] ?? 'Unknown',
          unit: item['unit'] ?? '',
          barCode: item['bar_code'] ?? '',
          tblStockId: item['tbl_stock_id'] ?? 0,
          tblCategoryId: item['tbl_category_id'] ?? 0,
          productImage: null,
          stockName: item['stock']?['stock_name'] ?? 'Main',
          availableQuantity: int.tryParse(item['qty']?.toString() ?? '0') ?? 0,
          price: double.tryParse(item['price']?.toString() ?? '0') ?? 0.0,
          cost: double.tryParse(item['cost']?.toString() ?? '0') ?? 0.0,
          wsPrice: double.tryParse(item['price']?.toString() ?? '0') ?? 0.0,
          lotNumber: item['lot_id']?.toString() ?? '',
          expiryDate: item['ex_date'] ?? item['expiry_date'],
          lotsqty: [],
        );
        
        final quantity = int.tryParse(item['qty']?.toString() ?? '1') ?? 1;
        final dis = double.tryParse(item['dis']?.toString() ?? '0') ?? 0.0;
        final disVal = double.tryParse(item['disVal']?.toString() ?? '0') ?? 0.0;
        
        String discountType = 'none';
        double discountValue = 0.0;
        
        if (dis > 0) {
          discountType = '%';
          discountValue = dis;
        } else if (disVal > 0) {
          discountType = 'value';
          discountValue = disVal;
        }
        
        final cartItem = CartItem(
          product: product,
          quantity: quantity,
          discountType: discountType,
          discountValue: discountValue,
        );
        
        cartItems.add(cartItem);
        totalSubtotal += cartItem.getSubtotal(_selectedOrderType);
      }
      
      // Get customer data
      Customer? selectedCustomer;
      if (customer != null) {
        selectedCustomer = Customer(
          id: customer['id'] ?? 0,
          name: customer['name'] ?? 'Walk-in Customer',
          phone: customer['phone'] ?? '',
          email: customer['email'] ?? '',
          nic: customer['nic'] ?? '',
          address: customer['address'] ?? '',
        );
      }
      
      // Get table data
      Table? selectedTable;
      if (table != null) {
        selectedTable = Table(
          id: table['id'] ?? 0,
          name: table['name'] ?? '',
          serviceCharge: double.tryParse(table['service_charge']?.toString() ?? '0') ?? 0.0,
          hasDueOrders: false,
          specialNote: table['special_note'] ?? '', // ADDED: Load special note
        );
      }
      
      // Create cart data for printing
      final cartData = {
        'printerType': PrinterType.cashier,
        'cartItems': cartItems,
        'selectedOrderType': _selectedOrderType,
        'selectedCustomer': selectedCustomer,
        'selectedTable': selectedTable,
        'totalSubtotal': totalSubtotal,
        'totalItemDiscount': 0.0,
        'discountPercentage': double.tryParse(invoiceHead['bill_dis']?.toString() ?? '0') ?? 0.0,
        'globalDiscountValue': double.tryParse(invoiceHead['bill_dis_val']?.toString() ?? '0') ?? 0.0,
        'serviceAmount': double.tryParse(invoiceHead['service_charge']?.toString() ?? '0') ?? 0.0,
        'netAmount': double.tryParse(invoiceHead['net_amount']?.toString() ?? '0') ?? 0.0,
        'orderNumber': invoiceHead['invoice_code'] ?? _orderNumber,
        'invoiceNumber': invoiceHead['invoice_code'] ?? 'COPY',
        'isBillCopy': true,
      };
      
      // Generate and print bill copy
      final List<int> cashierBytes = await _generateReceipt(cartData);
      
      // Print to cashier printers
      for (int i = 0; i < _connectedCashierDevices.length; i++) {
        try {
          _connections[i].output.add(Uint8List.fromList(cashierBytes));
          await _connections[i].output.allSent;
          // _showMessage('Bill copy printed successfully');
        } catch (e) {
          _showMessage('Error printing bill copy: $e');
        }
      }
      
      // IMPORTANT: Clear the current cart after printing
      if (_selectedTable != null && _cartItems.isNotEmpty) {
        _clearCart();
        // _showMessage('Bill copy printed and cart cleared.');
      }
      
    } catch (e) {
      _showMessage('Error generating bill copy: $e');
    }
  }

  // MODIFIED: Added printer connection check before payment
  Future<void> _payNow() async {
    if (_cartItems.isEmpty) return;

    // Check if cashier printer is connected
    if (_connectedCashierDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot process payment: Cashier printer not connected. Please connect to a cashier printer first.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Check if kitchen printer is connected for KOT (skip for due tables)
    if (!_isEditingDueTable && _connectedKitchenDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Warning: Kitchen printer not connected. KOT will not be printed.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Continue with payment even if kitchen printer is not connected
    }

    _cartDataForPrinting = {
      'cartItems': List<CartItem>.from(_cartItems),
      'selectedCustomer': _selectedCustomer,
      'selectedTable': _selectedTable,
      'totalSubtotal': _totalSubtotal,
      'totalItemDiscount': _totalItemDiscount,
      'discountPercentage': _discountPercentage,
      'globalDiscountValue': _globalDiscountValue,
      'serviceAmount': _serviceAmount,
      'netAmount': _netAmount,
      'orderNumber': _orderNumber,
      'isDueTable': _isEditingDueTable, // Add this flag
    };

    try {
      final headers = await _getAuthHeaders();
  
      String saleType = _selectedTable != null 
          ? 'DINE IN'  // When table is selected
          : 'TAKE AWAY'; 
  
      List<Map<String, dynamic>> items = [];
      for (var item in _cartItems) {
        double price = item.getPriceByOrderType(_selectedOrderType);
        double disVal = item.getDiscount(_selectedOrderType);
        double dis = item.discountType == '%' ? item.discountValue : 0.0;
        double total = item.getTotalPrice(_selectedOrderType);
        int lotId = int.tryParse(item.product.lotNumber) ?? 0;
    
        items.add({
          'aQty': item.product.availableQuantity,
          'bar_code': item.product.barCode,
          'cost': item.product.cost,
          'dis': dis,
          'disVal': disVal,
          'exp': item.product.expiryDate,
          'lot_id': lotId,
          'lot_index': 0,
          'name': item.product.name,
          'price': price,
          'qty': item.quantity,
          's_name': null,
          'sid': item.product.tblStockId,
          'stock': item.product.stockName,
          'total': total.toStringAsFixed(2),
          'total_discount': disVal.toStringAsFixed(2),
          'unit': item.product.unit,
        });
      }

      Map<String, dynamic> metadata = {
        'advance_payment': '',
        'bill_copy_issued': 0,
        'billDis': _discountPercentage.toString(),
        'billDisVal': _globalDiscountValue.toStringAsFixed(2),
        'customer': _selectedCustomer != null ? {
          'id': _selectedCustomer!.id,
          'name': _selectedCustomer!.name,
          'phone': _selectedCustomer!.phone,
          'email': _selectedCustomer!.email,
          'nic': _selectedCustomer!.nic,
          'address': _selectedCustomer!.address,
        } : {
          'id': 0, 
          'name': 'Walk-in Customer',
          'phone': '',
          'email': '',
          'nic': '',
          'address': '',
        },
        'free_issue': 0,
        'grossAmount': _totalSubtotal.toStringAsFixed(2),
        'invDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'items': _cartItems.map((item) {
          double price = item.getPriceByOrderType(_selectedOrderType);
          double disVal = item.getDiscount(_selectedOrderType);
          double dis = item.discountType == '%' ? item.discountValue : 0.0;
          double total = item.getTotalPrice(_selectedOrderType);
          
          int lotId = 0;
          if (item.product.lotsqty.isNotEmpty) {
            for (var lot in item.product.lotsqty) {
              if ((lot['qty'] ?? 0) > 0) {
                lotId = lot['id'] ?? 0;
                break;
              }
            }
          }
          
          return {
            'aQty': item.product.availableQuantity + item.quantity,
            'bar_code': item.product.barCode,
            'cost': item.product.cost,
            'dis': dis,
            'disVal': disVal,
            'exp': item.product.expiryDate,
            'lot_id': lotId,
            'lot_index': 0,
            'name': item.product.name,
            'price': price,
            'qty': item.quantity,
            's_name': null,
            'sid': item.product.tblStockId,
            'stock': item.product.stockName,
            'total': total.toStringAsFixed(2),
            'total_discount': disVal.toStringAsFixed(2),
            'unit': item.product.unit,
          };
        }).toList(),
        'netAmount': _netAmount.toStringAsFixed(2),
        'order_now_order_info_id': _currentInvoiceId,
        'room_booking': '',
        'saleType': saleType,
        'service_charge': _selectedTable != null ? _serviceAmount.toStringAsFixed(2) : '0.00',
        'services': [],
        'tbl_room_booking_id': '',
        'waiter_id': _selectedWaiter?.id ?? 0,
        'waiter_name': _selectedWaiter?.name ?? '',
      };

      if (_selectedTable != null && _selectedTable!.id != null) {
        metadata['table_name_id'] = {
          'id': _selectedTable!.id,
          'name': _selectedTable!.name,
          'service_charge': _selectedTable!.serviceCharge,
          'special_note': _selectedTable!.specialNote, // ADDED: Include special note
        };
      }

      final payload = {
        'advancePaymentApplied': 0,
        'bank': {
          'amount': "",
          'code': "",
        },
        'card': {
          'card_no': "",
          'cardAmount': "",
          'cardBank': {},
          'cardType': "",
        },
       'cash': _netAmount.toStringAsFixed(2),
        'cheque': {
          'amount': "",
          'bank': "",
          'chequeDate': "",
          'chequeNo': "",
        },
        'credit': "",
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'metadata': metadata,
        'overBal': "",
        'type': 2,
      };

      print('PayNow Payload: ${json.encode(payload)}');
      final response = await http.post(
        Uri.parse('https://api-cloudchef.sltcloud.lk/api/payment'),
        headers: headers,
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        
        String? invoiceNumber;
        if (responseData['data'] != null && responseData['data']['invoice_head'] != null) {
          invoiceNumber = responseData['data']['invoice_head']['invoice_code'];
        }
        
        // FIXED: Update cartDataForPrinting with actual invoice number
        if (_cartDataForPrinting != null) {
          _cartDataForPrinting!['invoiceNumber'] = invoiceNumber;
        }
        
        // Print receipt (cashier printer already checked)
        // Skip KOT for due tables
        await _printReceipt(skipKOT: _isEditingDueTable);
        
        _clearCart();
        _cartDataForPrinting = null;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment processed successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        setState(() {
          _orderNumber++;
        });
      } else {
        throw Exception('Failed to process payment: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing payment: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  
      _cartDataForPrinting = null;
    }
  }
  void _showPrinterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Bluetooth Printers'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_connectedCashierDevices.isNotEmpty) ...[
                      const Text('Cashier Printers:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ..._connectedCashierDevices.map((device) => ListTile(
                        title: Text(device.name ?? 'Unknown Device'),
                        subtitle: Text(device.address),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _disconnectDevice(device),
                        ),
                      )).toList(),
                    ],
                  
                    if (_connectedKitchenDevices.isNotEmpty) ...[
                      const Text('Kitchen Printers:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ..._connectedKitchenDevices.map((device) => ListTile(
                        title: Text(device.name ?? 'Unknown Device'),
                        subtitle: Text(device.address),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _disconnectDevice(device),
                        ),
                      )).toList(),
                      const Divider(),
                    ],
                  
                    if (_isScanning)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      )
                    else if (_devices.isEmpty)
                      const Text('No devices found. Tap scan to search for printers.')
                    else
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          itemCount: _devices.length,
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            final isCashierConnected = _connectedCashierDevices.any((d) => d.address == device.address);
                            final isKitchenConnected = _connectedKitchenDevices.any((d) => d.address == device.address);
                            final isConnected = isCashierConnected || isKitchenConnected;
                          
                            return ListTile(
                              title: Text(device.name ?? 'Unknown Device'),
                              subtitle: Text(device.address),
                              trailing: isConnected
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (String value) {
                                      _connectToDevice(device, value);
                                    },
                                    itemBuilder: (BuildContext context) => [
                                      const PopupMenuItem<String>(
                                        value: PrinterType.cashier,
                                        child: Text('Connect as Cashier Printer'),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: PrinterType.kitchen,
                                        child: Text('Connect as Kitchen Printer'),
                                      ),
                                    ],
                                  ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: _scanDevices,
                          child: const Text('Scan'),
                        ),
                        if (_connectedCashierDevices.isNotEmpty || _connectedKitchenDevices.isNotEmpty)
                          ElevatedButton(
                            onPressed: _disconnectAllDevices,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Disconnect All'),
                          ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  // MODIFIED: Added printer connection check before payment
  Future<void> _showPaymentScreen() async {
    if (_cartItems.isEmpty) {
      _showMessage('Cart is empty. Add items before payment.');
      return;
    }
    
    if (_selectedTable != null && _selectedTable!.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selected table has no valid ID. Please select a different table.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // Check if cashier printer is connected
    if (_connectedCashierDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot proceed to payment: Cashier printer not connected. Please connect to a cashier printer first.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // Check if kitchen printer is connected for KOT (skip for due tables)
    if (!_isEditingDueTable && _connectedKitchenDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Warning: Kitchen printer not connected. KOT will not be printed.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Continue with payment even if kitchen printer is not connected
    }
    
    // Set the flag if we're processing a due table
    setState(() {
      _isProcessingDueTablePayment = _isEditingDueTable;
    });
    
    _cartDataForPrinting = {
      'cartItems': List<CartItem>.from(_cartItems), 
      'selectedOrderType': _selectedOrderType,
      'selectedCustomer': _selectedCustomer,
      'selectedTable': _selectedTable,
      'totalSubtotal': _totalSubtotal,
      'totalItemDiscount': _totalItemDiscount,
      'discountPercentage': _discountPercentage,
      'globalDiscountValue': _globalDiscountValue,
      'serviceAmount': _serviceAmount,
      'netAmount': _netAmount,
      'orderNumber': _orderNumber,
      'isDueTable': _isEditingDueTable, // Add this flag
    };
  
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          cartItems: List<CartItem>.from(_cartItems), 
          selectedCustomer: _selectedCustomer,
          currentInvoiceId: _currentInvoiceId,
          selectedTable: _selectedTable,
          selectedWaiter: _selectedWaiter,
          selectedOrderType: _selectedOrderType,
          netAmount: _netAmount,
          discountPercentage: _discountPercentage,
          globalDiscountValue: _globalDiscountValue,
          serviceAmount: _serviceAmount,
          totalSubtotal: _totalSubtotal,
          isDueTable: _isEditingDueTable, // Pass this flag
        ),
      ),
    );
    
    if (result != null && result['success'] == true) {
      try {
        // FIXED: Get invoice number from payment response
        String? invoiceNumber = result['invoiceNumber'];
        
        // Update cartDataForPrinting with actual invoice number
        if (_cartDataForPrinting != null && invoiceNumber != null) {
          _cartDataForPrinting!['invoiceNumber'] = invoiceNumber;
        }
        
        // Print receipt (cashier printer already checked)
        // Skip KOT for due tables
        await _printReceipt(skipKOT: _isEditingDueTable);
        
        _clearCart();
        await _refreshDueTables();
        _cartDataForPrinting = null;
        
      } catch (e) {
        _showMessage('Payment successful but printing failed: $e');
        
        _clearCart();
        _cartDataForPrinting = null;
      } finally {
        setState(() {
          _isProcessingDueTablePayment = false;
        });
      }
    } else {
      setState(() {
        _isProcessingDueTablePayment = false;
      });
    }
  }

  Future<void> _refreshDueTables() async {
    try {
      if (_selectedTable != null) {
        setState(() {
          _tables = _tables.map((table) {
            if (table.id == _selectedTable!.id) {
              return Table(
                id: table.id!,
                name: table.name,
                serviceCharge: table.serviceCharge,
                hasDueOrders: false, 
                specialNote: '', // Clear special note after payment
              );
            }
            return table;
          }).toList();
          
          _filteredTables = _tables;
        });
        
        _selectedTable = null;
      }
      
      _showMessage('Table paid successfully and removed from due tables');
      
    } catch (e) {
      print('Error refreshing due tables: $e');
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'referer': REFERER_HEADER,
    };
  }

  Future<void> _loadCategories() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('https://api-cloudchef.sltcloud.lk/api/stock/create-data/category/get'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> categoriesData = data is List ? data : (data['data'] ?? []);
      
        List<Category> categories = categoriesData.map((e) => Category.fromJson(e)).toList();
      
        setState(() {
          _categories = [Category(id: 0, categoryName: 'All')] + categories;
          _selectedCategory = _categories.first;
        });
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load categories: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('https://api-cloudchef.sltcloud.lk/api/invoice-create/stock-master-data?type=All'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> productsData = data is List
            ? data
            : (data['data'] ?? data['products'] ?? data['items'] ?? data.values.firstWhere((v) => v is List, orElse: () => []));
      
        _products = productsData.map((e) => Product.fromJson(e)).toList();
        _filteredProducts = _products;
        await _loadCustomers();
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load products: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _loadTables() async {
    setState(() => _isLoading = true);
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('https://api-cloudchef.sltcloud.lk/api/table-name'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> tablesData;
        if (data is List) {
          tablesData = data;
        } else if (data is Map<String, dynamic>) {
          if (data.containsKey('data')) {
            tablesData = data['data'] is List ? data['data'] : [data['data']];
          } else {
            tablesData = [data];
          }
        } else {
          tablesData = [];
        }
    
        _tables = tablesData.map((e) {
          final table = Table.fromJson(e);
          
          if (table.id == null) {
            print('Warning: Table ${table.name} has null ID');
          }
          return table;
        }).toList();
        _filteredTables = _tables;
        
        print('Loaded ${_tables.length} tables');
        for (var table in _tables) {
          print('Table: ${table.name}, ID: ${table.id}');
        }
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
      } else {
        throw Exception('Failed to load tables: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load tables: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  // MODIFIED: Load due tables with special notes from local storage
  Future<List<Table>> _loadDueTablesFromAPI() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('https://api-cloudchef.sltcloud.lk/api/invoice-create/get-due-tables'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'Success' && data['data'] != null) {
          List<dynamic> tablesData = data['data'];
          List<Table> dueTables = [];
          
          for (var tableData in tablesData) {
            Table table = Table.fromJson(tableData);
            
            // Check if we have a local special note for this table
            if (_tableSpecialNotes.containsKey(table.id)) {
              table = Table(
                id: table.id,
                name: table.name,
                serviceCharge: table.serviceCharge,
                hasDueOrders: table.hasDueOrders,
                specialNote: _tableSpecialNotes[table.id]!,
              );
            }
            
            dueTables.add(table);
          }
          
          return dueTables;
        }
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
      }
      return [];
    } catch (e) {
      _showMessage('Error loading due tables: $e');
      return [];
    }
  }

  // MODIFIED: Fixed to properly load due table items without calling KOT
  Future<void> _loadDueTableItems(Table table) async {
    setState(() => _isLoading = true);
    
    try {
      // Clear existing cart items first
      _clearCart();
      
      // Load the due table items directly
      final headers = await _getAuthHeaders();
      
      final response = await http.get(
        Uri.parse('https://api-cloudchef.sltcloud.lk/api/invoice-create/get-due-table-items/${table.id}'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'Success' && data['data'] != null) {
          final itemsData = data['data'];
          
          // First, load the basic table info using _findTableBill
          await _findTableBill(table.name);
          
          // Now populate cart items from the due table items
          if (_currentInvoiceId != null) {
            int loadedItems = 0;
            for (var itemData in itemsData) {
              try {
                var productId = itemData['product_id'] ?? itemData['tbl_product_id'];
                final barCode = itemData['bar_code'];
                final productName = itemData['name'] ?? 'Unknown Product';
                
                  Product product = _products.firstWhere(
                  (p) => p.id == productId || p.barCode == barCode,
                  orElse: () => Product(
                    id: productId ?? 0,
                    name: productName,
                    unit: itemData['unit'] ?? '',
                    barCode: barCode ?? '',
                    tblStockId: itemData['tbl_stock_id'] ?? 0,
                    tblCategoryId: itemData['tbl_category_id'] ?? 0,
                    productImage: null,
                    stockName: itemData['stock']?['stock_name'] ?? itemData['stock_name'] ?? 'Main',
                    availableQuantity: int.tryParse(itemData['qty']?.toString() ?? '0') ?? 0,
                    price: double.tryParse(itemData['price']?.toString() ?? '0') ?? 0.0,
                    cost: double.tryParse(itemData['cost']?.toString() ?? '0') ?? 0.0,
                    wsPrice: double.tryParse(itemData['ws_price']?.toString() ?? itemData['price']?.toString() ?? '0') ?? 0.0,
                    lotNumber: itemData['lot_id']?.toString() ?? itemData['lot_number'] ?? '',
                    expiryDate: itemData['ex_date'] ?? itemData['expiry_date'],
                    lotsqty: [],
                  ),
                );

                final quantity = int.tryParse(itemData['qty']?.toString() ?? '1') ?? 1;
                String discountType = itemData['discount_type'] ?? 'none';
                double discountValue = double.tryParse(itemData['discount_value']?.toString() ?? '0') ?? 0.0;

                // Check if item already exists in cart (from _findTableBill)
                bool itemExists = _cartItems.any((item) => item.product.id == product.id);
                
                if (!itemExists) {
                  _cartItems.add(CartItem(
                    product: product,
                    quantity: quantity,
                    discountType: discountType,
                    discountValue: discountValue,
                    isNewItem: false, // These are existing items
                  ));
                  loadedItems++;
                }
              } catch (e) {
                print('Error loading due table item: $e');
              }
            }
            
            _updateCartTotals();
            
            _showMessage('Loaded $loadedItems items from due table ${table.name}');
          }
        }
      } else {
        // If specific endpoint fails, try the general table bill find
        await _findTableBill(table.name);
      }
    } catch (e) {
      _showMessage('Error loading due table items: $e');
      // Fall back to general table bill find
      await _findTableBill(table.name);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWaiters() async {
    setState(() => _isLoading = true);
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('https://api-cloudchef.sltcloud.lk/api/waiters'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> waitersData = data is List ? data : (data['data'] ?? []);
      
        _waiters = waitersData.map((e) => Waiter.fromJson(e)).toList();
        _filteredWaiters = _waiters;
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
      } else {
        throw Exception('Failed to load waiters: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load waiters: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUnauthorized() async {
    await AuthService.logout();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please login again.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _filterProductsByCategory(Category category) {
    setState(() {
      _selectedCategory = category;
      if (category.id == 0) {
        _filteredProducts = _products;
      } else {
        _filteredProducts = _products.where((p) => p.tblCategoryId == category.id).toList();
      }
    });
  }

  void _searchProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        if (_selectedCategory?.id == 0) {
          _filteredProducts = _products;
        } else {
          _filteredProducts = _products.where((p) => p.tblCategoryId == _selectedCategory?.id).toList();
        }
      } else {
        _filteredProducts = _products.where((product) =>
          (product.name.toLowerCase().contains(query.toLowerCase()) ||
          product.barCode.contains(query)) &&
          (_selectedCategory?.id == 0 || product.tblCategoryId == _selectedCategory?.id)
        ).toList();
      }
    });
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('https://api-cloudchef.sltcloud.lk/api/customers'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> customersData = data is List
            ? data
            : (data['data'] ?? data['customers'] ?? data.values.firstWhere((v) => v is List, orElse: () => []));
      
        _customers = customersData.map((e) => Customer.fromJson(e)).toList();
        _filteredCustomers = _customers;
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
      }
    } catch (e) {
      // Silent fail
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addCustomer(Customer customer) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('https://api-cloudchef.sltcloud.lk/api/customers'),
        headers: headers,
        body: json.encode(customer.toJson()),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _loadCustomers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Customer added successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
      } else {
        throw Exception('Failed to add customer: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding customer: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // MODIFIED: Save invoice with special note dialog before printing KOT
  Future<void> _saveInvoice({bool isDue = false}) async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No items in cart to save'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // Check if we're editing a due table
    if (_isEditingDueTable && _currentInvoiceId != null) {
      // Use the UPDATE endpoint for due tables
      await _updateDueTableInvoice();
      return;
    }
    
    // For regular saves, check kitchen printer connection
    if (_connectedKitchenDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Warning: Kitchen printer not connected. KOT will not be printed.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Continue with save even if kitchen printer is not connected
    }
    
    // Store the current table BEFORE showing any dialog
    final Table? currentTable = _selectedTable;
    final List<CartItem> cartItemsToSave = List<CartItem>.from(_cartItems);
    
    // Show special note dialog
    final specialNote = await _showSaveInvoiceNoteDialog();
    if (specialNote == null) {
      // User cancelled
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final headers = await _getAuthHeaders();
    
      String saleType = _selectedTable != null 
          ? 'DINE IN'  
          : 'TAKE AWAY'; 
    
      // Build items array
      List<Map<String, dynamic>> items = [];
    
      for (var item in cartItemsToSave) {
        double price = item.getPriceByOrderType(_selectedOrderType);
        double disVal = item.getDiscount(_selectedOrderType);
        double dis = item.discountType == '%' ? item.discountValue : 0.0;
        double total = item.getTotalPrice(_selectedOrderType);
        
        int lotId = 0;
        if (item.product.lotsqty.isNotEmpty) {
          for (var lot in item.product.lotsqty) {
            if ((lot['qty'] ?? 0) > 0) {
              lotId = lot['id'] ?? 0;
              break;
            }
          }
        }
        
        items.add({
          'aQty': item.product.availableQuantity + item.quantity,
          'bar_code': item.product.barCode,
          'cost': item.product.cost,
          'dis': dis,
          'disVal': disVal,
          'exp': item.product.expiryDate,
          'lot_id': lotId,
          'lot_index': 0,
          'name': item.product.name,
          'price': price,
          'qty': item.quantity,
          's_name': null,
          'sid': item.product.tblStockId,
          'stock': item.product.stockName,
          'total': total.toStringAsFixed(2),
          'total_discount': disVal.toStringAsFixed(2),
          'unit': item.product.unit,
        });
      }

      Map<String, dynamic> metadata = {
        'advance_payment': '',
        'bill_copy_issued': 0,
        'billDis': _discountPercentage.toString(),
        'billDisVal': _globalDiscountValue.toStringAsFixed(2),
        'customer': _selectedCustomer != null ? {
          'id': _selectedCustomer!.id,
          'name': _selectedCustomer!.name,
          'phone': _selectedCustomer!.phone,
          'email': _selectedCustomer!.email,
          'nic': _selectedCustomer!.nic,
          'address': _selectedCustomer!.address,
        } : {
          'id': 0,
          'name': 'Walk-in Customer',
          'phone': '',
          'email': '',
          'nic': '',
          'address': '',
        },
       'free_issue': 0,
      'grossAmount': _totalSubtotal.toStringAsFixed(2),
      'invDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'items': items,
      'netAmount': _netAmount.toStringAsFixed(2),
      'order_now_order_info_id': _currentInvoiceId,
      'room_booking': '',
      'saleType': saleType,
      'service_charge': _selectedTable != null ? _serviceAmount.toStringAsFixed(2) : '0.00',
      'services': [],
      'tbl_room_booking_id': '',
      'waiter_id': _selectedWaiter?.id ?? 0,
      'waiter_name': _selectedWaiter?.name ?? '',
      };

      if (currentTable != null && currentTable.id != null) {
        metadata['table_name_id'] = {
          'id': currentTable.id,
          'name': currentTable.name,
          'service_charge': currentTable.serviceCharge,
          'special_note': specialNote, // Use the special note from dialog
        };
      }

      final payload = {
        'metadata': metadata,
        'type': 2,
      };

      print('Save Invoice Payload: ${json.encode(payload)}');

      String endpoint = isDue 
          ? 'https://api-cloudchef.sltcloud.lk/api/invoice-create/dine-in-store?bill_copy=0&due=1'
          : 'https://api-cloudchef.sltcloud.lk/api/invoice-create/dine-in-store?bill_copy=0';

      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        
        String? invoiceNumber;
        if (responseData['data'] != null && responseData['data']['invoice_head'] != null) {
          invoiceNumber = responseData['data']['invoice_head']['invoice_code'];
        } else if (responseData['invoice_code'] != null) {
          invoiceNumber = responseData['invoice_code'];
        } else if (responseData['invoice_number'] != null) {
          invoiceNumber = responseData['invoice_number'];
        }
        
        // Print KOT for ALL items if kitchen printer is connected
        if (_connectedKitchenDevices.isNotEmpty) {
          await _printKOT(onlyNewItems: _isEditingDueTable);
        }
        
        _cartDataForPrinting = {
          'cartItems': List<CartItem>.from(cartItemsToSave),
          'selectedOrderType': _selectedOrderType,
          'selectedCustomer': _selectedCustomer,
          'selectedTable': currentTable,
          'totalSubtotal': _totalSubtotal,
          'totalItemDiscount': _totalItemDiscount,
          'discountPercentage': _discountPercentage,
          'globalDiscountValue': _globalDiscountValue,
          'serviceAmount': _serviceAmount,
          'netAmount': _netAmount,
          'orderNumber': _orderNumber,
          'invoiceNumber': invoiceNumber ?? 'INV-${DateTime.now().millisecondsSinceEpoch}',
        };
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDue ? 'Due invoice saved successfully' : 'Invoice saved successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
        
        // ✅ FIXED: Clear ONLY cart items, keep table with special note
        setState(() {
          // Return stock quantities
          for (var cartItem in _cartItems) {
            final product = cartItem.product;
            final productIndex = _products.indexWhere((p) => p.id == product.id);
            if (productIndex != -1) {
              _products[productIndex].availableQuantity += cartItem.quantity;
              final filteredIndex = _filteredProducts.indexWhere((p) => p.id == product.id);
              if (filteredIndex != -1) {
                _filteredProducts[filteredIndex].availableQuantity += cartItem.quantity;
              }
            }
          }
          
          // Clear cart items ONLY
          _cartItems.clear();
          _discountController.text = '0';
          _currentInvoiceId = null;
          _serviceAmountOverride = 0.0;
          _isEditingDueTable = false;
          _existingDueTableItems.clear();
          _isProcessingDueTablePayment = false;
          
          // ✅ IMPORTANT: Keep the table selection with special note
          if (currentTable != null) {
            _selectedTable = Table(
              id: currentTable.id,
              name: currentTable.name,
              serviceCharge: currentTable.serviceCharge,
              hasDueOrders: false, // Set to false after saving
              specialNote: specialNote, // Keep the special note
            );
            
            // Save the special note locally
            _saveLocalTableNote(currentTable.id, specialNote);
          }
        });
        
      } else {
        print('Save Invoice Error: ${response.statusCode} - ${response.body}');
        final errorData = json.decode(response.body);
        if (errorData['errors'] != null) {
          final errors = errorData['errors'];
          String errorMessage = 'Validation errors:\n';
          errors.forEach((key, value) {
            errorMessage += '$key: ${value.join(', ')}\n';
          });
          throw Exception(errorMessage);
        } else {
          throw Exception('Failed to save invoice: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      print('Save Invoice Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving invoice: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // NEW METHOD: Update due table invoice with special note dialog
  Future<void> _updateDueTableInvoice() async {
  if (_cartItems.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No items in cart to save'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  // Show special note dialog
  final specialNote = await _showSaveInvoiceNoteDialog();
  if (specialNote == null) {
    // User cancelled
    return;
  }
  
  // Store the current table before clearing
  final Table? currentTable = _selectedTable;
  
  setState(() => _isLoading = true);
  
  try {
    final headers = await _getAuthHeaders();
    
    String saleType = 'DINE IN'; // Due tables are always DINE IN
    
    // Build items array - combine existing items with new items
    List<Map<String, dynamic>> items = [];
    
    // Add existing items from due table
    if (_existingDueTableItems.isNotEmpty) {
      for (var existingItem in _existingDueTableItems) {
        items.add({
          'id': existingItem['id'], // Include the existing item ID
          'invoice_head_id': _currentInvoiceId,
          'lot_id': existingItem['lot_id'] ?? 0,
          'bar_code': existingItem['bar_code'] ?? '',
          'name': existingItem['name'] ?? '',
          's_name': existingItem['s_name'] ?? null,
          'unit': existingItem['unit'] ?? '',
          'ex_date': existingItem['ex_date'],
          'qty': existingItem['qty'] ?? 1,
          'cost': existingItem['cost'] ?? 0.0,
          'price': existingItem['price'] ?? 0.0,
          'dis': existingItem['dis'] ?? 0.0,
          'disVal': existingItem['disVal'] ?? 0.0,
          'total_discount': existingItem['total_discount'] ?? 0.0,
          'total': existingItem['total'] ?? 0.0,
          'profit': existingItem['profit'] ?? 0.0,
        });
      }
    }
    
    // Add new items from cart (only new items, not existing ones)
    for (var item in _cartItems) {
      // Check if this item already exists in existing items
      bool isExistingItem = false;
      if (_existingDueTableItems.isNotEmpty) {
        for (var existingItem in _existingDueTableItems) {
          if (existingItem['bar_code'] == item.product.barCode || 
              existingItem['name'] == item.product.name) {
            isExistingItem = true;
            break;
          }
        }
      }
      
      // Only add if it's a new item
      if (!isExistingItem) {
        double price = item.getPriceByOrderType(_selectedOrderType);
        double disVal = item.getDiscount(_selectedOrderType);
        double dis = item.discountType == '%' ? item.discountValue : 0.0;
        double total = item.getTotalPrice(_selectedOrderType);
        
        int lotId = 0;
        if (item.product.lotsqty.isNotEmpty) {
          for (var lot in item.product.lotsqty) {
            if ((lot['qty'] ?? 0) > 0) {
              lotId = lot['id'] ?? 0;
              break;
            }
          }
        }
        
        items.add({
          'aQty': item.product.availableQuantity + item.quantity,
          'bar_code': item.product.barCode,
          'cost': item.product.cost,
          'dis': dis,
          'disVal': disVal,
          'exp': item.product.expiryDate,
          'lot_id': lotId,
          'lot_index': 0,
          'name': item.product.name,
          'price': price,
          'qty': item.quantity,
          's_name': null,
          'sid': item.product.tblStockId,
          'stock': item.product.stockName,
          'total': total.toStringAsFixed(2),
          'total_discount': disVal.toStringAsFixed(2),
          'unit': item.product.unit,
        });
      }
    }

    Map<String, dynamic> metadata = {
      'id': _currentInvoiceId, // THIS IS CRITICAL - include the existing invoice ID
      'advance_payment': '',
      'bill_copy_issued': 0,
      'billDis': _discountPercentage.toString(),
      'billDisVal': _globalDiscountValue.toStringAsFixed(2),
      'customer': _selectedCustomer != null ? {
        'id': _selectedCustomer!.id,
        'name': _selectedCustomer!.name,
        'phone': _selectedCustomer!.phone,
        'email': _selectedCustomer!.email,
        'nic': _selectedCustomer!.nic,
        'address': _selectedCustomer!.address,
      } : {
        'id': 0,
        'name': 'Walk-in Customer',
        'phone': '',
        'email': '',
        'nic': '',
        'address': '',
      },
      'free_issue': 0,
      'grossAmount': _totalSubtotal.toStringAsFixed(2),
      'invDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'items': items,
      'netAmount': _netAmount.toStringAsFixed(2),
      'order_now_order_info_id': _currentInvoiceId, // Include this for updates
      'room_booking': '',
      'saleType': saleType,
      'service_charge': _selectedTable != null ? _serviceAmount.toStringAsFixed(2) : '0.00',
      'services': [],
      'tbl_room_booking_id': '',
      'waiter_id': _selectedWaiter?.id ?? 0,
      'waiter_name': _selectedWaiter?.name ?? '',
    };

    if (_selectedTable != null && _selectedTable!.id != null) {
      metadata['table_name_id'] = {
        'id': _selectedTable!.id,
        'name': _selectedTable!.name,
        'service_charge': _selectedTable!.serviceCharge,
        'special_note': specialNote, // ADDED: Include special note
      };
    }

    final payload = {
      'metadata': metadata,
      'type': 2,
    };

    print('Update Due Table Payload: ${json.encode(payload)}');

    // Use the update endpoint for due tables
    final response = await http.post(
      Uri.parse('https://api-cloudchef.sltcloud.lk/api/invoice-create/dine-in-store?bill_copy=0'),
      headers: headers,
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = json.decode(response.body);
      
      String? invoiceNumber;
      if (responseData['data'] != null && responseData['data']['invoice_head'] != null) {
        invoiceNumber = responseData['data']['invoice_head']['invoice_code'];
      }
      
      // ✅ FIXED: Print KOT only for NEW items if kitchen printer is connected
      if (_connectedKitchenDevices.isNotEmpty) {
        await _printKOT(onlyNewItems: true);
      }
      
      _cartDataForPrinting = {
        'cartItems': List<CartItem>.from(_cartItems.where((item) => item.isNewItem).toList()),
        'selectedOrderType': _selectedOrderType,
        'selectedCustomer': _selectedCustomer,
        'selectedTable': _selectedTable,
        'totalSubtotal': _totalSubtotal,
        'totalItemDiscount': _totalItemDiscount,
        'discountPercentage': _discountPercentage,
        'globalDiscountValue': _globalDiscountValue,
        'serviceAmount': _serviceAmount,
        'netAmount': _netAmount,
        'orderNumber': _orderNumber,
        'invoiceNumber': invoiceNumber ?? 'INV-${DateTime.now().millisecondsSinceEpoch}',
      };
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Due table updated successfully'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
      
      // ✅ FIXED: Clear only new items from cart, keep the table selected with special note
      setState(() {
        // Return stock quantities for new items only
        final itemsToClear = _cartItems.where((item) => item.isNewItem).toList();
        
        for (var cartItem in itemsToClear) {
          final product = cartItem.product;
          final productIndex = _products.indexWhere((p) => p.id == product.id);
          if (productIndex != -1) {
            _products[productIndex].availableQuantity += cartItem.quantity;
            final filteredIndex = _filteredProducts.indexWhere((p) => p.id == product.id);
            if (filteredIndex != -1) {
              _filteredProducts[filteredIndex].availableQuantity += cartItem.quantity;
            }
          }
        }
        
        // Clear only new cart items (keep existing items in cart if any)
        _cartItems.removeWhere((item) => item.isNewItem);
        
        // Reset discount and service charge for new items
        _discountController.text = '0';
        _serviceAmountOverride = 0.0;
        _isProcessingDueTablePayment = false;
        
        // Keep the existing items in memory for future updates
        _updateCartTotals(); // Recalculate totals
        
        // Keep the table selection with updated special note
        if (currentTable != null) {
          _selectedTable = Table(
            id: currentTable.id,
            name: currentTable.name,
            serviceCharge: currentTable.serviceCharge,
            hasDueOrders: true, // Still a due table since we're updating
            specialNote: specialNote, // Keep the updated special note
          );
          
          // Save the special note locally
          _saveLocalTableNote(currentTable.id, specialNote);
        }
      });
      
    } else {
      print('Update Due Table Error: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to update due table: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print('Update Due Table Exception: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error updating due table: $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  // MODIFIED: Added printer connection check before printing bill copy
  Future<void> _printBillCopy() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No items in cart to print bill copy'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    if (_connectedCashierDevices.isEmpty) {
      _showMessage('Please connect to a cashier printer first');
      return;
    }
    
    try {
      // Simply print the bill copy without saving to database
      await _printReceipt(isBillCopy: true);
      
      // Clear cart after printing
      _clearCart();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Bill copy printed successfully. Cart cleared.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing bill copy: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // MODIFIED: Added printer connection check before saving and printing bill copy
  Future<void> _saveAndPrintBillCopy() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No items in cart to save'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // Check if cashier printer is connected
    if (_connectedCashierDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot save bill copy: Cashier printer not connected. Please connect to a cashier printer first.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    try {
      final headers = await _getAuthHeaders();
      
      String saleType = _selectedTable != null 
          ? 'DINE IN'  
          : 'TAKE AWAY'; 
      
      List<Map<String, dynamic>> items = [];
      for (var item in _cartItems) {
        double price = item.getPriceByOrderType(_selectedOrderType);
        double disVal = item.getDiscount(_selectedOrderType);
        double dis = item.discountType == '%' ? item.discountValue : 0.0;
        double total = item.getTotalPrice(_selectedOrderType);
        
        int lotId = 0;
        if (item.product.lotsqty.isNotEmpty) {
          for (var lot in item.product.lotsqty) {
            if ((lot['qty'] ?? 0) > 0) {
              lotId = lot['id'] ?? 0;
              break;
            }
          }
        }
        
        items.add({
          'aQty': item.product.availableQuantity + item.quantity,
          'bar_code': item.product.barCode,
          'cost': item.product.cost,
          'dis': dis,
          'disVal': disVal,
          'exp': item.product.expiryDate,
          'lot_id': lotId,
          'lot_index': 0,
          'name': item.product.name,
          'price': price,
          'qty': item.quantity,
          's_name': null,
          'sid': item.product.tblStockId,
          'stock': item.product.stockName,
          'total': total.toStringAsFixed(2),
          'total_discount': disVal.toStringAsFixed(2),
          'unit': item.product.unit,
        });
      }

      Map<String, dynamic> metadata = {
        'advance_payment': '',
        'bill_copy_issued': 1, // Set to 1 for bill copy
        'billDis': _discountPercentage.toString(),
        'billDisVal': _globalDiscountValue.toStringAsFixed(2),
        'customer': _selectedCustomer != null ? {
          'id': _selectedCustomer!.id,
          'name': _selectedCustomer!.name,
          'phone': _selectedCustomer!.phone,
          'email': _selectedCustomer!.email,
          'nic': _selectedCustomer!.nic,
          'address': _selectedCustomer!.address,
        } : {
          'id': 0,
          'name': 'Walk-in Customer',
          'phone': '',
          'email': '',
          'nic': '',
          'address': '',
        },
        'free_issue': 0,
        'grossAmount': _totalSubtotal.toStringAsFixed(2),
        'invDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'items': items,
        'netAmount': _netAmount.toStringAsFixed(2),
        'order_now_order_info_id': _currentInvoiceId,
        'room_booking': '',
        'saleType': saleType,
        'service_charge': _selectedTable != null ? _serviceAmount.toStringAsFixed(2) : '0.00',
        'services': [],
        'tbl_room_booking_id': '',
        'waiter_id': _selectedWaiter?.id ?? 0,
        'waiter_name': _selectedWaiter?.name ?? '',
      };

      if (_selectedTable != null && _selectedTable!.id != null) {
        metadata['table_name_id'] = {
          'id': _selectedTable!.id,
          'name': _selectedTable!.name,
          'service_charge': _selectedTable!.serviceCharge,
          'special_note': _selectedTable!.specialNote, // ADDED: Include special note
        };
      }

      final payload = {
        'metadata': metadata,
        'type': 2,
      };

      print('Save Bill Copy Payload: ${json.encode(payload)}');

      // Call API with bill_copy=1 parameter
      final response = await http.post(
        Uri.parse('https://api-cloudchef.sltcloud.lk/api/invoice-create/dine-in-store?bill_copy=1'),
        headers: headers,
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        
        // Print the bill copy
        await _printBillCopyFromInvoice(responseData);
        
        // IMPORTANT: Clear the cart after saving and printing bill copy
        _clearCart();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bill copy saved, printed, and cart cleared'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
        
      } else {
        throw Exception('Failed to save bill copy: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Save Bill Copy Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving bill copy: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddProductDialog(Product product) {
    final existingIndex = _cartItems.indexWhere((item) => item.product.id == product.id);
    final bool isExisting = existingIndex >= 0;
    
    if (isExisting) {
      _addProductToCart(
        product,
        _cartItems[existingIndex].quantity + 1,
        _cartItems[existingIndex].discountType,
        _cartItems[existingIndex].discountValue,
        existingIndex,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} quantity increased to ${_cartItems[existingIndex].quantity}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      _addProductToCart(
        product,
        1,  // Default quantity = 1
        'none',  // No discount by default
        0.0,  // No discount value
        null,  // Not an existing item
      );
    }
  }

  Widget _buildDiscountTypeChip(String value, String label, String selectedValue, void Function(void Function()) setState) {
    final isSelected = selectedValue == value;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.poppins()),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            // Handle selection
          }
        });
      },
      selectedColor: Colors.blue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
      ),
    );
  }

  void _addProductToCart(Product product, int quantity, String discountType, double discountValue, int? existingIndex) {
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid quantity')),
      );
      return;
    }
  
    if (quantity > product.availableQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only ${product.availableQuantity} available')),
      );
      return;
    }
  
    if (discountType == '%' && discountValue > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Percentage cannot exceed 100')),
      );
      return;
    }
  
    if (existingIndex != null) {
      setState(() {
        _cartItems[existingIndex].quantity = quantity;
        _cartItems[existingIndex].discountType = discountType;
        _cartItems[existingIndex].discountValue = discountValue;
        
        final productIndex = _products.indexWhere((p) => p.id == product.id);
        if (productIndex != -1) {
          final originalQty = _products[productIndex].availableQuantity;
          final cartItem = _cartItems[existingIndex];
          final previousQty = cartItem.quantity;
          final newQty = originalQty + previousQty - quantity;
          if (newQty >= 0) {
            _products[productIndex].availableQuantity = newQty;
            final filteredIndex = _filteredProducts.indexWhere((p) => p.id == product.id);
            if (filteredIndex != -1) {
              _filteredProducts[filteredIndex].availableQuantity = newQty;
            }
          }
        }
      });
    } else {
      setState(() {
        _cartItems.add(CartItem(
          product: product,
          quantity: quantity,
          discountType: discountType,
          discountValue: discountValue,
          isNewItem: true, // This is a new item
        ));
        
        final productIndex = _products.indexWhere((p) => p.id == product.id);
        if (productIndex != -1) {
          final newQty = _products[productIndex].availableQuantity - quantity;
          if (newQty >= 0) {
            _products[productIndex].availableQuantity = newQty;
            final filteredIndex = _filteredProducts.indexWhere((p) => p.id == product.id);
            if (filteredIndex != -1) {
              _filteredProducts[filteredIndex].availableQuantity = newQty;
            }
          }
        }
      });
    }
  
    _updateCartTotals();
  }

  void _removeFromCart(Product product) {
    setState(() {
      final itemIndex = _cartItems.indexWhere((item) => item.product.id == product.id);
      if (itemIndex >= 0) {
        final removedItem = _cartItems.removeAt(itemIndex);
        
        final productIndex = _products.indexWhere((p) => p.id == product.id);
        if (productIndex != -1) {
          _products[productIndex].availableQuantity += removedItem.quantity;
          
          final filteredIndex = _filteredProducts.indexWhere((p) => p.id == product.id);
          if (filteredIndex != -1) {
            _filteredProducts[filteredIndex].availableQuantity += removedItem.quantity;
          }
        }
      }
    });
    _updateCartTotals();
  }

  void _updateCartQuantity(Product product, int newQuantity) {
    setState(() {
      final itemIndex = _cartItems.indexWhere((item) => item.product.id == product.id);
      if (itemIndex >= 0) {
        if (newQuantity <= 0) {
          final removedItem = _cartItems.removeAt(itemIndex);
          final productIndex = _products.indexWhere((p) => p.id == product.id);
          if (productIndex != -1) {
            _products[productIndex].availableQuantity += removedItem.quantity;
            final filteredIndex = _filteredProducts.indexWhere((p) => p.id == product.id);
            if (filteredIndex != -1) {
              _filteredProducts[filteredIndex].availableQuantity += removedItem.quantity;
            }
          }
        } else if (newQuantity <= product.availableQuantity + _cartItems[itemIndex].quantity) {
          final difference = newQuantity - _cartItems[itemIndex].quantity;
          _cartItems[itemIndex].quantity = newQuantity;
          
          final productIndex = _products.indexWhere((p) => p.id == product.id);
          if (productIndex != -1) {
            _products[productIndex].availableQuantity -= difference;
            final filteredIndex = _filteredProducts.indexWhere((p) => p.id == product.id);
            if (filteredIndex != -1) {
              _filteredProducts[filteredIndex].availableQuantity -= difference;
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Only ${product.availableQuantity} items available'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
    _updateCartTotals();
  }

  void _updateCartTotals() {
    setState(() {});
  }

  double get _totalSubtotal {
    return _cartItems.fold(0, (sum, item) => sum + item.getSubtotal(_selectedOrderType));
  }

  double get _totalItemDiscount {
    return _cartItems.fold(0.0, (sum, item) => sum + item.getDiscount(_selectedOrderType));
  }

  double get _totalBeforeGlobal {
    return _totalSubtotal - _totalItemDiscount;
  }

  double get _discountPercentage {
    return double.tryParse(_discountController.text) ?? 0.0;
  }

  double get _globalDiscountValue {
    return _totalBeforeGlobal * (_discountPercentage / 100);
  }

  double get _serviceAmount {
    if (_serviceAmountOverride > 0) {
      return _serviceAmountOverride;
    }
    double base = _totalBeforeGlobal - _globalDiscountValue;
    return _selectedTable != null ? base * (_selectedTable!.serviceCharge / 100) : 0.0;
  }

  double get _netAmount {
    double base = _totalBeforeGlobal - _globalDiscountValue;
    return base + _serviceAmount;
  }

void _clearCart() {
  setState(() {
    // Return stock quantities
    for (var cartItem in _cartItems) {
      final product = cartItem.product;
      final productIndex = _products.indexWhere((p) => p.id == product.id);
      if (productIndex != -1) {
        _products[productIndex].availableQuantity += cartItem.quantity;
        final filteredIndex = _filteredProducts.indexWhere((p) => p.id == product.id);
        if (filteredIndex != -1) {
          _filteredProducts[filteredIndex].availableQuantity += cartItem.quantity;
        }
      }
    }
    
    // Clear cart items only
    _cartItems.clear();
    _discountController.text = '0';
    _currentInvoiceId = null;
    _serviceAmountOverride = 0.0;
    _isEditingDueTable = false;
    _existingDueTableItems.clear();
    _isProcessingDueTablePayment = false;
    
    // DO NOT clear customer, waiter, or table selection
  });
}
void _clearEverything() {
  setState(() {
    // Return stock quantities
    for (var cartItem in _cartItems) {
      final product = cartItem.product;
      final productIndex = _products.indexWhere((p) => p.id == product.id);
      if (productIndex != -1) {
        _products[productIndex].availableQuantity += cartItem.quantity;
        final filteredIndex = _filteredProducts.indexWhere((p) => p.id == product.id);
        if (filteredIndex != -1) {
          _filteredProducts[filteredIndex].availableQuantity += cartItem.quantity;
        }
      }
    }
    
    // Clear everything
    _cartItems.clear();
    _discountController.text = '0';
    _selectedCustomer = null;
    _selectedWaiter = null;
    _selectedTable = null;
    _currentInvoiceId = null;
    _serviceAmountOverride = 0.0;
    _isEditingDueTable = false;
    _existingDueTableItems.clear();
    _isProcessingDueTablePayment = false;
  });
}
void _selectFreshTable(Table table) {
  setState(() {
    // Clear everything first
    _clearEverything();
    
    // Set the new table as fresh (no due orders)
    _selectedTable = Table(
      id: table.id,
      name: table.name,
      serviceCharge: table.serviceCharge,
      hasDueOrders: false,
      specialNote: '', // Clear special note for fresh table
    );
  });
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Fresh table "${table.name}" selected'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.blue,
    ),
  );
}

  void _clearCartForBillCopy() {
    setState(() {
      // Return stock quantities
      for (var cartItem in _cartItems) {
        final product = cartItem.product;
        final productIndex = _products.indexWhere((p) => p.id == product.id);
        if (productIndex != -1) {
          _products[productIndex].availableQuantity += cartItem.quantity;
          final filteredIndex = _filteredProducts.indexWhere((p) => p.id == product.id);
          if (filteredIndex != -1) {
            _filteredProducts[filteredIndex].availableQuantity += cartItem.quantity;
          }
        }
      }
      
      // Clear cart items only
      _cartItems.clear();
      _discountController.text = '0';
      _currentInvoiceId = null;
      _serviceAmountOverride = 0.0;
      _isEditingDueTable = false;
      _existingDueTableItems.clear();
      _isProcessingDueTablePayment = false;
      // Don't clear customer, waiter, or table selection
    });
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _showOrderTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Order Type',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: OrderType.values.map((orderType) {
                  return _buildOrderTypeChip(orderType);
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('CLOSE', style: GoogleFonts.poppins()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTypeChip(OrderType orderType) {
    final isSelected = _selectedOrderType == orderType;
    return FilterChip(
      selected: isSelected,
      label: Text(orderType.displayName, style: GoogleFonts.poppins()),
      avatar: Icon(orderType.icon, color: isSelected ? Colors.white : orderType.color),
      backgroundColor: isSelected ? orderType.color : Colors.grey[200],
      selectedColor: orderType.color,
      selectedShadowColor: orderType.color.withOpacity(0.3),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: FontWeight.w500,
      ),
      onSelected: (selected) {
        setState(() {
          _selectedOrderType = orderType;
        });
        Navigator.pop(context);
      },
    );
  }

  void _showCustomerDialog() {
    _searchController.clear();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Select Customer',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => _showAddCustomerDialog(context),
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search customers...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _filteredCustomers = _customers.where((customer) =>
                            customer.name.toLowerCase().contains(value.toLowerCase()) ||
                            customer.phone.contains(value)
                          ).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _filteredCustomers.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                                      SizedBox(height: 16),
                                      Text('No customers found', style: TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _filteredCustomers.length,
                                  itemBuilder: (context, index) {
                                    final customer = _filteredCustomers[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.person, color: Colors.blue, size: 20),
                                        ),
                                        title: Text(customer.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                        subtitle: Text(customer.phone),
                                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                        onTap: () {
                                          Navigator.pop(context);
                                          this.setState(() {
                                            _selectedCustomer = customer;
                                          });
                                        },
                                      ),
                                    ).animate().fadeIn(duration: 300.ms);
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showWaiterDialog() {
    _waiterSearchController.clear();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Select Waiter',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _waiterSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search waiters...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _filteredWaiters = _waiters.where((waiter) =>
                            waiter.name.toLowerCase().contains(value.toLowerCase())
                          ).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _filteredWaiters.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_pin_outlined, size: 64, color: Colors.grey),
                                      SizedBox(height: 16),
                                      Text('No waiters found', style: TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _filteredWaiters.length,
                                  itemBuilder: (context, index) {
                                    final waiter = _filteredWaiters[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.person_pin, color: Colors.blue, size: 20),
                                        ),
                                        title: Text(waiter.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                        onTap: () {
                                          Navigator.pop(context);
                                          setState(() {
                                            _selectedWaiter = waiter;
                                          });
                                        },
                                      ),
                                    ).animate().fadeIn(duration: 300.ms);
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // MODIFIED: Removed special note dialog when selecting table
  void _showTableDialog() {
    _tableSearchController.clear();
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isLandscape ? MediaQuery.of(context).size.width * 0.8 : MediaQuery.of(context).size.width * 0.9,
                maxHeight: isLandscape ? MediaQuery.of(context).size.height * 0.9 : MediaQuery.of(context).size.height * 0.8,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Select Table',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _tableSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search tables...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _filteredTables = _tables.where((table) =>
                            table.name.toLowerCase().contains(value.toLowerCase())
                          ).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _filteredTables.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.table_chart_outlined, size: 64, color: Colors.grey),
                                      SizedBox(height: 16),
                                      Text('No tables found', style: TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _filteredTables.length,
                                  itemBuilder: (context, index) {
                                    final table = _filteredTables[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.table_chart,
                                            color: Colors.blue,
                                            size: 20,
                                          ),
                                        ),
                                        title: Text(table.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                        subtitle: Text('Service Charge: ${table.serviceCharge}%'),
                                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                       onTap: () {
                                          Navigator.pop(context);
                                          // Select table without showing special note dialog
                                          this.setState(() {
                                            // Clear any previous table selection first
                                            _selectedTable = null;
                                            _cartItems.clear();
                                            _currentInvoiceId = null;
                                            _serviceAmountOverride = 0.0;
                                            _isEditingDueTable = false;
                                            _existingDueTableItems.clear();
                                            
                                            // Set new table (without special note)
                                            _selectedTable = Table(
                                              id: table.id,
                                              name: table.name,
                                              serviceCharge: table.serviceCharge,
                                              hasDueOrders: table.hasDueOrders,
                                              specialNote: '', // Clear special note for selection
                                            );
                                          });
                                          
                                          // Now load table items
                                          _loadTableItems();
                                        },
                                      ),
                                    ).animate().fadeIn(duration: 300.ms);
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDueTablesDialog() async {
    setState(() => _isLoading = true);
   
    try {
      final dueTables = await _loadDueTablesFromAPI();
     
      if (dueTables.isEmpty) {
        _showMessage('No due tables found');
        return;
      }
      
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            List<Table> currentDueTables = List.from(dueTables);
           
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Ongoing Tables',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Text(
                              'Active orders',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.red[700],
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.refresh, color: Colors.grey[700]),
                            onPressed: () async {
                              setDialogState(() {});
                              final refreshedTables = await _loadDueTablesFromAPI();
                              setDialogState(() {
                                currentDueTables = refreshedTables;
                              });
                            },
                          ),
                        ],
                      ),
                     
                      const SizedBox(height: 4),
                      Divider(color: Colors.grey[300], thickness: 1),
                      const SizedBox(height: 8),
                     
                      Expanded(
                        child: currentDueTables.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.table_chart_outlined, size: 64, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No active tables',
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey[500],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 3.4,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: currentDueTables.length,
                                itemBuilder: (context, index) {
                                  final table = currentDueTables[index];
                                  return _buildTableCardFromImage(table, () {
                                    currentDueTables.removeAt(index);
                                    setDialogState(() {});
                                  });
                                },
                              ),
                      ),
                     
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            foregroundColor: Colors.black87,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'CLOSE',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      _showMessage('Error loading due tables: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // MODIFIED: Show special note in table card
  Widget _buildTableCardFromImage(Table table, VoidCallback onMarkAsPaid) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _selectedTable = Table(
            id: table.id,
            name: table.name,
            serviceCharge: table.serviceCharge,
            hasDueOrders: table.hasDueOrders,
            specialNote: table.specialNote, // Load special note from table
          );
        });
        _loadDueTableItems(table);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Row(
                    children: [
                      Icon(
                        table.name.toLowerCase().contains('box')
                            ? Icons.square_rounded
                            : Icons.circle,
                        color: Colors.blue[700],
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        table.name,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Text(
                      'Active',
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
              // ADDED: Show special note if exists
              if (table.specialNote.isNotEmpty) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.yellow[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    table.specialNote,
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      color: Colors.orange[800],
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markTableAsPaid(Table table, VoidCallback onSuccess) async {
    try {
      final headers = await _getAuthHeaders();
      
      final response = await http.post(
        Uri.parse('https://api-cloudchef.sltcloud.lk/api/invoice-create/mark-table-paid/${table.id}'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        setState(() {
          _tables = _tables.map((t) {
            if (t.id == table.id) {
              return Table(
                id: t.id!,
                name: t.name,
                serviceCharge: t.serviceCharge,
                hasDueOrders: false,
                specialNote: '', // Clear special note after payment
              );
            }
            return t;
          }).toList();
          _filteredTables = _tables;
        });
        
        // Remove local special note
        await _removeLocalTableNote(table.id);
        
        onSuccess();
      }
    } catch (e) {
      _showMessage('Error marking table as paid: $e');
    }
  }

  // FIXED: Updated _showAddCustomerDialog to be responsive
  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final nicController = TextEditingController();
    final addressController = TextEditingController();

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLandscape ? MediaQuery.of(context).size.width * 0.6 : 400,
            maxHeight: isLandscape ? MediaQuery.of(context).size.height * 0.8 : 500,
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add New Customer',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Name*',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone*',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nicController,
                    decoration: InputDecoration(
                      labelText: 'NIC',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'CANCEL',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Name and Phone are required'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            final newCustomer = Customer(
                              name: nameController.text,
                              phone: phoneController.text,
                              email: emailController.text,
                              nic: nicController.text,
                              address: addressController.text,
                            );
                            Navigator.pop(context);
                            _addCustomer(newCustomer);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'ADD',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final isInStock = product.availableQuantity > 0;
    final currentPrice = _selectedOrderType == OrderType.whole ? product.wsPrice : product.price;
    final cardHeight = 50.0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isInStock ? () => _showAddProductDialog(product) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: cardHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      color: Colors.grey[100],
                      image: product.productImage != null
                          ? DecorationImage(
                              image: NetworkImage(product.productImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: product.productImage == null
                        ? Center(
                            child: Icon(
                              Icons.fastfood,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                          )
                        : null,
                  ),
                ),
                
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 4),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Rs.${currentPrice.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartItem(CartItem cartItem) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cartItem.product.name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rs.${cartItem.getPriceByOrderType(_selectedOrderType).toStringAsFixed(2)} x ${cartItem.quantity}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    'Total: Rs.${cartItem.getTotalPrice(_selectedOrderType).toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: () => _updateCartQuantity(cartItem.product, cartItem.quantity - 1),
                  padding: EdgeInsets.zero,
                ),
                Text(
                  cartItem.quantity.toString(),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () => _updateCartQuantity(cartItem.product, cartItem.quantity + 1),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  onPressed: () => _removeFromCart(cartItem.product),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesPanel() {
    return Container(
      width: 140, 
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color.fromARGB(255, 255, 255, 255),
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: Text(
              'Categories',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: const Color.fromARGB(255, 1, 6, 10),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          Expanded(
            child: _categories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.category_outlined, size: 32, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          'No categories',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(4),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory?.id == category.id;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _filterProductsByCategory(category),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? Colors.blue : Colors.grey[300]!,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.category,
                                    size: 14,
                                    color: isSelected ? Colors.blue : Colors.grey[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      category.categoryName.length > 12 
                                          ? '${category.categoryName.substring(0, 12)}...' 
                                          : category.categoryName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? Colors.blue : Colors.grey[700],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.blue,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Cart - ${_cartItems.length} items',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
          
            if (_cartItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Summary',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Subtotal: Rs.${_totalSubtotal.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          
            const SizedBox(height: 16),
          
            Expanded(
              child: _cartItems.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('Your cart is empty'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _cartItems.length,
                      itemBuilder: (context, index) {
                        return _buildCartItem(_cartItems[index]);
                      },
                    ),
            ),
          
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildTotalRow('Subtotal', _totalSubtotal),
                  _buildTotalRow('Item Discounts', -_totalItemDiscount),
                  _buildTotalRow('Discount (${_discountPercentage}%)', -_globalDiscountValue),
                  if (_selectedTable != null && _serviceAmount > 0)
                    _buildTotalRow('Service Charge', _serviceAmount),
                  const Divider(),
                  _buildTotalRow(
                    'NET AMOUNT',
                    _netAmount,
                    isBold: true,
                    isTotal: true,
                  ),
                  const SizedBox(height: 16),
                
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _discountController,
                          decoration: InputDecoration(
                            labelText: 'Discount %',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Rs.${_globalDiscountValue.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                
                  const SizedBox(height: 16),
                
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _cartItems.isEmpty ? null : _showPaymentScreen,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'PROCEED TO PAYMENT',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                
                  const SizedBox(height: 8),
                
                  if (_cartItems.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _saveInvoice(),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: const BorderSide(color: Colors.blue),
                            ),
                            child: Text(
                              'SAVE INV',
                              style: GoogleFonts.poppins(color: Colors.blue),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _saveInvoice(isDue: true),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: const BorderSide(color: Colors.orange),
                            ),
                            child: Text(
                              'DUE INV',
                              style: GoogleFonts.poppins(color: Colors.orange),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isBold = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green : Colors.black,
            ),
          ),
          Text(
            'Rs.${amount.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green : (amount < 0 ? Colors.red : Colors.black),
            ),
          ),
        ],
      )
    );
  }

  Widget _buildCartPanel() {
    return Container(
      width: 280,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cart (${_cartItems.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                // ADDED: Show special note indicator if exists
                if (_selectedTable != null && _selectedTable!.specialNote.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.yellow[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.note, size: 12, color: Colors.orange[800]),
                        const SizedBox(width: 4),
                        Text(
                          'Note',
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        
          Expanded(
            child: _cartItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'Cart is empty',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add items from the left',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(4),
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      return _buildCartItemForPanel(_cartItems[index]);
                    },
                  ),
          ),
        
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
              child: Column(
                children: [
                 
                  
                  _buildSummaryRow('Gross Amount:', _totalSubtotal),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _discountController,
                          decoration: InputDecoration(
                            labelText: 'Discount (%)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[100]!),
                          ),
                          child: Text(
                            'Rs.${_globalDiscountValue.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  if (_selectedTable != null && _serviceAmount > 0)
                    _buildSummaryRow('Service Charge:', _serviceAmount),
                  
                  const Divider(height: 20),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[100]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'NET AMOUNT:',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                        Text(
                          'Rs.${_netAmount.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _cartItems.isEmpty ? null : _showPaymentScreen,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            'PAY NOW',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      if (_cartItems.isNotEmpty)
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 40,
                                child: OutlinedButton(
                                  onPressed: () => _saveInvoice(),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    side: const BorderSide(color: Colors.blue),
                                  ),
                                  child: Text(
                                    'SAVE INV',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 40,
                                child: OutlinedButton(
                                  onPressed: () => _saveInvoice(isDue: true),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    side: const BorderSide(color: Colors.orange),
                                  ),
                                  child: Text(
                                    'DUE INV',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildCartItemForPanel(CartItem cartItem) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4), 
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    cartItem.product.name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 12, 
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2), 
                  Row(
                    children: [
                      Text(
                        'Rs.${cartItem.getPriceByOrderType(_selectedOrderType).toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 10, 
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 1,
                        height: 10,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'x${cartItem.quantity}',
                        style: GoogleFonts.poppins(
                          fontSize: 10, 
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24, 
                        height: 20,
                        child: IconButton(
                          icon: const Icon(Icons.remove, size: 12),
                          onPressed: () => _updateCartQuantity(cartItem.product, cartItem.quantity - 1),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                      Container(
                        width: 24,
                        alignment: Alignment.center,
                        child: Text(
                          cartItem.quantity.toString(),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 12, 
                          ),
                        ),
                      ),
                      Container(
                        width: 24,
                        height: 20,
                        child: IconButton(
                          icon: const Icon(Icons.add, size: 12),
                          onPressed: () => _updateCartQuantity(cartItem.product, cartItem.quantity + 1),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 2), 
                
                Text(
                  'Rs.${cartItem.getTotalPrice(_selectedOrderType).toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11, 
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            
            const SizedBox(width: 4),
            Container(
              width: 24,
              height: 24,
              child: IconButton(
                icon: const Icon(Icons.close, size: 14, color: Colors.red),
                onPressed: () => _removeFromCart(cartItem.product),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          Text(
            'Rs.${amount.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ],
      )
    );
  }

  void _toggleListView() {
    setState(() {
      _showListView = !_showListView;
    });
  }

  Widget _buildProductCardGrid(Product product) {
    final isInStock = product.availableQuantity > 0;
    final currentPrice = _selectedOrderType == OrderType.whole ? product.wsPrice : product.price;
    final cardHeight = 50.0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isInStock ? () => _showAddProductDialog(product) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: cardHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      color: Colors.grey[100],
                      image: product.productImage != null
                          ? DecorationImage(
                              image: NetworkImage(product.productImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: product.productImage == null
                        ? Center(
                            child: Icon(
                              Icons.fastfood,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                          )
                        : null,
                  ),
                ),
                
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 4),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Rs.${currentPrice.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductItemList(Product product) {
    final isInStock = product.availableQuantity > 0;
    final currentPrice = _selectedOrderType == OrderType.whole ? product.wsPrice : product.price;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: product.productImage != null
            ? Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(product.productImage!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            : Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fastfood, color: Colors.grey),
              ),
        title: Text(
          product.name,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Rs.${currentPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),
        trailing: isInStock
            ? ElevatedButton(
                onPressed: () {
                  _showAddProductDialog(product);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  'Add',
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
              )
            : Text(
                'Out of Stock',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
      ),
    );
  }

  // NEW: Load local table notes from SharedPreferences
  Future<void> _loadLocalTableNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notesJson = prefs.getString('table_special_notes');
      if (notesJson != null) {
        final Map<String, dynamic> notesMap = json.decode(notesJson);
        setState(() {
          _tableSpecialNotes = notesMap.map((key, value) => 
            MapEntry(int.parse(key), value.toString()));
        });
      }
    } catch (e) {
      print('Error loading local table notes: $e');
    }
  }

  // NEW: Save table note locally
  Future<void> _saveLocalTableNote(int tableId, String note) async {
    try {
      setState(() {
        _tableSpecialNotes[tableId] = note;
      });
      
      final prefs = await SharedPreferences.getInstance();
      final notesJson = json.encode(_tableSpecialNotes);
      await prefs.setString('table_special_notes', notesJson);
    } catch (e) {
      print('Error saving local table note: $e');
    }
  }

  // NEW: Remove table note locally
  Future<void> _removeLocalTableNote(int tableId) async {
    try {
      setState(() {
        _tableSpecialNotes.remove(tableId);
      });
      
      final prefs = await SharedPreferences.getInstance();
      final notesJson = json.encode(_tableSpecialNotes);
      await prefs.setString('table_special_notes', notesJson);
    } catch (e) {
      print('Error removing local table note: $e');
    }
  }

  // ADDED: Loading screen widget
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator.adaptive(),
            const SizedBox(height: 20),
            Text(
              'Cloud Chef POS',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 10),
            const Text('Loading data...'),
            const SizedBox(height: 20),
            Text(
              'Please wait while we load your data',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen if data is not loaded yet
    if (_isInitialLoading || !_dataLoaded) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'Cloud Chef POS',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            if (_selectedCustomer != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  'Customer: ${_selectedCustomer!.name}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ),
            if (_selectedTable != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Row(
                  children: [
                    Text(
                      'Table: ${_selectedTable!.name}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    if (_selectedTable!.specialNote.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.note, size: 16, color: Colors.yellow),
                      ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: _showPrinterDialog,
            tooltip: 'Printers',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Row(
        children: [
          _buildCategoriesPanel(),
          
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 45,
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _showOrderTypeDialog,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(_selectedOrderType.icon, color: Colors.blue, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        _selectedOrderType.displayName,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _printBillCopy,
                                borderRadius: BorderRadius.circular(10),
                                child: const Icon(
                                  Icons.copy,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSelectionChip(
                              _selectedCustomer?.name ?? 'Customer',
                              Icons.person,
                              _showCustomerDialog,
                            ),
                            const SizedBox(width: 8),
                            _buildSelectionChip(
                              _selectedWaiter?.name ?? 'Waiter',
                              Icons.person_pin,
                              _showWaiterDialog,
                            ),
                            const SizedBox(width: 8),
                            _buildSelectionChip(
                              _selectedTable?.name ?? 'Table',
                              Icons.table_chart,
                              _showTableDialog,
                            ),
                            const SizedBox(width: 8),
                           
                            Container(
                              height: 35,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.red[100]!),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _showDueTablesDialog,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.money_off, size: 16, color: Colors.red[800]),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Due Tables',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.red[800],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                           
                            Container(
                              height: 35,
                              width: 35,
                              decoration: BoxDecoration(
                                color: _showListView ? Colors.blue[100] : Colors.blue[50],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.blue[100]!),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _toggleListView,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Icon(
                                    _showListView ? Icons.grid_view : Icons.list,
                                    size: 18,
                                    color: _showListView ? Colors.blue[800] : Colors.blue,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    
                      Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            const Icon(Icons.search, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _productSearchController,
                                decoration: InputDecoration(
                                  hintText: 'Search products...',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onChanged: _searchProducts,
                              ),
                            ),
                            if (_productSearchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _productSearchController.clear();
                                  _searchProducts('');
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              
                Expanded(
                  child: _isLoadingProducts
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No products found',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _showListView
                              ? ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: _filteredProducts.length,
                                  itemBuilder: (context, index) {
                                    return _buildProductItemList(_filteredProducts[index]);
                                  },
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.all(8),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 6,
                                    childAspectRatio: 0.65,
                                    crossAxisSpacing: 4,
                                    mainAxisSpacing: 4, 
                                  ),
                                  itemCount: _filteredProducts.length,
                                  itemBuilder: (context, index) {
                                    return _buildProductCardGrid(_filteredProducts[index]);
                                  },
                                ),
                ),
              ],
            ),
          ),
          
          Container(
            width: 280,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
            child: _buildCartPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionChip(String text, IconData icon, VoidCallback onTap) {
    return Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.blue),
              const SizedBox(width: 4),
              Text(
                text.length > 10 ? '${text.substring(0, 10)}...' : text,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.blue,
      ),
    );
  }
}

class PaymentScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final Customer? selectedCustomer;
  final Table? selectedTable;
  final Waiter? selectedWaiter;
  final OrderType selectedOrderType;
  final double netAmount;
  final double discountPercentage;
  final double globalDiscountValue;
  final double serviceAmount;
  final double totalSubtotal;
  final int? currentInvoiceId;
  final bool isDueTable; // Add this parameter
  
  const PaymentScreen({
    super.key,
    required this.cartItems,
    this.selectedCustomer,
    this.currentInvoiceId,
    this.selectedTable,
    this.selectedWaiter,
    required this.selectedOrderType,
    required this.netAmount,
    required this.discountPercentage,
    required this.globalDiscountValue,
    required this.serviceAmount,
    required this.totalSubtotal,
    this.isDueTable = false, // Default to false
  });
  
  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _cashAmountController = TextEditingController();
  final TextEditingController _bankTransferAmountController = TextEditingController();
  final TextEditingController _creditAmountController = TextEditingController();
  final TextEditingController _cardAmountController = TextEditingController();
 
  double cashPaid = 0.0;
  double bankTransferPaid = 0.0;
  double creditUsed = 0.0;
  double cardPaid = 0.0;
  double totalPaid = 0.0;
  double remainingBalance = 0.0;
  bool _isProcessingPayment = false;
  String? authToken;
  Map<String, dynamic>? userData;
 
  static const Color primaryColor = Color(0xFF1A3C34);
  static const Color accentColor = Color(0xFFFFCA28);
 
  late TabController _tabController;
  List<Map<String, dynamic>> banks = [];
  Map<String, dynamic>? selectedBankTransferBank;
  Map<String, dynamic>? selectedCardBank;
  bool _loadingBanks = false;
  String? _bankLoadError;
  bool _initialLoadAttempted = false;
  
  bool _cardTabVisited = false;
  bool _cashTabVisited = false;
  bool _bankTabVisited = false;
  bool _creditTabVisited = false;
  
  @override
  void initState() {
    super.initState();
    
    _tabController = TabController(length: 4, vsync: this);
    remainingBalance = widget.netAmount;
    
    cashPaid = 0.0;
    bankTransferPaid = 0.0;
    creditUsed = 0.0;
    cardPaid = 0.0;
    totalPaid = 0.0;
    remainingBalance = widget.netAmount;
    
    _cashAmountController.clear();
    _bankTransferAmountController.clear();
    _creditAmountController.clear();
    _cardAmountController.clear();
    
    _cashTabVisited = false;
    _bankTabVisited = false;
    _creditTabVisited = false;
    _cardTabVisited = false;
    
    _tabController.addListener(_handleTabChange);
    _loadAuthTokenAndUserData();
    
    // Auto-fill card amount if it's a due table
    if (widget.isDueTable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoFillCardAmountForDueTable();
      });
    }
  }
  
  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      final currentIndex = _tabController.index;
      
      switch (currentIndex) {
        case 0:
          if (!_cashTabVisited) {
            setState(() {
              _cashTabVisited = true;
            });
          }
          break;
        case 1:
          if (!_bankTabVisited) {
            setState(() {
              _bankTabVisited = true;
            });
          }
          break;
        case 2:
          if (!_creditTabVisited) {
            setState(() {
              _creditTabVisited = true;
            });
          }
          break;
        case 3:
          if (!_cardTabVisited) {
            setState(() {
              _cardTabVisited = true;
            });
            // Auto-fill card amount with remaining balance when card tab is first visited
            _autoFillCardAmount();
          } else {
            // When revisiting card tab, auto-fill with remaining balance
            _autoFillCardAmount();
          }
          break;
      }
    }
  }
  
  void _autoFillCardAmount() {
    // Calculate remaining balance
    double currentTotalPaid = cashPaid + bankTransferPaid + creditUsed + cardPaid;
    double currentRemainingBalance = widget.netAmount - currentTotalPaid;
    
    // If there's remaining balance, auto-fill card amount with it
    if (currentRemainingBalance > 0) {
      setState(() {
        cardPaid = currentRemainingBalance;
        _cardAmountController.text = cardPaid.toStringAsFixed(2);
        
        // Recalculate total paid and remaining balance
        totalPaid = cashPaid + bankTransferPaid + creditUsed + cardPaid;
        remainingBalance = widget.netAmount - totalPaid;
      });
    }
  }
  
  void _autoFillCardAmountForDueTable() {
    // For due tables, auto-fill card amount with the full net amount
    setState(() {
      cardPaid = widget.netAmount;
      _cardAmountController.text = cardPaid.toStringAsFixed(2);
      
      // Recalculate total paid and remaining balance
      totalPaid = cashPaid + bankTransferPaid + creditUsed + cardPaid;
      remainingBalance = widget.netAmount - totalPaid;
    });
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _cashAmountController.dispose();
    _bankTransferAmountController.dispose();
    _creditAmountController.dispose();
    _cardAmountController.dispose();
    super.dispose();
  }
  
  Future<void> _loadAuthTokenAndUserData() async {
    setState(() {
      _loadingBanks = true;
      _bankLoadError = null;
    });
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Authentication token not available. Please login again.');
      }
      setState(() {
        authToken = token;
      });
      await _loadUserData();
      await _loadBanks();
    } catch (e) {
      setState(() {
        _bankLoadError = 'Error: ${e.toString()}';
        _loadingBanks = false;
      });
    }

    setState(() {
      _initialLoadAttempted = true;
    });
  }
  
  Future<void> _loadUserData() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? userDataString = prefs.getString('user_data');
   
      if (userDataString != null) {
        final Map<String, dynamic> userDataMap = json.decode(userDataString);
        setState(() {
          userData = userDataMap;
        });
      } else {
        await _fetchUserDataFromAPI();
      }
    } catch (e) {
      await _fetchUserDataFromAPI();
    }
  }
  
  Future<void> _fetchUserDataFromAPI() async {
    if (authToken == null) return;

    try {
      final response = await http.get(
        Uri.parse('https://api-cloudchef.sltcloud.lk/api/user'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
          'referer': REFERER_HEADER,
        },
      ).timeout(const Duration(seconds: 10));
   
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
     
        if (data is Map<String, dynamic>) {
          setState(() {
            userData = data;
          });
       
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', json.encode(data));
        }
      }
    } catch (e) {
      // Silent fail
    }
  }
  
  Future<void> _loadBanks() async {
    if (authToken == null) {
      setState(() {
        _bankLoadError = 'Authentication token not available';
        _loadingBanks = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://api-cloudchef.sltcloud.lk/api/bank-list'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
          'referer': REFERER_HEADER,
        },
      ).timeout(const Duration(seconds: 10));
   
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
     
        List<dynamic> banksList = [];
     
        if (data is List) {
          banksList = data;
        } else if (data['data'] is List) {
          banksList = data['data'];
        } else if (data is Map<String, dynamic>) {
          final listKey = data.keys.firstWhere(
            (key) => data[key] is List,
            orElse: () => '',
          );
          if (listKey.isNotEmpty) {
            banksList = data[listKey];
          }
        }
     
        if (banksList.isNotEmpty) {
          setState(() {
            banks = List<Map<String, dynamic>>.from(banksList);
            if (banks.isNotEmpty) {
              selectedBankTransferBank = banks.first;
              selectedCardBank = banks.first;
            }
            _bankLoadError = null;
          });
        } else {
          throw Exception('No bank data found in response');
        }
      } else if (response.statusCode == 401) {
        _handleUnauthorizedError();
      } else {
        throw Exception('Failed to load bank list: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _bankLoadError = 'Error loading bank list: ${e.toString()}';
      });
    } finally {
      setState(() {
        _loadingBanks = false;
      });
    }
  }
  
  void _retryBankLoad() {
    _loadAuthTokenAndUserData();
  }
  
  void _handleUnauthorizedError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Session expired. Please login again.',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _updatePaymentAmount(String method, String value) {
    double amount = double.tryParse(value) ?? 0.0;
    
    setState(() {
      switch (method) {
        case 'Cash':
          cashPaid = amount;
          break;
        case 'Bank Transfer':
          bankTransferPaid = amount;
          break;
        case 'Credit':
          if (widget.selectedCustomer?.id != null) {
            creditUsed = amount;
          } else {
            creditUsed = 0.0;
            if (value.isNotEmpty) {
              _creditAmountController.text = '';
            }
          }
          break;
        case 'Card':
          cardPaid = amount;
          break;
      }
      
      totalPaid = cashPaid + bankTransferPaid + creditUsed + cardPaid;
      remainingBalance = widget.netAmount - totalPaid;
    });
  }

  void _adjustPaymentsForOverpayment(String changedMethod, double attemptedAmount) {
    double newCardPaid = 0.0;
    double newCashPaid = 0.0;
    double newBankPaid = 0.0;
    double newCreditUsed = 0.0;
    
    switch (changedMethod) {
      case 'Cash':
        newCashPaid = attemptedAmount > widget.netAmount ? widget.netAmount : attemptedAmount;
        break;
      case 'Bank Transfer':
        newBankPaid = attemptedAmount > widget.netAmount ? widget.netAmount : attemptedAmount;
        break;
      case 'Credit':
        newCreditUsed = attemptedAmount > widget.netAmount ? widget.netAmount : attemptedAmount;
        break;
      case 'Card':
        newCardPaid = attemptedAmount > widget.netAmount ? widget.netAmount : attemptedAmount;
        break;
    }
    
    setState(() {
      cashPaid = newCashPaid;
      bankTransferPaid = newBankPaid;
      creditUsed = newCreditUsed;
      cardPaid = newCardPaid;
      
      _cashAmountController.text = newCashPaid > 0 ? newCashPaid.toStringAsFixed(2) : '';
      _bankTransferAmountController.text = newBankPaid > 0 ? newBankPaid.toStringAsFixed(2) : '';
      _creditAmountController.text = newCreditUsed > 0 ? newCreditUsed.toStringAsFixed(2) : '';
      _cardAmountController.text = newCardPaid > 0 ? newCardPaid.toStringAsFixed(2) : '';
      
      totalPaid = cashPaid + bankTransferPaid + creditUsed + cardPaid;
      remainingBalance = widget.netAmount - totalPaid;
    });
  }

  Future<Map<String, dynamic>> _processPayment() async {
    if (_isProcessingPayment) return {'success': false, 'invoiceNumber': null};
    setState(() => _isProcessingPayment = true);
    
    if (widget.selectedTable != null && widget.selectedTable!.id == null) {
      _showError('Selected table has no valid ID. Please select a different table.');
      setState(() => _isProcessingPayment = false);
      return {'success': false, 'invoiceNumber': null};
    }
    
    if (totalPaid < widget.netAmount) {
      _showError('Total payment (${totalPaid.toStringAsFixed(2)}) is less than invoice amount (${widget.netAmount.toStringAsFixed(2)})');
      setState(() => _isProcessingPayment = false);
      return {'success': false, 'invoiceNumber': null};
    }
    
    if (creditUsed > 0 && widget.selectedCustomer?.id == null) {
      _showError('Customer ID is required for credit payment');
      setState(() => _isProcessingPayment = false);
      return {'success': false, 'invoiceNumber': null};
    }
    
    try {
      final paymentPayload = await _buildPaymentPayload();
  
      print('Payment Payload: ${json.encode(paymentPayload)}');
  
      final response = await http.post(
        Uri.parse('https://api-cloudchef.sltcloud.lk/api/payment'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
          'referer': REFERER_HEADER,
        },
        body: json.encode(paymentPayload),
      ).timeout(const Duration(seconds: 30));
     
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        
        // FIXED: Extract invoice number from response
        String? invoiceNumber;
        if (responseData['data'] != null && responseData['data']['invoice_head'] != null) {
          invoiceNumber = responseData['data']['invoice_head']['invoice_code'];
        }
        
        await _showSuccessDialog(responseData, invoiceNumber);
        return {'success': true, 'invoiceNumber': invoiceNumber};
      } else {
        throw Exception('Payment failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _showError('Payment error: $e');
      return {'success': false, 'invoiceNumber': null};
    } finally {
      setState(() => _isProcessingPayment = false);
    }
  }

  Future<void> _showSuccessDialog(Map<String, dynamic> responseData, String? invoiceNumber) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 32),
              const SizedBox(width: 12),
              Text(
                'Success!',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Payment processed successfully!',
                style: GoogleFonts.poppins(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice #: ${invoiceNumber ?? 'N/A'}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total: Rs.${widget.netAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop({'success': true, 'invoiceNumber': invoiceNumber});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'OK',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _buildPaymentPayload() async {
    if (userData == null) {
      throw Exception('User data not loaded. Please try again.');
    }
    
    String branch = userData!['branch_id']?.toString() ?? '1';
    String userName = userData!['name']?.toString() ?? 'Unknown';
    String userId = userData!['id']?.toString() ?? '0';
    
    String saleType = widget.selectedTable != null 
        ? 'DINE IN'  
        : 'TAKE AWAY'; 
    
    List<Map<String, dynamic>> items = [];
    for (var item in widget.cartItems) {
      double price = item.getPriceByOrderType(widget.selectedOrderType);
      double disVal = item.getDiscount(widget.selectedOrderType);
      double dis = item.discountType == '%' ? item.discountValue : 0.0;
      double total = item.getTotalPrice(widget.selectedOrderType);
      
      int lotId = 0;
      String lotNumber = item.product.lotNumber;
      
      if (item.product.lotsqty.isNotEmpty) {
        for (var lot in item.product.lotsqty) {
          final qty = int.tryParse(lot['qty']?.toString() ?? '0') ?? 0;
          if (qty > 0) {
            lotId = lot['id'] ?? lot['lot_id'] ?? 0;
            lotNumber = lot['lot_number']?.toString() ?? '';
            break;
          }
        }
        
        if (lotId == 0 && lotNumber.isNotEmpty) {
          try {
            lotId = int.tryParse(lotNumber) ?? 0;
          } catch (e) {
            print('Failed to parse lot number: $lotNumber');
          }
        }
        
        if (lotId == 0) {
          final firstLot = item.product.lotsqty.first;
          lotId = firstLot['id'] ?? firstLot['lot_id'] ?? 1;
        }
      } else {
        if (item.product.lotNumber.isNotEmpty) {
          try {
            lotId = int.tryParse(item.product.lotNumber) ?? 1;
          } catch (e) {
            lotId = 1;
          }
        } else {
          lotId = 1;
        }
      }
      
      if (lotId == 0) {
        lotId = 1;
      }
      
      items.add({
        'aQty': item.product.availableQuantity + item.quantity,
        'bar_code': item.product.barCode,
        'cost': item.product.cost,
        'dis': dis,
        'disVal': disVal,
        'exp': item.product.expiryDate,
        'lot_id': lotId,
        'lot_index': 0,
        'name': item.product.name,
        'price': price,
        'qty': item.quantity,
        's_name': null,
        'sid': item.product.tblStockId,
        'stock': item.product.stockName,
        'total': total.toStringAsFixed(2),
        'total_discount': disVal.toStringAsFixed(2),
        'unit': item.product.unit,
      });
    }
    
    Map<String, dynamic> metadata = {
      'id': widget.currentInvoiceId,
      'advance_payment': '',
      'bill_copy_issued': 0,
      'billDis': widget.discountPercentage.toString(),
      'billDisVal': widget.globalDiscountValue.toStringAsFixed(2),
      'customer': widget.selectedCustomer != null ? {
        'id': widget.selectedCustomer!.id,
        'name': widget.selectedCustomer!.name,
        'phone': widget.selectedCustomer!.phone ?? '',
        'email': widget.selectedCustomer!.email ?? '',
        'nic': widget.selectedCustomer!.nic ?? '',
        'address': widget.selectedCustomer!.address ?? '',
      } : {
        'id': 0,
        'name': 'Walk-in Customer',
        'phone': '',
        'email': '',
        'nic': '',
        'address': '',
      },
      'free_issue': 0,
      'grossAmount': widget.totalSubtotal.toStringAsFixed(2),
      'invDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'items': items,
      'netAmount': widget.netAmount.toStringAsFixed(2),
      'order_now_order_info_id': null,
      'room_booking': '',
      'saleType': saleType,
      'service_charge': widget.selectedTable != null ? widget.serviceAmount.toStringAsFixed(2) : '0.00',
      'services': [],
      'tbl_room_booking_id': '',
      'waiter_id': widget.selectedWaiter?.id ?? 0,
      'waiter_name': widget.selectedWaiter?.name ?? '',
    };
    
    if (widget.selectedTable != null) {
      metadata['table_name_id'] = {
        'id': widget.selectedTable!.id,
        'name': widget.selectedTable!.name,
        'service_charge': widget.selectedTable!.serviceCharge,
        'special_note': widget.selectedTable!.specialNote, // ADDED: Include special note
      };
    }
    
    // Build bank data - FIXED: Ensure all fields are properly formatted
    Map<String, dynamic> bankData = {};
    if (bankTransferPaid > 0) {
      bankData = {
        'amount': bankTransferPaid.toStringAsFixed(2),
        'code': selectedBankTransferBank?['id']?.toString() ?? "",
        'branch': branch,
        'user_name': userName,
        'user_id': userId,
      };
    }
    
    // Build card data - FIXED: cardBank should not be an empty object when not selected
    Map<String, dynamic> cardData = {};
    if (cardPaid > 0) {
      cardData = {
        'card_no': '0000',
        'cardAmount': cardPaid.toStringAsFixed(2),
        'cardType': 'VISA',
      };
      
      // Only add cardBank if a bank is selected and has valid data
      if (selectedCardBank != null && selectedCardBank!.isNotEmpty) {
        cardData['cardBank'] = {
          'account_no': selectedCardBank!['account_no']?.toString() ?? '123456',
          'account_type': selectedCardBank!['account_type']?.toString() ?? 'Saving',
          'bank_code': selectedCardBank!['bank_code']?.toString() ?? 'BOC',
          'bank_name': selectedCardBank!['bank_name']?.toString() ?? 'BOC',
          'branch': selectedCardBank!['branch']?.toString() ?? 'Kurunegala',
          'created_at': selectedCardBank!['created_at']?.toString() ?? '2025-04-07T11:35:51.000000Z',
          'id': selectedCardBank!['id'] ?? 1,
          'updated_at': selectedCardBank!['updated_at']?.toString() ?? '2025-04-07T11:35:51.000000Z',
        };
      } else {
        // Provide a default cardBank structure to avoid null
        cardData['cardBank'] = {
          'account_no': '123456',
          'account_type': 'Saving',
          'bank_code': 'BOC',
          'bank_name': 'Bank of Ceylon',
          'branch': 'Kurunegala',
          'created_at': '2025-04-07T11:35:51.000000Z',
          'id': 1,
          'updated_at': '2025-04-07T11:35:51.000000Z',
        };
      }
    }
    
    Map<String, dynamic> creditData = {};
    if (creditUsed > 0) {
      creditData = {
        'amount': creditUsed.toStringAsFixed(2),
        'customer_id': widget.selectedCustomer?.id?.toString() ?? "",
      };
    }
    
    // FIXED: Ensure all payment method objects have proper structure
    return {
      'advancePaymentApplied': 0,
      'bank': bankTransferPaid > 0 ? bankData : {
        'amount': "",
        'code': "",
        'branch': "",
        'user_name': "",
        'user_id': "",
      },
      'card': cardPaid > 0 ? cardData : {
        'card_no': "",
        'cardAmount': "",
        'cardBank': {},  // Empty object instead of null
        'cardType': "",
      },
      'cash': cashPaid > 0 ? cashPaid.toStringAsFixed(2) : "",
      'cheque': {
        'amount': "",
        'bank': "",
        'chequeDate': "",
        'chequeNo': "",
      },
      'credit': creditUsed > 0 ? creditUsed.toStringAsFixed(2) : "",
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'metadata': metadata,
      'overBal': "",
      'type': 2,
    };
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildBankDropdownSection(String type) {
    if (!_initialLoadAttempted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const CircularProgressIndicator(color: Color(0xFF1A3C34)),
            const SizedBox(height: 8),
            Text(
              'Loading banks...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    if (_loadingBanks) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const CircularProgressIndicator(color: Color(0xFF1A3C34)),
            const SizedBox(height: 8),
            Text(
              'Loading banks...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    if (_bankLoadError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red[800], size: 32),
            const SizedBox(height: 8),
            Text(
              _bankLoadError!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.red[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _retryBankLoad,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3C34),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }
    
    if (banks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No banks available',
          style: GoogleFonts.poppins(color: Colors.grey[600]),
        ),
      );
    }
    
    return _buildBankDropdown(
      value: type == 'transfer' ? selectedBankTransferBank : selectedCardBank,
      onChanged: (Map<String, dynamic>? newValue) {
        setState(() {
          if (type == 'transfer') {
            selectedBankTransferBank = newValue;
          } else {
            selectedCardBank = newValue;
          }
        });
      },
      label: type == 'transfer' ? 'Select Bank for Transfer' : 'Select Bank for Card',
    );
  }
  
  Widget _buildBankDropdown({
    required Map<String, dynamic>? value,
    required Function(Map<String, dynamic>?) onChanged,
    required String label,
  }) {
    return DropdownButtonFormField<Map<String, dynamic>>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: banks.map<DropdownMenuItem<Map<String, dynamic>>>((Map<String, dynamic> bank) {
        final String displayName = bank['bank_name'] ??
                                 bank['bank_code'] ??
                                 bank['name'] ??
                                 'Unknown Bank';
        return DropdownMenuItem<Map<String, dynamic>>(
          value: bank,
          child: Text(
            displayName,
            style: GoogleFonts.poppins(),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A3C34),
        elevation: 2,
        title: Text(
          widget.isDueTable ? 'PAY DUE TABLE' : 'PAYMENT',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop({'success': false, 'invoiceNumber': null}),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildPaymentSummaryRow("Invoice Amount", _fmt(widget.netAmount), isBold: true),
                    _buildPaymentSummaryRow("Total Paid", _fmt(totalPaid)),
                    _buildPaymentSummaryRow(
                      "Remaining Balance",
                      _fmt(remainingBalance),
                      isBold: true,
                      isNegative: remainingBalance < 0
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            Container(
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: primaryColor,
                labelColor: primaryColor,
                unselectedLabelColor: Colors.grey[600],
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
                tabs: const [
                  Tab(text: 'Cash'),
                  Tab(text: 'Bank'),
                  Tab(text: 'Credit'),
                  Tab(text: 'Card'),
                ],
              ),
            ),
            
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _cashAmountController,
                          decoration: InputDecoration(
                            labelText: 'Cash Amount',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            hintText: 'Enter cash amount',
                            suffixText: 'LKR',
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) => _updatePaymentAmount('Cash', value),
                        ),
                      ],
                    ),
                  ),
                  
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _bankTransferAmountController,
                          decoration: InputDecoration(
                            labelText: 'Transfer Amount',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            hintText: 'Enter transfer amount',
                            suffixText: 'LKR',
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) => _updatePaymentAmount('Bank Transfer', value),
                        ),
                        const SizedBox(height: 12),
                        _buildBankDropdownSection('transfer'),
                      ],
                    ),
                  ),
                  
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (widget.selectedCustomer == null)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.warning_amber, color: Colors.red[800], size: 32),
                                const SizedBox(height: 8),
                                Text(
                                  'Please select a customer to use Credit payment.',
                                  style: TextStyle(
                                    color: Colors.red[800],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "Available Credit: Rs. 10000.00",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _creditAmountController,
                                decoration: InputDecoration(
                                  labelText: 'Credit Amount to Use',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  hintText: 'Enter credit amount',
                                  suffixText: 'LKR',
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                onChanged: (value) => _updatePaymentAmount('Credit', value),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Card Amount field - will auto-fill with remaining balance
                        TextField(
                          controller: _cardAmountController,
                          decoration: InputDecoration(
                            labelText: 'Card Amount',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            hintText: 'Enter card amount',
                            suffixText: 'LKR',
                            // Add a note about auto-fill
                            helperText: widget.isDueTable 
                                ? 'Auto-filled with due table amount' 
                                : 'Auto-filled with remaining balance',
                            helperStyle: TextStyle(color: primaryColor),
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) => _updatePaymentAmount('Card', value),
                        ),
                        const SizedBox(height: 12),
                        // Bank selection dropdown
                        _buildBankDropdownSection('card'),
                        const SizedBox(height: 12),
                        // Card type dropdown
                        DropdownButtonFormField<String>(
                          value: 'VISA',
                          decoration: InputDecoration(
                            labelText: 'Card Type',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'VISA', child: Text('VISA')),
                            DropdownMenuItem(value: 'MASTER', child: Text('MasterCard')),
                            DropdownMenuItem(value: 'AMEX', child: Text('American Express')),
                            DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                          ],
                          onChanged: (value) {
                            // Handle card type change
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop({'success': false, 'invoiceNumber': null}),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      "CANCEL",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessingPayment ? null : () async {
                      final result = await _processPayment();
                      if (result['success'] == true) {
                        // Do nothing - the dialog will handle navigation
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isProcessingPayment ? Colors.grey : accentColor,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isProcessingPayment
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black87)),
                          )
                        : Text(
                            "PROCESS PAYMENT",
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPaymentSummaryRow(String label, String value, {bool isBold = false, bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isNegative ? Colors.red : primaryColor,
            ),
          ),
        ],
      )
    );
  }
  
  String _fmt(double v) => 'Rs. ${v.toStringAsFixed(2)}';
}