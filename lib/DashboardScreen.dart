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
import 'package:resturant/ApiConstants.dart'; 



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
        Uri.parse(ApiConstants.getFullUrl(ApiConstants.authLogin)),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'referer': ApiConstants.refererHeader,
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
            Uri.parse(ApiConstants.getFullUrl(ApiConstants.getUser)),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'referer': ApiConstants.refererHeader,
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
        Uri.parse(ApiConstants.getFullUrl('${ApiConstants.getCustomers}?page=1&limit=1')),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'referer': ApiConstants.refererHeader,
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
  bool isNewItem;
  String uniqueId;
  String? specialNote;

  CartItem({
    required this.product,
    required this.quantity,
    this.discountType = 'none',
    this.discountValue = 0.0,
    this.isNewItem = true,
    this.specialNote,
  }) : uniqueId = DateTime.now().millisecondsSinceEpoch.toString();

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

  CartItem copyWith({
    Product? product,
    int? quantity,
    String? discountType,
    double? discountValue,
    bool? isNewItem,
    String? specialNote,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      isNewItem: isNewItem ?? this.isNewItem,
      specialNote: specialNote ?? this.specialNote,
    );
  }
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
  String specialNote;

  Table({
    required this.id,
    required this.name,
    required this.serviceCharge,
    this.hasDueOrders = false,
    this.specialNote = '',
  });

  factory Table.fromJson(Map<String, dynamic> json) {
    return Table(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      serviceCharge: double.tryParse(json['service_charge']?.toString() ?? '0') ?? 0.0,
      hasDueOrders: json['has_due_orders'] ?? false,
      specialNote: json['special_note'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'service_charge': serviceCharge,
    'has_due_orders': hasDueOrders,
    'special_note': specialNote,
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
  static const String bot = 'BOT';
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
  
  bool _dataLoaded = false;
  bool _isInitialLoading = true;
  bool _isLoading = false;
  bool _isLoadingProducts = false;

  bool _isSavingInvoice = false;
  
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
  List<BluetoothDevice> _connectedBotDevices = [];
  List<BluetoothConnection> _connections = [];
  bool _isScanning = false;
  bool _isBluetoothEnabled = false;
  int _orderNumber = 1;
  static const String defaultCashierPrinterName = 'Printer001';
  static const String defaultKitchenPrinterName = '4B-2023PA-EE15';
  static const String defaultBotPrinterName = 'BOT-Printer';
  double _serviceAmountOverride = 0.0;
  Map<String, dynamic>? _cartDataForPrinting;
  bool _showListView = true;
  
  bool _isEditingDueTable = false;
  List<Map<String, dynamic>> _existingDueTableItems = [];
  bool _isProcessingDueTablePayment = false;
  
  Map<int, String> _tableSpecialNotes = {};
  
  Map<String, double>? _paymentDataForPrinting;
  String? _kotCode;
  String? _botCode;

  @override
  void initState() {
    super.initState();
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

  int _getTotalConnectedPrinters() {
    return _connectedCashierDevices.length + 
         _connectedKitchenDevices.length + 
         _connectedBotDevices.length;
  }

  Future<void> _loadOrders() async {
    if (!_dataLoaded) return;
    
    setState(() => _isLoading = true);
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse(ApiConstants.getFullUrl(ApiConstants.getOrders)),
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

  bool _hasKitchenItems(List<CartItem> cartItems) {
    return cartItems.any((item) {
      final stockName = item.product.stockName.toLowerCase();
      final productUnit = item.product.unit.toLowerCase();
      final productName = item.product.name.toLowerCase();
      
      final isBarItem = stockName.contains('bar') || 
                       stockName.contains('beverage') ||
                       productUnit.contains('drink') ||
                       productUnit.contains('beverage') ||
                       productUnit.contains('coffee') ||
                       productUnit.contains('tea') ||
                       productUnit.contains('juice') ||
                       productName.contains('coffee') ||
                       productName.contains('tea') ||
                       productName.contains('juice') ||
                       productName.contains('soda') ||
                       productName.contains('water') ||
                       productName.contains('cappuccino') ||
                       productName.contains('latte') ||
                       productName.contains('espresso');
      
      return !isBarItem;
    });
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
        _isEditingDueTable = true;
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
            isNewItem: false,
            specialNote: itemData['special_note'] ?? itemData['note'] ?? '', 
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

    _clearCart();

    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse(ApiConstants.getFullUrl(ApiConstants.tableBillFind)),
        headers: headers,
        body: json.encode({'table_name': _selectedTable!.name}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await _findTableBill(_selectedTable!.name);
        return;
      }
    } catch (e) {
      print('No existing bill for table ${_selectedTable!.name}: $e');
    }

    setState(() {
      _cartItems.clear();
      _currentInvoiceId = null;
      _serviceAmountOverride = 0.0;
      _isEditingDueTable = false;
      _existingDueTableItems.clear();
      
      if (_selectedTable != null) {
        final localNote = _tableSpecialNotes[_selectedTable!.id];
        _selectedTable = Table(
          id: _selectedTable!.id,
          name: _selectedTable!.name,
          serviceCharge: _selectedTable!.serviceCharge,
          hasDueOrders: false,
          specialNote: localNote ?? '',
        );
      }
    });
  }

  Future<String?> _showSaveInvoiceNoteDialog() async {
    final noteController = TextEditingController();
    
    if (_selectedTable != null && _selectedTable!.specialNote.isNotEmpty) {
      noteController.text = _selectedTable!.specialNote;
    }
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          insetPadding: EdgeInsets.all(isLandscape ? 40 : 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: BoxConstraints(
              maxWidth: isLandscape 
                  ? MediaQuery.of(context).size.width * 0.5
                  : MediaQuery.of(context).size.width * 0.8,
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Table ${_selectedTable?.name ?? ''} - Special Note',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: noteController,
                    minLines: 1,
                    maxLines: 5,
                    expands: false,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: 'Enter special note...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
                
                if (isLandscape)
                  Row(
                    children: _buildDialogButtons(noteController),
                  )
                else
                  Column(
                    children: _buildDialogButtons(noteController),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildDialogButtons(TextEditingController noteController) {
    return [
      Expanded(
        child: TextButton(
          onPressed: () => Navigator.pop(context, null),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ),
      ),
      const SizedBox(width: 12, height: 12),
      Expanded(
        child: ElevatedButton(
          onPressed: () {
            final note = noteController.text.trim();
            Navigator.pop(context, note);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(
            'OK',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ),
      ),
    ];
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
      BluetoothDevice? botPrinter;
    
      for (var device in bondedDevices) {
        if (device.name == defaultCashierPrinterName) {
          cashierPrinter = device;
        } else if (device.name == defaultKitchenPrinterName) {
          kitchenPrinter = device;
        } else if (device.name == defaultBotPrinterName) {
          botPrinter = device;
        }
      }
    
      if (cashierPrinter != null) {
        await _connectToDevice(cashierPrinter, PrinterType.cashier, isAutoConnect: true);
      }
    
      if (kitchenPrinter != null) {
        await _connectToDevice(kitchenPrinter, PrinterType.kitchen, isAutoConnect: true);
      }
      
      if (botPrinter != null) {
        await _connectToDevice(botPrinter, PrinterType.bot, isAutoConnect: true);
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
    } else if (printerType == PrinterType.kitchen) {
      isAlreadyConnected = _connectedKitchenDevices.any((d) => d.address == device.address);
    } else if (printerType == PrinterType.bot) {
      isAlreadyConnected = _connectedBotDevices.any((d) => d.address == device.address);
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
          _connectedBotDevices.removeWhere((d) => d.address == device.address);
        });
        if (!isAutoConnect) {
          _showMessage('${device.name} disconnected');
        }
      });

      setState(() {
        _connections.add(connection);
        if (printerType == PrinterType.cashier) {
          _connectedCashierDevices.add(device);
        } else if (printerType == PrinterType.kitchen) {
          _connectedKitchenDevices.add(device);
        } else if (printerType == PrinterType.bot) {
          _connectedBotDevices.add(device);
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
      
      int botIndex = _connections.indexOf(connection) - _connectedCashierDevices.length - _connectedKitchenDevices.length;
      if (botIndex >= 0 && botIndex < _connectedBotDevices.length) {
        return _connectedBotDevices[botIndex];
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
    } else if (_connectedBotDevices.any((d) => d.address == device.address)) {
      return PrinterType.bot;
    }
    return 'UNKNOWN';
  }

  Future<void> _disconnectDevice(BluetoothDevice device) async {
    try {
      final String printerType = _getPrinterTypeForDevice(device);
      List<BluetoothDevice> targetList;
      
      if (printerType == PrinterType.cashier) {
        targetList = _connectedCashierDevices;
      } else if (printerType == PrinterType.kitchen) {
        targetList = _connectedKitchenDevices;
      } else {
        targetList = _connectedBotDevices;
      }
        
      final index = targetList.indexWhere((d) => d.address == device.address);
      if (index >= 0) {
        int connectionIndex;
        if (printerType == PrinterType.cashier) {
          connectionIndex = index;
        } else if (printerType == PrinterType.kitchen) {
          connectionIndex = _connectedCashierDevices.length + index;
        } else {
          connectionIndex = _connectedCashierDevices.length + _connectedKitchenDevices.length + index;
        }
          
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
      _connectedBotDevices.clear();
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
    bool isBotPrint = cartData['isBotPrint'] ?? false;
    String? kotCode = cartData['kotCode'];
    String? botCode = cartData['botCode'];

    
    Map<String, double>? paymentBreakdown = cartData['paymentBreakdown'];
    double cashPaid = paymentBreakdown?['cash'] ?? 0.0;
    double bankPaid = paymentBreakdown?['bank'] ?? 0.0;
    double cardPaid = paymentBreakdown?['card'] ?? 0.0;
    double creditPaid = paymentBreakdown?['credit'] ?? 0.0;
    double totalPaid = cashPaid + bankPaid + cardPaid + creditPaid;
    double remainingBalance = netAmount - totalPaid;
    double cashChange = cashPaid > 0 ? cashPaid - (netAmount - bankPaid - cardPaid - creditPaid) : 0.0;
    if (cashChange < 0) cashChange = 0.0;

    if (printerType == PrinterType.cashier) {
      bytes += generator.text(
        'KAFENIO COLOMBO',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
        ),
      );

      bytes += generator.text(
        'NO-32, Hospital Street, Colombo 1',
        styles: const PosStyles(
          align: PosAlign.center,
        ),
      );

      bytes += generator.text(
        'Tel: 0712901901',
        styles: const PosStyles(
          align: PosAlign.center,
        ),
      );

      bytes += generator.hr();

      if (isBillCopy) {
        bytes += generator.text(
          '*** BILL COPY ***',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            reverse: true,
          ),
        );
        bytes += generator.hr();
      }

      bytes += generator.text(
        'Invoice No: ${invoiceNumber ?? 'INV-${DateTime.now().millisecondsSinceEpoch}'}',
        styles: const PosStyles(
          align: PosAlign.left,
          bold: true,
        ),
      );
      
      bytes += generator.text(
        'Cashier: POS User',
        styles: const PosStyles(
          align: PosAlign.left,
        ),
      );
      
      bytes += generator.text(
        'Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
        styles: const PosStyles(
          align: PosAlign.right,
        ),
      );

      bytes += generator.text(
        'Time: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
        styles: const PosStyles(
          align: PosAlign.right,
        ),
      );

      if (selectedCustomer != null) {
        bytes += generator.text(
          'Customer: ${selectedCustomer.name}',
          styles: const PosStyles(
            align: PosAlign.left,
          ),
        );
      }

      if (selectedTable != null) {
        bytes += generator.text(
          'Table: ${selectedTable.name}',
          styles: const PosStyles(
            align: PosAlign.left,
          ),
        );
        if (selectedTable!.specialNote.isNotEmpty) {
          bytes += generator.text(
            'Note: ${selectedTable!.specialNote}',
            styles: const PosStyles(
              align: PosAlign.left,
              fontType: PosFontType.fontB,
            ),
          );
        }
      }

      bytes += generator.text(
        'Order Type: ${selectedOrderType.displayName}',
        styles: const PosStyles(
          align: PosAlign.left,
        ),
      );

      bytes += generator.hr(ch: '-');

      bytes += generator.row([
        PosColumn(
          text: 'Qty',
          width: 2,
          styles: const PosStyles(
            bold: true,
          ),
        ),
        PosColumn(
          text: 'Unit Price',
          width: 3,
          styles: const PosStyles(
            bold: true,
            align: PosAlign.center,
          ),
        ),
        PosColumn(
          text: 'Dis',
          width: 3,
          styles: const PosStyles(
            bold: true,
            align: PosAlign.center,
          ),
        ),
        PosColumn(
          text: 'Amount',
          width: 4,
          styles: const PosStyles(
            bold: true,
            align: PosAlign.right,
          ),
        ),
      ]);

      bytes += generator.hr(ch: '-');

      for (var item in cartItems) {
        final price = item.getPriceByOrderType(selectedOrderType);
        final total = item.getTotalPrice(selectedOrderType);
        final itemDiscount = 0.00;

        String itemName = item.product.name.toUpperCase();
        
        if (item.specialNote != null && item.specialNote!.isNotEmpty) {
          itemName = '$itemName (${item.specialNote})';
        }
        
        bytes += generator.text(
          itemName,
          styles: const PosStyles(
            align: PosAlign.left,
          ),
        );

        bytes += generator.row([
          PosColumn(
            text: item.quantity.toString(),
            width: 2,
            styles: const PosStyles(
              align: PosAlign.left,
            ),
          ),
          PosColumn(
            text: price.toStringAsFixed(2),
            width: 3,
            styles: const PosStyles(
              align: PosAlign.center,
            ),
          ),
          PosColumn(
            text: itemDiscount.toStringAsFixed(2),
            width: 3,
            styles: const PosStyles(
              align: PosAlign.center,
            ),
          ),
          PosColumn(
            text: total.toStringAsFixed(2),
            width: 4,
            styles: const PosStyles(
              align: PosAlign.right,
            ),
          ),
        ]);
      }

      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(
          text: 'Gross Amount',
          width: 7,
          styles: const PosStyles(
          ),
        ),
        PosColumn(
          text: totalSubtotal.toStringAsFixed(2),
          width: 5,
          styles: const PosStyles(
            align: PosAlign.right,
          ),
        ),
      ]);

      if (globalDiscountValue > 0) {
        bytes += generator.row([
          PosColumn(
            text: 'Discount (${discountPercentage.toStringAsFixed(0)}%)',
            width: 7,
            styles: const PosStyles(
            ),
          ),
          PosColumn(
            text: '-${globalDiscountValue.toStringAsFixed(2)}',
            width: 5,
            styles: const PosStyles(
              align: PosAlign.right,
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
            ),
          ),
          PosColumn(
            text: serviceAmount.toStringAsFixed(2),
            width: 5,
            styles: const PosStyles(
              align: PosAlign.right,
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
          ),
        ),
        PosColumn(
          text: netAmount.toStringAsFixed(2),
          width: 5,
          styles: const PosStyles(
            bold: true,
            align: PosAlign.right,
          ),
        ),
      ]);

      if (paymentBreakdown != null) {
       
      
        bytes += generator.hr(ch: '-');
        
        if (cashPaid > 0) {
          bytes += generator.row([
            PosColumn(
              text: 'Cash Payment',
              width: 7,
              styles: const PosStyles(),
            ),
            PosColumn(
              text: cashPaid.toStringAsFixed(2),
              width: 5,
              styles: const PosStyles(
                align: PosAlign.right,
              ),
            ),
          ]);
          
        
        }
        
        if (bankPaid > 0) {
          bytes += generator.row([
            PosColumn(
              text: 'Bank Transfer',
              width: 7,
              styles: const PosStyles(),
            ),
            PosColumn(
              text: bankPaid.toStringAsFixed(2),
              width: 5,
              styles: const PosStyles(
                align: PosAlign.right,
              ),
            ),
          ]);
        }
        
        if (cardPaid > 0) {
          bytes += generator.row([
            PosColumn(
              text: 'Card Payment',
              width: 7,
              styles: const PosStyles(),
            ),
            PosColumn(
              text: cardPaid.toStringAsFixed(2),
              width: 5,
              styles: const PosStyles(
                align: PosAlign.right,
              ),
            ),
          ]);
        }
        
        if (creditPaid > 0) {
          bytes += generator.row([
            PosColumn(
              text: 'Credit Used',
              width: 7,
              styles: const PosStyles(),
            ),
            PosColumn(
              text: creditPaid.toStringAsFixed(2),
              width: 5,
              styles: const PosStyles(
                align: PosAlign.right,
              ),
            ),
          ]);
        }
        
        bytes += generator.hr();
        
        bytes += generator.row([
          PosColumn(
            text: 'TOTAL PAID',
            width: 7,
            styles: const PosStyles(
              bold: true,
            ),
          ),
          PosColumn(
            text: totalPaid.toStringAsFixed(2),
            width: 5,
            styles: const PosStyles(
              bold: true,
              align: PosAlign.right,
            ),
          ),
        ]);
        
        if (remainingBalance != 0) {
          bytes += generator.row([
            PosColumn(
              text: 'REMAINING BALANCE',
              width: 7,
              styles: const PosStyles(
                bold: true,
              ),
            ),
            PosColumn(
              text: remainingBalance.toStringAsFixed(2),
              width: 5,
              styles: const PosStyles(
                bold: true,
                align: PosAlign.right,
              
              ),
            ),
          ]);
        }
      }

      bytes += generator.hr();

      if (isBillCopy) {
        bytes += generator.text(
          '*** BILL COPY - NOT ORIGINAL ***',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
          ),
        );
        bytes += generator.hr();
      }

      bytes += generator.text(
        'THANK YOU, COME AGAIN',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );

      bytes += generator.text(
        'Software By (e) SLT Cloud POS',
        styles: const PosStyles(
          align: PosAlign.center,
        ),
      );

      bytes += generator.text(
        '0252264723 | 0702967270',
        styles: const PosStyles(
          align: PosAlign.center,
        ),
      );

      bytes += generator.text(
        'www.posmasters.lk',
        styles: const PosStyles(
          align: PosAlign.center,
        ),
      );
    } else if (printerType == PrinterType.kitchen) {
      if (kotCode != null && kotCode.isNotEmpty) {
        bytes += generator.text(
          'KOT - $kotCode',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size3,
            width: PosTextSize.size2,
          ),
        );
      }
  
      if (isBillCopy) {
        bytes += generator.text(
          '*** BILL COPY ***',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            reverse: true,
            height: PosTextSize.size2,
          ),
        );
      }
  
      bytes += generator.text(
        'Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
        ),
      );

      bytes += generator.text(
        'Time: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
        ),
      );
  
      if (selectedTable != null) {
        bytes += generator.text(
          'Table: ${selectedTable.name}',
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
          ),
        );
        if (selectedTable!.specialNote.isNotEmpty) {
          bytes += generator.text(
            'Note: ${selectedTable!.specialNote}',
            styles: const PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size2,
            ),
          );
        }
      }

      bytes += generator.hr();
  
      final itemsToPrint = cartData['onlyNewItems'] == true 
          ? cartItems.where((item) => item.isNewItem).toList()
          : cartItems;
  
      final kitchenItems = itemsToPrint.where((item) {
        final stockName = item.product.stockName.toLowerCase();
        final productUnit = item.product.unit.toLowerCase();
        final productName = item.product.name.toLowerCase();
        
        final isBarItem = stockName.contains('bar') || 
                         stockName.contains('beverage') ||
                         productUnit.contains('drink') ||
                         productUnit.contains('beverage') ||
                         productUnit.contains('coffee') ||
                         productUnit.contains('tea') ||
                         productUnit.contains('juice') ||
                         productName.contains('coffee') ||
                         productName.contains('tea') ||
                         productName.contains('juice') ||
                         productName.contains('soda') ||
                         productName.contains('water') ||
                         productName.contains('cappuccino') ||
                         productName.contains('latte') ||
                         productName.contains('espresso');
        
        return !isBarItem;
      }).toList();

      if (kitchenItems.isEmpty) {
        bytes += generator.text(
          'No kitchen items in this order',
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
          ),
        );
      } else {
        bytes += generator.text(
          'KITCHEN ITEMS:',
          styles: const PosStyles(
            bold: true,
            align: PosAlign.left,
            height: PosTextSize.size2,
          ),
        );
        
        bytes += generator.text(
          'Item'.padRight(45) + 'Qty',
          styles: const PosStyles(
            bold: true,
            align: PosAlign.left,
            height: PosTextSize.size2,
          ),
        );
        
        bytes += generator.hr(ch: '-');
        
        for (var item in kitchenItems) {
          String itemName = item.product.name;
          String quantity = 'x${item.quantity.toString()}';
          
          bytes += generator.text(
            itemName.padRight(45) + quantity,
            styles: const PosStyles(
              align: PosAlign.left,
              height: PosTextSize.size2,
            ),
          );
          
          if (item.specialNote != null && item.specialNote!.isNotEmpty) {
            bytes += generator.text(
              'Note: ${item.specialNote}',
              styles: const PosStyles(
                align: PosAlign.left,
                height: PosTextSize.size1,
              ),
            );
          }
          
          if (item.product.unit.toLowerCase().contains('main') ||
              item.product.name.toLowerCase().contains('main')) {
            bytes += generator.text(
              ' - Please prepare fresh',
              styles: const PosStyles(
                align: PosAlign.left,
                height: PosTextSize.size1,
              ),
            );
          }
        }
      }

      bytes += generator.hr();
      bytes += generator.feed(1);
      bytes += generator.text(
        '--- END OF KOT ---',
        styles: const PosStyles(
          align: PosAlign.center,                           
          height: PosTextSize.size2,
        ),
      );
    } else if (printerType == PrinterType.bot) {
      if (botCode != null && botCode.isNotEmpty) {
        bytes += generator.text(
          'BOT - $botCode',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size3,
            width: PosTextSize.size2,
          ),
        );
      }
  
      if (isBillCopy) {
        bytes += generator.text(
          '*** BILL COPY ***',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            reverse: true,
            height: PosTextSize.size2,
          ),
        );
      }
  
      bytes += generator.text(
        'Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
        ),
      );

      bytes += generator.text(
        'Time: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
        ),
      );
  
      if (selectedTable != null) {
        bytes += generator.text(
          'Table: ${selectedTable.name}',
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
          ),
        );
        if (selectedTable!.specialNote.isNotEmpty) {
          bytes += generator.text(
            'Note: ${selectedTable!.specialNote}',
            styles: const PosStyles(
              align: PosAlign.center,
              height: PosTextSize.size2,
            ),
          );
        }
      }

      bytes += generator.hr();
  
      final itemsToPrint = cartData['onlyNewItems'] == true 
          ? cartItems.where((item) => item.isNewItem).toList()
          : cartItems;
  
      final allItems = itemsToPrint;

      if (allItems.isEmpty) {
        bytes += generator.text(
          'No items in this order',
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
          ),
        );
      } else {
        bytes += generator.text(
          'BAR/BEVERAGE & KITCHEN ITEMS:',
          styles: const PosStyles(
            bold: true,
            align: PosAlign.left,
            height: PosTextSize.size2,
          ),
        );
        
        bytes += generator.text(
          'Item'.padRight(45) + 'Qty',
          styles: const PosStyles(
            bold: true,
            align: PosAlign.left,
            height: PosTextSize.size2,
          ),
        );
        
        bytes += generator.hr(ch: '-');
        
        final barItems = allItems.where((item) {
          final stockName = item.product.stockName.toLowerCase();
          final productUnit = item.product.unit.toLowerCase();
          final productName = item.product.name.toLowerCase();
          
          return stockName.contains('bar') || 
                 stockName.contains('beverage') ||
                 productUnit.contains('drink') ||
                 productUnit.contains('beverage') ||
                 productUnit.contains('coffee') ||
                 productUnit.contains('tea') ||
                 productUnit.contains('juice') ||
                 productName.contains('coffee') ||
                 productName.contains('tea') ||
                 productName.contains('juice') ||
                 productName.contains('soda') ||
                 productName.contains('water') ||
                 productName.contains('cappuccino') ||
                 productName.contains('latte') ||
                 productName.contains('espresso');
        }).toList();
        
        final kitchenItems = allItems.where((item) {
          final stockName = item.product.stockName.toLowerCase();
          final productUnit = item.product.unit.toLowerCase();
          final productName = item.product.name.toLowerCase();
          
          return !(stockName.contains('bar') || 
                  stockName.contains('beverage') ||
                  productUnit.contains('drink') ||
                  productUnit.contains('beverage') ||
                  productUnit.contains('coffee') ||
                  productUnit.contains('tea') ||
                  productUnit.contains('juice') ||
                  productName.contains('coffee') ||
                  productName.contains('tea') ||
                  productName.contains('juice') ||
                  productName.contains('soda') ||
                  productName.contains('water') ||
                  productName.contains('cappuccino') ||
                  productName.contains('latte') ||
                  productName.contains('espresso'));
        }).toList();
        
        if (barItems.isNotEmpty) {
          bytes += generator.text(
            'BAR/BEVERAGE ITEMS:',
            styles: const PosStyles(
              bold: true,
              align: PosAlign.left,
              height: PosTextSize.size2,
            ),
          );
          
          for (var item in barItems) {
            String itemName = item.product.name;
            String quantity = 'x${item.quantity.toString()}';
            
            bytes += generator.text(
              itemName.padRight(45) + quantity,
              styles: const PosStyles(
                align: PosAlign.left,
                height: PosTextSize.size2,
              ),
            );
            
            if (item.specialNote != null && item.specialNote!.isNotEmpty) {
              bytes += generator.text(
                'Note: ${item.specialNote}',
                styles: const PosStyles(
                  align: PosAlign.left,
                  height: PosTextSize.size1,
                ),
              );
            }
          }
          
          if (kitchenItems.isNotEmpty) {
            bytes += generator.hr(ch: '-');
          }
        }
        
        if (kitchenItems.isNotEmpty) {
          if (barItems.isEmpty) {
            bytes += generator.text(
              'KITCHEN ITEMS:',
              styles: const PosStyles(
                bold: true,
                align: PosAlign.left,
                height: PosTextSize.size2,
              ),
            );
          } else {
            bytes += generator.text(
              'KITCHEN ITEMS:',
              styles: const PosStyles(
                bold: true,
                align: PosAlign.left,
                height: PosTextSize.size2,
              ),
            );
          }
          
          for (var item in kitchenItems) {
            String itemName = item.product.name;
            String quantity = 'x${item.quantity.toString()}';
            
            bytes += generator.text(
              itemName.padRight(45) + quantity,
              styles: const PosStyles(
                align: PosAlign.left,
                height: PosTextSize.size2,
              ),
            );
            
            if (item.specialNote != null && item.specialNote!.isNotEmpty) {
              bytes += generator.text(
                'Note: ${item.specialNote}',
                styles: const PosStyles(
                  align: PosAlign.left,
                  height: PosTextSize.size1,
                ),
              );
            }
            
            if (item.product.unit.toLowerCase().contains('main') ||
                item.product.name.toLowerCase().contains('main')) {
              bytes += generator.text(
                ' - Please prepare fresh',
                styles: const PosStyles(
                  align: PosAlign.left,
                  height: PosTextSize.size1,
                ),
              );
            }
          }
        }
      }

      bytes += generator.hr();
      bytes += generator.feed(1);
      bytes += generator.text(
        '--- END OF BOT ---',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
        ),
      );
    }
  
    bytes += generator.feed(2);
    bytes += generator.cut();
    return bytes;
  }

  Future<void> _printReceipt({bool isBillCopy = false, bool skipKOT = false, bool skipBOT = false}) async {
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
          'kotCode': _kotCode,
        };
      }
      
      if (_paymentDataForPrinting != null) {
        cartData['paymentBreakdown'] = _paymentDataForPrinting;
      }

      final List<int> cashierBytes = await _generateReceipt({...cartData, 'printerType': PrinterType.cashier});
      final List<int> kitchenBytes = await _generateReceipt({...cartData, 'printerType': PrinterType.kitchen, 'kotCode': _kotCode});
      final List<int> botBytes = await _generateReceipt({...cartData, 'printerType': PrinterType.bot, 'kotCode': _kotCode});
    
      for (int i = 0; i < _connectedCashierDevices.length; i++) {
        try {
          _connections[i].output.add(Uint8List.fromList(cashierBytes));
          await _connections[i].output.allSent;
          print('Receipt sent to ${_connectedCashierDevices[i].name}');
        } catch (e) {
          
        }
      }
    
      final hasKitchenItems = _hasKitchenItems(_cartItems);

      if (!isBillCopy && !skipKOT && _connectedKitchenDevices.isNotEmpty && hasKitchenItems) {
        for (int i = 0; i < _connectedKitchenDevices.length; i++) {
          try {
            int connectionIndex = _connectedCashierDevices.length + i;
            _connections[connectionIndex].output.add(Uint8List.fromList(kitchenBytes));
            await _connections[connectionIndex].output.allSent;
            print('KOT sent to ${_connectedKitchenDevices[i].name}');
          } catch (e) {
            _showMessage('Error printing to ${_connectedKitchenDevices[i].name}: $e');
          }
        }
      }
      
      if (!isBillCopy && !skipBOT && _connectedBotDevices.isNotEmpty) {
        for (int i = 0; i < _connectedBotDevices.length; i++) {
          try {
            int connectionIndex = _connectedCashierDevices.length + _connectedKitchenDevices.length + i;
            _connections[connectionIndex].output.add(Uint8List.fromList(botBytes));
            await _connections[connectionIndex].output.allSent;
            print('BOT sent to ${_connectedBotDevices[i].name}');
          } catch (e) {
            _showMessage('Error printing to ${_connectedBotDevices[i].name}: $e');
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

  Future<void> _printKOT({bool onlyNewItems = false, bool printBOT = false}) async {
    final itemsToCheck = onlyNewItems 
        ? _cartItems.where((item) => item.isNewItem).toList()
        : List<CartItem>.from(_cartItems);
  
    if (!printBOT) {
      if (_connectedKitchenDevices.isEmpty) {
        _showMessage('No kitchen printer connected. Cannot print KOT.');
        return;
      }
      
      final hasKitchenItems = _hasKitchenItems(itemsToCheck);
      
      if (!hasKitchenItems) {
        print('No kitchen items to print KOT');
        return;
      }
    } else {
      if (_connectedBotDevices.isEmpty) {
        _showMessage('No BOT printer connected. Cannot print BOT.');
        return;
      }
      
      if (itemsToCheck.isEmpty) {
        print('No items to print BOT');
        return;
      }
    }

    if (itemsToCheck.isEmpty) {
      _showMessage('No items to print');
      return;
    }

    try {
      final cartData = {
        'printerType': printBOT ? PrinterType.bot : PrinterType.kitchen,
        'cartItems': itemsToCheck,
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
        'onlyNewItems': onlyNewItems,
        'isBotPrint': printBOT,
        'kotCode': _kotCode,
      };
    
      final List<int> printerBytes = await _generateReceipt(cartData);
  
      if (printBOT) {
        for (int i = 0; i < _connectedBotDevices.length; i++) {
          try {
            int connectionIndex = _connectedCashierDevices.length + _connectedKitchenDevices.length + i;
            _connections[connectionIndex].output.add(Uint8List.fromList(printerBytes));
            await _connections[connectionIndex].output.allSent;
          } catch (e) {
            _showMessage('Error printing to ${_connectedBotDevices[i].name}: $e');
          }
        }
        
        await _updateStockAfterKOT(onlyNewItems, printBOT: true);
      } else {
        for (int i = 0; i < _connectedKitchenDevices.length; i++) {
          try {
            int connectionIndex = _connectedCashierDevices.length + i;
            _connections[connectionIndex].output.add(Uint8List.fromList(printerBytes));
            await _connections[connectionIndex].output.allSent;
          } catch (e) {
            _showMessage('Error printing to ${_connectedKitchenDevices[i].name}: $e');
          }
        }
        
        await _updateStockAfterKOT(onlyNewItems, printBOT: false);
      }
  
    } catch (e) {
      _showMessage('Error generating ${printBOT ? 'BOT' : 'KOT'}: $e');
    }
  }

  Future<void> _updateStockAfterKOT(bool onlyNewItems, {bool printBOT = false}) async {
    if (_cartItems.isEmpty) return;
  
    try {
      final headers = await _getAuthHeaders();
      
      final itemsToUpdate = onlyNewItems
          ? _cartItems.where((item) => item.isNewItem).toList()
          : _cartItems;
      
      final filteredItems = itemsToUpdate.where((item) {
        if (printBOT) {
          return item.product.unit.toLowerCase().contains('beverage') ||
                 item.product.unit.toLowerCase().contains('drink') ||
                 item.product.unit.toLowerCase().contains('bar');
        } else {
          return !item.product.unit.toLowerCase().contains('beverage') &&
                 !item.product.unit.toLowerCase().contains('drink');
        }
      }).toList();
      
      for (var cartItem in filteredItems) {
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
              Uri.parse(ApiConstants.getFullUrl(ApiConstants.updateLotQuantity)),
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
      
    }
  }

  Future<void> _printDueTableBillCopy(Table table) async {
    if (_connectedCashierDevices.isEmpty) {
      _showMessage('Please connect to a cashier printer first');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      await _findTableBill(table.name);
      
      if (_cartItems.isEmpty) {
        _showMessage('No items found for table ${table.name}');
        return;
      }
      
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
        'kotCode': _kotCode,
      };
      
      final List<int> cashierBytes = await _generateReceipt(cartData);
      
      for (int i = 0; i < _connectedCashierDevices.length; i++) {
        try {
          _connections[i].output.add(Uint8List.fromList(cashierBytes));
          await _connections[i].output.allSent;
        } catch (e) {
          _showMessage('Error printing bill copy: $e');
        }
      }
      
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
      final invoiceHead = invoiceData['data']?['invoice_head'] ?? invoiceData['invoice_head'];
      final items = invoiceData['data']?['items'] ?? invoiceData['items'] ?? [];
      final customer = invoiceData['data']?['customer'] ?? invoiceData['customer'];
      final table = invoiceData['data']?['table'] ?? invoiceData['table'];
      final kotCode = invoiceData['kot_code'] ?? invoiceData['data']?['kot_code'];
      
      if (items.isEmpty) {
        _showMessage('No invoice data to print');
        return;
      }
      
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
          specialNote: item['special_note'] ?? item['note'] ?? '',
        );
        
        cartItems.add(cartItem);
        totalSubtotal += cartItem.getSubtotal(_selectedOrderType);
      }
      
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
      
      Table? selectedTable;
      if (table != null) {
        selectedTable = Table(
          id: table['id'] ?? 0,
          name: table['name'] ?? '',
          serviceCharge: double.tryParse(table['service_charge']?.toString() ?? '0') ?? 0.0,
          hasDueOrders: false,
          specialNote: table['special_note'] ?? '',
        );
      }
      
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
        'kotCode': kotCode,
      };
      
      final List<int> cashierBytes = await _generateReceipt(cartData);
      
      for (int i = 0; i < _connectedCashierDevices.length; i++) {
        try {
          _connections[i].output.add(Uint8List.fromList(cashierBytes));
          await _connections[i].output.allSent;
        } catch (e) {
          _showMessage('Error printing bill copy: $e');
        }
      }
      
      if (_selectedTable != null && _cartItems.isNotEmpty) {
        _clearCart();
      }
      
    } catch (e) {
      _showMessage('Error generating bill copy: $e');
    }
  }

  Future<void> _payNow() async {
    if (_cartItems.isEmpty) return;

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

    if (!_isEditingDueTable && _connectedKitchenDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Warning: Kitchen printer not connected. KOT will not be printed.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    
    if (!_isEditingDueTable && _connectedBotDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Warning: BOT printer not connected. BOT will not be printed.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      'isDueTable': _isEditingDueTable,
      'kotCode': _kotCode,
    };

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
          'special_note': item.specialNote ?? '',
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
            'special_note': item.specialNote ?? '',
          };
        }).toList(),
        'netAmount': _netAmount.toStringAsFixed(2),
        'order_now_order_info_id': [],
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
          'special_note': _selectedTable!.specialNote,
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
        Uri.parse(ApiConstants.getFullUrl(ApiConstants.processPayment)),
        headers: headers,
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        
        String? invoiceNumber;
        if (responseData['data'] != null && responseData['data']['invoice_head'] != null) {
          invoiceNumber = responseData['data']['invoice_head']['invoice_code'];
        }
        
        String? kotCode = responseData['kot_code'] ?? responseData['data']?['kot_code'];
        String? botCode = responseData['bot_code'] ?? responseData['data']?['bot_code'];
        
        if (_cartDataForPrinting != null) {
          _cartDataForPrinting!['invoiceNumber'] = invoiceNumber;
          _cartDataForPrinting!['kotCode'] = kotCode;
          _cartDataForPrinting!['botCode'] = botCode;
        }
        
        await _printReceipt(skipKOT: _isEditingDueTable, skipBOT: _isEditingDueTable);
        
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
                    
                    if (_connectedBotDevices.isNotEmpty) ...[
                      const Text('BOT Printers:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ..._connectedBotDevices.map((device) => ListTile(
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
                            final isBotConnected = _connectedBotDevices.any((d) => d.address == device.address);
                            final isConnected = isCashierConnected || isKitchenConnected || isBotConnected;
                          
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
                                      const PopupMenuItem<String>(
                                        value: PrinterType.bot,
                                        child: Text('Connect as BOT Printer'),
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
                        if (_connectedCashierDevices.isNotEmpty || _connectedKitchenDevices.isNotEmpty || _connectedBotDevices.isNotEmpty)
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
    
    final hasKitchenItems = _hasKitchenItems(_cartItems);

    if (!_isEditingDueTable && hasKitchenItems && _connectedKitchenDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Warning: Kitchen printer not connected. KOT will not be printed.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (!_isEditingDueTable && _cartItems.isNotEmpty && _connectedBotDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Warning: BOT printer not connected. BOT will not be printed.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    
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
      'isDueTable': _isEditingDueTable,
      'kotCode': _kotCode,
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
          isDueTable: _isEditingDueTable,
        ),
      ),
    );
    
    if (result != null && result['success'] == true) {
      try {
        String? invoiceNumber = result['invoiceNumber'];
        
        if (_cartDataForPrinting != null && invoiceNumber != null) {
          _cartDataForPrinting!['invoiceNumber'] = invoiceNumber;
        }
        
        if (result['paymentData'] != null) {
          _paymentDataForPrinting = Map<String, double>.from(result['paymentData']);
        }
        
        await _printReceipt(skipKOT: _isEditingDueTable, skipBOT: _isEditingDueTable);
        
        _clearCart();
        await _refreshDueTables();
        _cartDataForPrinting = null;
        _paymentDataForPrinting = null;
        
      } catch (e) {
        _showMessage('Payment successful but printing failed: $e');
        
        _clearCart();
        _cartDataForPrinting = null;
        _paymentDataForPrinting = null;
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
                specialNote: '',
              );
            }
            return table;
          }).toList();
          
          _filteredTables = _tables;
        });
        
        _selectedTable = null;
      }
      
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
      'referer': ApiConstants.refererHeader,
    };
  }

  Future<void> _loadCategories() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse(ApiConstants.getFullUrl(ApiConstants.getCategories)),
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
        Uri.parse('${ApiConstants.getFullUrl(ApiConstants.getProducts)}?type=All'),
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
        Uri.parse(ApiConstants.getFullUrl(ApiConstants.getTables)),
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
  
  Future<List<Table>> _loadDueTablesFromAPI() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse(ApiConstants.getFullUrl(ApiConstants.getDueTables)),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'Success' && data['data'] != null) {
          List<dynamic> tablesData = data['data'];
          List<Table> dueTables = [];
          
          for (var tableData in tablesData) {
            Table table = Table.fromJson(tableData);
            
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

  Future<void> _loadDueTableItems(Table table) async {
    setState(() => _isLoading = true);
  
    try {
      _clearCart();
      
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConstants.getFullUrl(ApiConstants.getDueTableItems)}/${table.id}'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'Success' && data['data'] != null) {
          final itemsData = data['data'];
          
          List<CartItem> tempCartItems = [];
          int loadedItems = 0;
          
          for (var itemData in itemsData) {
            try {
              var productId = itemData['product_id'] ?? itemData['tbl_product_id'];
              
              Product? product = _products.firstWhere(
                (p) => p.id == productId,
                orElse: () {
                  return Product(
                    id: productId ?? 0,
                    name: itemData['name'] ?? 'Unknown Product',
                    unit: itemData['unit'] ?? '',
                    barCode: itemData['bar_code'] ?? '',
                    tblStockId: itemData['tbl_stock_id'] ?? 0,
                    tblCategoryId: itemData['tbl_category_id'] ?? 0,
                    productImage: null,
                    stockName: itemData['stock']?['stock_name'] ?? itemData['stock_name'] ?? 'Main',
                    availableQuantity: 9999,
                    price: double.tryParse(itemData['price']?.toString() ?? '0') ?? 0.0,
                    cost: double.tryParse(itemData['cost']?.toString() ?? '0') ?? 0.0,
                    wsPrice: double.tryParse(itemData['ws_price']?.toString() ?? itemData['price']?.toString() ?? '0') ?? 0.0,
                    lotNumber: itemData['lot_id']?.toString() ?? itemData['lot_number'] ?? '',
                    expiryDate: itemData['ex_date'] ?? itemData['expiry_date'],
                    lotsqty: [],
                  );
                },
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

              tempCartItems.add(CartItem(
                product: product,
                quantity: quantity,
                discountType: discountType,
                discountValue: discountValue,
                isNewItem: false,
                specialNote: itemData['special_note'] ?? itemData['note'] ?? '',
              ));
              loadedItems++;
            } catch (e) {
              print('Error loading due table item: $e');
            }
          }
          
          try {
            final billResponse = await http.post(
              Uri.parse(ApiConstants.getFullUrl(ApiConstants.tableBillFind)),
              headers: headers,
              body: json.encode({'table_name': table.name}),
            ).timeout(const Duration(seconds: 5));
            
            if (billResponse.statusCode == 200) {
              final billData = json.decode(billResponse.body);
              final invB = billData['invB'] ?? billData['items'] ?? [];
              
              for (var item in invB) {
                var productId = item['product_id'] ?? item['tbl_product_id'];
                
                if (!tempCartItems.any((cartItem) => cartItem.product.id == productId)) {
                  try {
                    Product? product = _products.firstWhere(
                      (p) => p.id == productId,
                      orElse: () => Product(
                        id: productId ?? 0,
                        name: item['name'] ?? 'Unknown Product',
                        unit: item['unit'] ?? '',
                        barCode: item['bar_code'] ?? '',
                        tblStockId: item['tbl_stock_id'] ?? 0,
                        tblCategoryId: item['tbl_category_id'] ?? 0,
                        productImage: null,
                        stockName: item['stock']?['stock_name'] ?? 'Main',
                        availableQuantity: 9999,
                        price: double.tryParse(item['price']?.toString() ?? '0') ?? 0.0,
                        cost: double.tryParse(item['cost']?.toString() ?? '0') ?? 0.0,
                        wsPrice: double.tryParse(item['ws_price']?.toString() ?? '0') ?? 0.0,
                        lotNumber: item['lot_id']?.toString() ?? '',
                        expiryDate: item['ex_date'],
                        lotsqty: [],
                      ),
                    );

                    final quantity = int.tryParse(item['qty']?.toString() ?? '1') ?? 1;
                    String discountType = item['discount_type'] ?? 'none';
                    double discountValue = double.tryParse(item['discount_value']?.toString() ?? '0') ?? 0.0;

                    if (discountType == 'none') {
                      final dis = double.tryParse(item['dis']?.toString() ?? '0') ?? 0.0;
                      final disVal = double.tryParse(item['disVal']?.toString() ?? '0') ?? 0.0;
                      if (dis > 0) {
                        discountType = '%';
                        discountValue = dis;
                      } else if (disVal > 0) {
                        discountType = 'value';
                        discountValue = disVal;
                      }
                    }

                    tempCartItems.add(CartItem(
                      product: product,
                      quantity: quantity,
                      discountType: discountType,
                      discountValue: discountValue,
                      isNewItem: false,
                      specialNote: item['special_note'] ?? item['note'] ?? '',
                    ));
                  } catch (e) {
                    print('Error adding item from table-bill-find: $e');
                  }
                }
              }
            }
          } catch (e) {
            print('Error loading via table-bill-find: $e');
          }
          
          setState(() {
            _cartItems = tempCartItems;
            _isEditingDueTable = true;
            _selectedTable = table;
            _existingDueTableItems = List<Map<String, dynamic>>.from(itemsData);
          });
          
          _updateCartTotals();
          return;
        }
      }
      
      await _findTableBill(table.name);
      
    } catch (e) {
      _showMessage('Error loading due table items: $e');
      await _findTableBill(table.name);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleTableSelection(Table table) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator.adaptive(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            SizedBox(height: 16),
            Text(
              'Loading table...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
    
    try {
      setState(() {
        _selectedTable = Table(
          id: table.id,
          name: table.name,
          serviceCharge: table.serviceCharge,
          hasDueOrders: table.hasDueOrders,
          specialNote: table.specialNote,
        );
      });
      
      if (table.hasDueOrders) {
        await _loadDueTableItems(table);
      } else {
        await _loadTableItems();
      }
      
      Navigator.pop(context);
      
    } catch (e) {
      Navigator.pop(context);
      _showMessage('Error loading table: $e');
    }
  }

  Future<void> _loadWaiters() async {
    setState(() => _isLoading = true);
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse(ApiConstants.getFullUrl(ApiConstants.getWaiters)),
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
        Uri.parse(ApiConstants.getFullUrl(ApiConstants.getCustomers)),
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
      
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addCustomer(Customer customer) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse(ApiConstants.getFullUrl(ApiConstants.getCustomers)),
        headers: headers,
        body: json.encode(customer.toJson()),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _loadCustomers();
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

  Future<void> _saveInvoice({bool isDue = false}) async {
    if (_cartItems.isEmpty) {
      return;
    }
    
    if (_isEditingDueTable && _currentInvoiceId != null) {
      await _updateDueTableInvoice();
      return;
    }
    
    final hasKitchenItems = _hasKitchenItems(_cartItems);
    
    if (_connectedKitchenDevices.isEmpty && hasKitchenItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Warning: Kitchen printer not connected. KOT will not be printed.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    
    if (_connectedBotDevices.isEmpty && _cartItems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Warning: BOT printer not connected. BOT will not be printed.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    
    final Table? currentTable = _selectedTable;
    final List<CartItem> cartItemsToSave = List<CartItem>.from(_cartItems);
    
    final specialNote = await _showSaveInvoiceNoteDialog();
    if (specialNote == null) {
      return;
    }
    
    setState(() {
      _isSavingInvoice = true;
    });
    
    _showLoadingOverlay('Saving Invoice...');
    
    try {
      final headers = await _getAuthHeaders();
      
      String saleType = _selectedTable != null 
          ? 'DINE IN'  
          : 'TAKE AWAY'; 
      
      List<Map<String, dynamic>> items = [];
      
      for (var item in cartItemsToSave) {
        double price = item.getPriceByOrderType(_selectedOrderType);
        double disVal = item.getDiscount(_selectedOrderType);
        double dis = item.discountType == '%' ? item.discountValue : 0.0;
        double total = item.getTotalPrice(_selectedOrderType);
        
        int lotId = 0;
        String? lotNumber;
        
        if (item.product.lotsqty.isNotEmpty) {
          for (var lot in item.product.lotsqty) {
            final qty = int.tryParse(lot['qty']?.toString() ?? '0') ?? 0;
            if (qty > 0) {
              lotId = lot['id'] ?? lot['lot_id'] ?? 0;
              lotNumber = lot['lot_number']?.toString();
              break;
            }
          }
          
          if (lotId == 0) {
            final firstLot = item.product.lotsqty.first;
            lotId = firstLot['id'] ?? firstLot['lot_id'] ?? 1;
            lotNumber = firstLot['lot_number']?.toString();
          }
        } else {
          if (item.product.lotNumber.isNotEmpty) {
            try {
              lotId = int.tryParse(item.product.lotNumber) ?? 1;
              lotNumber = item.product.lotNumber;
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
          'special_note': item.specialNote ?? '',
          'lot_number': lotNumber ?? item.product.lotNumber,
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
        'order_now_order_info_id': [],
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
          'special_note': specialNote,
        };
      }

      final payload = {
        'metadata': metadata,
        'type': 2,
      };

      print('Save Invoice Payload: ${json.encode(payload)}');

      String endpoint = ApiConstants.getFullUrl(ApiConstants.saveInvoice);
      
      final uri = Uri.parse(endpoint).replace(
        queryParameters: {
          'bill_copy': '0',
          'due': isDue ? '1' : '0',
        }
      );

      final response = await http.post(
        uri,
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
        
        String? kotCode = responseData['kot_code'] ?? responseData['data']?['kot_code'];
        String? botCode = responseData['bot_code'] ?? responseData['data']?['bot_code'];
        
        if (kotCode != null) {
          setState(() {
            _kotCode = kotCode;
          });
        }
        
        if (botCode != null) {
          setState(() {
            _botCode = botCode;
          });
        }
        
        final hasKitchenItemsInCart = _hasKitchenItems(cartItemsToSave);

        if (_connectedKitchenDevices.isNotEmpty && hasKitchenItemsInCart) {
          await _printKOT(onlyNewItems: _isEditingDueTable);
        }

        if (_connectedBotDevices.isNotEmpty && cartItemsToSave.isNotEmpty) {
          await _printKOT(onlyNewItems: _isEditingDueTable, printBOT: true);
        }
        
        await _updateStockInDatabaseForSave(cartItemsToSave, headers);
        
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
          'kotCode': kotCode,
          'botCode': botCode,
        };
        
        setState(() {
          for (var cartItem in _cartItems) {
            final product = cartItem.product;
            final productIndex = _products.indexWhere((p) => p.id == product.id);
            if (productIndex != -1) {
              _products[productIndex].availableQuantity -= cartItem.quantity;
              final filteredIndex = _filteredProducts.indexWhere((p) => p.id == product.id);
              if (filteredIndex != -1) {
                _filteredProducts[filteredIndex].availableQuantity -= cartItem.quantity;
              }
            }
          }
          
          _cartItems.clear();
          _discountController.text = '0';
          _currentInvoiceId = null;
          _serviceAmountOverride = 0.0;
          _isEditingDueTable = false;
          _existingDueTableItems.clear();
          _isProcessingDueTablePayment = false;
          _kotCode = null;
          
          if (currentTable != null) {
            _selectedTable = Table(
              id: currentTable.id,
              name: currentTable.name,
              serviceCharge: currentTable.serviceCharge,
              hasDueOrders: false,
              specialNote: specialNote,
            );
            
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
      _dismissLoadingOverlay();
      if (mounted) setState(() {
        _isSavingInvoice = false;
      });
    }
  }

  void _showLoadingOverlay(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator.adaptive(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please wait...',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _dismissLoadingOverlay() {
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _updateDueTableInvoice() async {
    if (_cartItems.isEmpty) {
      return;
    }

    final specialNote = await _showSaveInvoiceNoteDialog();
    if (specialNote == null) {
      return;
    }
    
    final Table? currentTable = _selectedTable;
    
    setState(() {
      _isSavingInvoice = true;
    });
    
    _showLoadingOverlay('Updating Due Table...');
    
    try {
      final headers = await _getAuthHeaders();
      
      if (_currentInvoiceId == null) {
        throw Exception('No invoice ID found for due table update');
      }
      
      String saleType = 'DINE IN';
      
      List<Map<String, dynamic>> items = [];
      
      for (var cartItem in _cartItems) {
        double price = cartItem.getPriceByOrderType(_selectedOrderType);
        double disVal = cartItem.getDiscount(_selectedOrderType);
        double dis = cartItem.discountType == '%' ? cartItem.discountValue : 0.0;
        double total = cartItem.getTotalPrice(_selectedOrderType);
        
        int lotId = 0;
        String lotNumber = cartItem.product.lotNumber;
        
        if (cartItem.product.lotsqty.isNotEmpty) {
          for (var lot in cartItem.product.lotsqty) {
            final qty = int.tryParse(lot['qty']?.toString() ?? '0') ?? 0;
            if (qty > 0) {
              lotId = lot['id'] ?? lot['lot_id'] ?? 0;
              lotNumber = lot['lot_number']?.toString() ?? '';
              break;
            }
          }
          
          if (lotId == 0 && cartItem.product.lotsqty.isNotEmpty) {
            final firstLot = cartItem.product.lotsqty.first;
            lotId = firstLot['id'] ?? firstLot['lot_id'] ?? 1;
            lotNumber = firstLot['lot_number']?.toString() ?? '';
          }
        } else {
          if (cartItem.product.lotNumber.isNotEmpty) {
            try {
              lotId = int.tryParse(cartItem.product.lotNumber) ?? 1;
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
        
        Map<String, dynamic> itemData = {
          'aQty': cartItem.product.availableQuantity + cartItem.quantity,
          'bar_code': cartItem.product.barCode,
          'cost': cartItem.product.cost,
          'dis': dis,
          'disVal': disVal,
          'exp': cartItem.product.expiryDate,
          'lot_id': lotId,
          'lot_index': 0,
          'name': cartItem.product.name,
          'price': price,
          'qty': cartItem.quantity,
          's_name': null,
          'sid': cartItem.product.tblStockId,
          'stock': cartItem.product.stockName,
          'total': total.toStringAsFixed(2),
          'total_discount': disVal.toStringAsFixed(2),
          'unit': cartItem.product.unit,
          'special_note': cartItem.specialNote ?? '',
          'lot_number': lotNumber,
        };
        
        if (!cartItem.isNewItem) {
          final existingItem = _existingDueTableItems.firstWhere(
            (existing) => 
              existing['product_id'] == cartItem.product.id ||
              existing['tbl_product_id'] == cartItem.product.id,
            orElse: () => {},
          );
          
          if (existingItem.isNotEmpty && existingItem['id'] != null) {
            itemData['id'] = existingItem['id'];
          }
        }
        
        items.add(itemData);
      }

      Map<String, dynamic> metadata = {
        'id': _currentInvoiceId,
        'advance_payment': '',
        'bill_copy_issued': 0,
        'billDis': _discountPercentage.toString(),
        'billDisVal': _globalDiscountValue.toStringAsFixed(2),
        'customer': _selectedCustomer != null ? {
          'id': _selectedCustomer!.id ?? 0,
          'name': _selectedCustomer!.name,
          'phone': _selectedCustomer!.phone ?? '',
          'email': _selectedCustomer!.email ?? '',
          'nic': _selectedCustomer!.nic ?? '',
          'address': _selectedCustomer!.address ?? '',
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
        'order_now_order_info_id': [],
        'room_booking': '',
        'saleType': saleType,
        'service_charge': _selectedTable != null ? _serviceAmount.toStringAsFixed(2) : '0.00',
        'services': [],
        'tbl_room_booking_id': '',
        'waiter_id': _selectedWaiter?.id ?? 0,
        'waiter_name': _selectedWaiter?.name ?? '',
      };

      if (currentTable != null) {
        metadata['table_name_id'] = {
          'id': currentTable.id ?? 0,
          'name': currentTable.name,
          'service_charge': currentTable.serviceCharge,
          'special_note': specialNote,
        };
      } else {
        metadata['table_name_id'] = {
          'id': 0,
          'name': '',
          'service_charge': 0.0,
          'special_note': '',
        };
      }

      final payload = {
        'metadata': metadata,
        'type': 2,
      };

      print('Update Due Table Payload: ${json.encode(payload)}');

      String endpoint = '${ApiConstants.getFullUrl(ApiConstants.saveInvoice)}?bill_copy=0&due=1';

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
        }
        
        String? kotCode = responseData['kot_code'] ?? responseData['data']?['kot_code'];
        String? botCode = responseData['bot_code'] ?? responseData['data']?['bot_code'];
        
        if (kotCode != null) {
          setState(() {
            _kotCode = kotCode;
          });
        }
        
        if (botCode != null) {
          setState(() {
            _botCode = botCode;
          });
        }
        
        final newKitchenItems = _cartItems.where((item) => item.isNewItem).toList();
        final hasNewKitchenItems = _hasKitchenItems(newKitchenItems);

        if (_connectedKitchenDevices.isNotEmpty && hasNewKitchenItems) {
          await _printKOT(onlyNewItems: true);
        }

        if (_connectedBotDevices.isNotEmpty && newKitchenItems.isNotEmpty) {
          await _printKOT(onlyNewItems: true, printBOT: true);
        }
        
        await _updateStockInDatabase(newKitchenItems, headers);
        
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
          'kotCode': kotCode,
          'botCode': botCode,
        };
        
        setState(() {
          final newItemsToClear = _cartItems.where((item) => item.isNewItem).toList();
          
          for (var cartItem in newItemsToClear) {
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
          
          _cartItems.clear();
          _discountController.text = '0';
          _serviceAmountOverride = 0.0;
          _isProcessingDueTablePayment = false;
          _kotCode = null;
          _botCode = null;
          
          _cartDataForPrinting = null;
          _isEditingDueTable = false;
          _existingDueTableItems.clear();
          _currentInvoiceId = null;
          
          _updateCartTotals();
          
          if (currentTable != null) {
            _selectedTable = Table(
              id: currentTable.id,
              name: currentTable.name,
              serviceCharge: currentTable.serviceCharge,
              hasDueOrders: false,
              specialNote: specialNote,
            );
            
            _saveLocalTableNote(currentTable.id, specialNote);
          }
        });
        
      } else {
        print('Update Due Table Error: ${response.statusCode} - ${response.body}');
        final errorBody = json.decode(response.body);
        
        String errorMessage = 'Failed to update due table';
        if (errorBody['message'] != null) {
          errorMessage = errorBody['message'];
        } else if (errorBody['error'] != null) {
          errorMessage = errorBody['error'];
        }
        
        throw Exception('$errorMessage (Status: ${response.statusCode})');
      }
    } catch (e) {
      print('Update Due Table Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating due table: ${e.toString().replaceAll('Exception: ', '')}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _dismissLoadingOverlay();
      if (mounted) setState(() {
        _isSavingInvoice = false;
      });
    }
  }

  Future<void> _updateStockInDatabaseForSave(List<CartItem> itemsToUpdate, Map<String, String> headers) async {
    if (itemsToUpdate.isEmpty) return;
    
    try {
      for (var cartItem in itemsToUpdate) {
        final product = cartItem.product;
        
        if (product.lotsqty.isNotEmpty) {
          var selectedLot;
          int lotId = 0;
          
          for (var lot in product.lotsqty) {
            final qty = int.tryParse(lot['qty']?.toString() ?? '0') ?? 0;
            if (qty > 0) {
              selectedLot = lot;
              lotId = lot['id'] ?? lot['lot_id'] ?? 0;
              break;
            }
          }
          
          if (selectedLot == null && product.lotsqty.isNotEmpty) {
            selectedLot = product.lotsqty.first;
            lotId = selectedLot['id'] ?? selectedLot['lot_id'] ?? 0;
          }
          
          if (lotId > 0) {
            final currentQty = int.tryParse(selectedLot['qty']?.toString() ?? '0') ?? 0;
            
            if (currentQty >= cartItem.quantity) {
              final newQty = currentQty - cartItem.quantity;
              
              final response = await http.post(
                Uri.parse(ApiConstants.getFullUrl(ApiConstants.updateLotQuantity)),
                headers: headers,
                body: json.encode({
                  'lot_id': lotId,
                  'qty': newQty,
                }),
              ).timeout(const Duration(seconds: 10));
              
              if (response.statusCode == 200) {
                print('Stock updated for product ${product.name}, lot $lotId: $currentQty -> $newQty');
              } else {
                print('Failed to update stock for product ${product.name}: ${response.statusCode}');
              }
            } else {
              print('Insufficient stock for product ${product.name}: ${currentQty} available, ${cartItem.quantity} requested');
            }
          }
        }
      }
    } catch (e) {
      print('Error updating stock in database for save: $e');
    }
  }

  Future<void> _updateStockInDatabase(List<CartItem> itemsToUpdate, Map<String, String> headers) async {
    if (itemsToUpdate.isEmpty) return;
    
    try {
      for (var cartItem in itemsToUpdate) {
        final product = cartItem.product;
        
        if (product.lotsqty.isNotEmpty) {
          var selectedLot;
          for (var lot in product.lotsqty) {
            final qty = int.tryParse(lot['qty']?.toString() ?? '0') ?? 0;
            if (qty > 0) {
              selectedLot = lot;
              break;
            }
          }
          
          if (selectedLot == null && product.lotsqty.isNotEmpty) {
            selectedLot = product.lotsqty.first;
          }
          
          if (selectedLot != null) {
            final lotId = selectedLot['id'];
            final currentQty = int.tryParse(selectedLot['qty']?.toString() ?? '0') ?? 0;
            
            if (currentQty >= cartItem.quantity) {
              final newQty = currentQty - cartItem.quantity;
              
              final response = await http.post(
                Uri.parse(ApiConstants.getFullUrl(ApiConstants.updateLotQuantity)),
                headers: headers,
                body: json.encode({
                  'lot_id': lotId,
                  'qty': newQty,
                }),
              ).timeout(const Duration(seconds: 10));
              
              if (response.statusCode == 200) {
                print('Stock updated for product ${product.name}, lot $lotId');
              } else {
                print('Failed to update stock for product ${product.name}: ${response.statusCode}');
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error updating stock in database: $e');
    }
  }

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
      await _printReceipt(isBillCopy: true);
      
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

  Future<void> _saveAndPrintBillCopy() async {
    if (_cartItems.isEmpty) {
      return;
    }
    
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
          'special_note': item.specialNote ?? '',
        });
      }

      Map<String, dynamic> metadata = {
        'advance_payment': '',
        'bill_copy_issued': 1,
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
        'order_now_order_info_id': [],
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
          'special_note': _selectedTable!.specialNote,
        };
      }

      final payload = {
        'metadata': metadata,
        'type': 2,
      };

      print('Save Bill Copy Payload: ${json.encode(payload)}');

      final response = await http.post(
        Uri.parse('${ApiConstants.getFullUrl(ApiConstants.saveInvoice)}?bill_copy=1'),
        headers: headers,
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        
        await _printBillCopyFromInvoice(responseData);
        
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
        1,
        'none',
        0.0,
        null,
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
  
    if (existingIndex != null && existingIndex < _cartItems.length) {
      setState(() {
        _cartItems[existingIndex] = CartItem(
          product: product,
          quantity: quantity,
          discountType: discountType,
          discountValue: discountValue,
          isNewItem: _cartItems[existingIndex].isNewItem,
          specialNote: _cartItems[existingIndex].specialNote,
        );
        
        final productIndex = _products.indexWhere((p) => p.id == product.id);
        if (productIndex != -1) {
          final originalQty = _products[productIndex].availableQuantity;
          final previousQty = _cartItems[existingIndex].quantity;
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
          isNewItem: true,
          specialNote: '',
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

  void _removeFromCart(int index) {
    if (index >= 0 && index < _cartItems.length) {
      setState(() {
        final removedItem = _cartItems.removeAt(index);
        
        if (removedItem.isNewItem) {
          final productIndex = _products.indexWhere((p) => p.id == removedItem.product.id);
          if (productIndex != -1) {
            _products[productIndex].availableQuantity += removedItem.quantity;
            
            final filteredIndex = _filteredProducts.indexWhere((p) => p.id == removedItem.product.id);
            if (filteredIndex != -1) {
              _filteredProducts[filteredIndex].availableQuantity += removedItem.quantity;
            }
          }
        }
      });
      _updateCartTotals();
    }
  }

  void _updateCartQuantity(int index, int newQuantity) {
    if (index >= 0 && index < _cartItems.length) {
      final item = _cartItems[index];
      
      if (_isEditingDueTable && !item.isNewItem) {
        return;
      }
      
      final product = item.product;
      
      setState(() {
        if (newQuantity <= 0) {
          _removeFromCart(index);
        } else if (newQuantity <= product.availableQuantity + item.quantity) {
          final difference = newQuantity - item.quantity;
          _cartItems[index] = CartItem(
            product: product,
            quantity: newQuantity,
            discountType: item.discountType,
            discountValue: item.discountValue,
            isNewItem: item.isNewItem,
            specialNote: item.specialNote,
          );
          
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
      });
      _updateCartTotals();
    }
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
    if (_cartItems.isEmpty) {
      return;
    }
  
    _showLoadingOverlay('Clearing Cart...');
  
    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
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
        
        _cartItems.clear();
        _discountController.text = '0';
        _currentInvoiceId = null;
        _serviceAmountOverride = 0.0;
        _isEditingDueTable = false;
        _existingDueTableItems.clear();
        _isProcessingDueTablePayment = false;
        _paymentDataForPrinting = null;
        _kotCode = null;
      });
      
      _dismissLoadingOverlay();
    });
  }

  void _clearEverything() {
    if (_cartItems.isEmpty && 
        _selectedCustomer == null && 
        _selectedTable == null && 
        _selectedWaiter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nothing to clear'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
  
    _showLoadingOverlay('Resetting Everything...');
  
    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
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
        _paymentDataForPrinting = null;
        _kotCode = null;
      });
    
      _dismissLoadingOverlay();
    });
  }

  void _selectFreshTable(Table table) {
    setState(() {
      _clearEverything();
      
      _selectedTable = Table(
        id: table.id,
        name: table.name,
        serviceCharge: table.serviceCharge,
        hasDueOrders: false,
        specialNote: '',
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
      
      _cartItems.clear();
      _discountController.text = '0';
      _currentInvoiceId = null;
      _serviceAmountOverride = 0.0;
      _isEditingDueTable = false;
      _existingDueTableItems.clear();
      _isProcessingDueTablePayment = false;
      _paymentDataForPrinting = null;
      _kotCode = null;
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
                                          _handleTableSelection(table);
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isLoading = true;
        List<Table> currentDueTables = [];
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (isLoading) {
              _loadDueTablesForDialog().then((tables) {
                if (mounted) {
                  setDialogState(() {
                    currentDueTables = tables;
                    isLoading = false;
                  });
                }
              }).catchError((error) {
                if (mounted) {
                  setDialogState(() {
                    isLoading = false;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error loading due tables: $error'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  });
                }
              });
            }
            
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
                          if (!isLoading && currentDueTables.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.refresh, color: Colors.grey[700]),
                              onPressed: () async {
                                setDialogState(() {
                                  isLoading = true;
                                });
                                final refreshedTables = await _loadDueTablesForDialog();
                                setDialogState(() {
                                  currentDueTables = refreshedTables;
                                  isLoading = false;
                                });
                              },
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      Divider(color: Colors.grey[300], thickness: 1),
                      const SizedBox(height: 8),
                      
                      Expanded(
                        child: isLoading
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CircularProgressIndicator.adaptive(),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Loading active tables...',
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey[500],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : currentDueTables.isEmpty
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
        );
      },
    );
  }

  Future<List<Table>> _loadDueTablesForDialog() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse(ApiConstants.getFullUrl(ApiConstants.getDueTables)),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'Success' && data['data'] != null) {
          List<dynamic> tablesData = data['data'];
          List<Table> dueTables = [];
          
          for (var tableData in tablesData) {
            Table table = Table.fromJson(tableData);
            
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
      print('Error loading due tables: $e');
      return [];
    }
  }

  Widget _buildTableCardFromImage(Table table, VoidCallback onMarkAsPaid) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: CircularProgressIndicator.adaptive(),
            ),
          ),
        );
        
        Future.delayed(const Duration(milliseconds: 100), () {
          setState(() {
            _selectedTable = Table(
              id: table.id,
              name: table.name,
              serviceCharge: table.serviceCharge,
              hasDueOrders: table.hasDueOrders,
              specialNote: table.specialNote,
            );
          });
          
          _loadDueTableItems(table).then((_) {
            Navigator.pop(context);
          }).catchError((error) {
            Navigator.pop(context);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading due table: $error'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          });
        });
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
        Uri.parse('${ApiConstants.getFullUrl(ApiConstants.markTablePaid)}/${table.id}'),
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
                specialNote: '',
              );
            }
            return t;
          }).toList();
          _filteredTables = _tables;
        });
        
        await _removeLocalTableNote(table.id);
        
        onSuccess();
      }
    } catch (e) {
      _showMessage('Error marking table as paid: $e');
    }
  }

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

  Widget _buildCartItem(CartItem cartItem, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cartItem.product.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (cartItem.specialNote != null && cartItem.specialNote!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.yellow[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Note',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.orange[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rs.${cartItem.getPriceByOrderType(_selectedOrderType).toStringAsFixed(2)} x ${cartItem.quantity}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    'Total: Rs.${cartItem.getTotalPrice(_selectedOrderType).toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18, color: Colors.black87),
                  onPressed: () => _updateCartQuantity(index, cartItem.quantity - 1),
                  padding: EdgeInsets.zero,
                ),
                Text(
                  cartItem.quantity.toString(),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18, color: Colors.black87),
                  onPressed: () => _updateCartQuantity(index, cartItem.quantity + 1),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Color.fromARGB(255, 221, 49, 49)),
                  onPressed: () => _removeFromCart(index),
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
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: Text(
              'Categories',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
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
                                        color: isSelected ? Colors.blue : Colors.black87,
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
                        return _buildCartItem(_cartItems[index], index);
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

  void _showCartItemPopup(int index) {
    final cartItem = _cartItems[index];
    final noteController = TextEditingController(text: cartItem.specialNote ?? '');
    
    showDialog(
      context: context,
      builder: (context) {
        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.all(16),
            width: isLandscape 
                ? MediaQuery.of(context).size.width * 0.5
                : MediaQuery.of(context).size.width * 0.75,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Special Note:',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 9),
                
                TextField(
                  controller: noteController,
                  maxLines: isLandscape ? 2 : 3,
                  decoration: InputDecoration(
                    hintText: 'Enter special instructions...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                  style: GoogleFonts.poppins(fontSize: 10),
                ),
                
                const SizedBox(height: 12),
                
                if (isLandscape)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.18,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.18,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _cartItems[index] = cartItem.copyWith(
                                specialNote: noteController.text.trim().isEmpty 
                                    ? null 
                                    : noteController.text.trim(),
                              );
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Item updated'),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Text(
                            'Save',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _cartItems[index] = cartItem.copyWith(
                                specialNote: noteController.text.trim().isEmpty 
                                    ? null 
                                    : noteController.text.trim(),
                              );
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Item updated'),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Text(
                            'Save',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
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
                      return _buildCartItemForPanel(_cartItems[index], index);
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

  Widget _buildCartItemForPanel(CartItem cartItem, int index) {
    final isDueTableItem = _isEditingDueTable && !cartItem.isNewItem;
    
    return InkWell(
      onLongPress: () {
        _showCartItemPopup(index);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 4), 
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: Colors.white,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cartItem.product.name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 12, 
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (cartItem.specialNote != null && cartItem.specialNote!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.yellow[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'N',
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
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
              
              if (isDueTableItem)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Qty: ${cartItem.quantity}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          fontSize: 11, 
                          color: Colors.black,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    Container(
                      width: 24,
                      height: 24,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 14, color: Colors.red),
                        onPressed: () => _removeFromCart(index),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                              icon: const Icon(Icons.remove, size: 12, color: Colors.black),
                              onPressed: () => _updateCartQuantity(index, cartItem.quantity - 1),
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
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Container(
                            width: 24,
                            height: 20,
                            child: IconButton(
                              icon: const Icon(Icons.add, size: 12, color: Colors.black),
                              onPressed: () => _updateCartQuantity(index, cartItem.quantity + 1),
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
              
              if (!isDueTableItem) const SizedBox(width: 4),
                
              if (!isDueTableItem)
                Container(
                  width: 24,
                  height: 24,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 14, color: Colors.black),
                    onPressed: () => _removeFromCart(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
            ],
          ),
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
      color: Colors.white,
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
                          color: Colors.black87,
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
      color: Colors.white,
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
            color: Colors.black87,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'CloudChef POS',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'v1.0005',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (_selectedCustomer != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  'Customer: ${_selectedCustomer!.name}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
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
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                    if (_selectedTable!.specialNote.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Icon(Icons.note, size: 12, color: Colors.yellow),
                      ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.print, color: Colors.white, size: 20),
                if (_getTotalConnectedPrinters() > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 10,
                        minHeight: 10,
                      ),
                      child: Text(
                        _getTotalConnectedPrinters().toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showPrinterDialog,
            tooltip: 'Printers',
            iconSize: 20,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white, size: 20),
            onPressed: _logout,
            tooltip: 'Logout',
            iconSize: 20,
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

  Widget _buildPrinterIconWithStatus() {
    final totalPrinters = _getTotalConnectedPrinters();
    final hasCashierPrinter = _connectedCashierDevices.isNotEmpty;
    final hasKitchenPrinter = _connectedKitchenDevices.isNotEmpty;
    final hasBotPrinter = _connectedBotDevices.isNotEmpty;
    
    Color iconColor;
    Color badgeColor;
    String tooltipText = 'Printers';
    
    if (!hasCashierPrinter) {
      iconColor = Colors.red;
      badgeColor = Colors.red;
      tooltipText = 'No cashier printer connected!';
    } else if (!hasKitchenPrinter && !hasBotPrinter) {
      iconColor = Colors.orange;
      badgeColor = Colors.orange;
      tooltipText = 'Only cashier printer connected';
    } else if (!hasKitchenPrinter || !hasBotPrinter) {
      iconColor = Colors.amber;
      badgeColor = Colors.amber;
      tooltipText = 'Some printers not connected';
    } else {
      iconColor = Colors.green;
      badgeColor = Colors.green;
      tooltipText = 'All printers connected';
    }
    
    return Stack(
      children: [
        Icon(
          Icons.print,
          color: iconColor,
          size: 24,
        ),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 1),
            ),
            constraints: const BoxConstraints(
              minWidth: 14,
              minHeight: 14,
            ),
            child: Center(
              child: Text(
                totalPrinters.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
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
  final bool isDueTable;
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
    this.isDueTable = false,
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
              if (widget.isDueTable) {
                _autoFillCardAmountForDueTable();
              } else {
                _autoFillCardAmount();
              }
            });
          } else {
            if (!widget.isDueTable) {
              _autoFillCardAmount();
            }
          }
          break;
      }
    }
  }
 
  void _autoFillCardAmount() {
    double currentTotalPaid = cashPaid + bankTransferPaid + creditUsed;
    double currentRemainingBalance = widget.netAmount - currentTotalPaid;
 
    if (currentRemainingBalance > 0) {
      setState(() {
        cardPaid = currentRemainingBalance;
        _cardAmountController.text = cardPaid.toStringAsFixed(2);
     
        totalPaid = cashPaid + bankTransferPaid + creditUsed + cardPaid;
        remainingBalance = widget.netAmount - totalPaid;
      });
    }
  }
 
  void _autoFillCardAmountForDueTable() {
    setState(() {
      cardPaid = widget.netAmount;
      _cardAmountController.text = cardPaid.toStringAsFixed(2);
   
      cashPaid = 0.0;
      bankTransferPaid = 0.0;
      creditUsed = 0.0;
      _cashAmountController.text = '';
      _bankTransferAmountController.text = '';
      _creditAmountController.text = '';
   
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
        Uri.parse(ApiConstants.getFullUrl(ApiConstants.getUser)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
          'referer': ApiConstants.REFERER_HEADER,
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
        Uri.parse(ApiConstants.getFullUrl(ApiConstants.bankList)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
          'referer': ApiConstants.REFERER_HEADER,
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
   
    double currentMethodAmount = 0.0;
    switch (method) {
      case 'Cash':
        currentMethodAmount = cashPaid;
        break;
      case 'Bank Transfer':
        currentMethodAmount = bankTransferPaid;
        break;
      case 'Credit':
        currentMethodAmount = creditUsed;
        break;
      case 'Card':
        currentMethodAmount = cardPaid;
        break;
    }
   
    double otherMethodsTotal = totalPaid - currentMethodAmount;
   
    double maxAllowed = (widget.netAmount - otherMethodsTotal);
   
    if (method != 'Cash' && amount > maxAllowed) {
      amount = maxAllowed > 0 ? maxAllowed : 0;
     
      switch (method) {
        case 'Bank Transfer':
          _bankTransferAmountController.text = amount > 0 ? amount.toStringAsFixed(2) : '';
          break;
        case 'Credit':
          _creditAmountController.text = amount > 0 ? amount.toStringAsFixed(2) : '';
          break;
        case 'Card':
          _cardAmountController.text = amount > 0 ? amount.toStringAsFixed(2) : '';
          break;
      }
    }
   
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
 
  Future<Map<String, dynamic>> _processPayment() async {
    if (_isProcessingPayment) return {'success': false, 'invoiceNumber': null};
    setState(() => _isProcessingPayment = true);
 
    if (widget.selectedTable != null && widget.selectedTable!.id == null) {
      _showError('Selected table has no valid ID. Please select a different table.');
      setState(() => _isProcessingPayment = false);
      return {'success': false, 'invoiceNumber': null};
    }
   
    double nonCashTotal = bankTransferPaid + creditUsed + cardPaid;
    double cashPayment = cashPaid;
   
    if (nonCashTotal > widget.netAmount) {
      _showError('Total non-cash payment (${nonCashTotal.toStringAsFixed(2)}) exceeds invoice amount (${widget.netAmount.toStringAsFixed(2)})');
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
        Uri.parse(ApiConstants.getFullUrl(ApiConstants.processPayment)),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
          'referer': ApiConstants.REFERER_HEADER,
        },
        body: json.encode(paymentPayload),
      ).timeout(const Duration(seconds: 30));
  
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
   
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
     
        String? invoiceNumber;
        if (responseData['data'] != null && responseData['data']['invoice_head'] != null) {
          invoiceNumber = responseData['data']['invoice_head']['invoice_code'];
        }
     
        await _showSuccessDialog(responseData, invoiceNumber);
        
        return {
          'success': true, 
          'invoiceNumber': invoiceNumber,
          'paymentData': {
            'cash': cashPaid,
            'bank': bankTransferPaid,
            'credit': creditUsed,
            'card': cardPaid,
          }
        };
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
                Navigator.of(context).pop({
                  'success': true, 
                  'invoiceNumber': invoiceNumber,
                  'paymentData': {
                    'cash': cashPaid,
                    'bank': bankTransferPaid,
                    'credit': creditUsed,
                    'card': cardPaid,
                  }
                });
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
      'special_note': item.specialNote ?? '', 
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
    'order_now_order_info_id': "",
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
      'special_note': widget.selectedTable!.specialNote,
    };
  }
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
  Map<String, dynamic> cardData = {};
  if (cardPaid > 0) {
    cardData = {
      'card_no': '0000',
      'cardAmount': cardPaid.toStringAsFixed(2),
      'cardType': 'VISA',
    };
 
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
  String overBal = "";
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
      'cardBank': {},
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
    'overBal': overBal,
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
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Center(
                    child: SizedBox(
                      height: 48,
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: primaryColor,
                        labelColor: primaryColor,
                        unselectedLabelColor: Colors.grey[600],
                        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
                        isScrollable: true,
                        tabAlignment: TabAlignment.center,
                        tabs: const [
                          Tab(text: 'Cash'),
                          Tab(text: 'Bank'),
                          Tab(text: 'Credit'),
                          Tab(text: 'Card'),
                        ],
                      ),
                    ),
                  ),
                ),
             
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Cash Payment',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _cashAmountController,
                              decoration: InputDecoration(
                                labelText: 'Cash Amount',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                hintText: 'Enter cash amount',
                                suffixText: 'LKR',
                                prefixIcon: const Icon(Icons.money),
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
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Bank Transfer Payment',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _bankTransferAmountController,
                              decoration: InputDecoration(
                                labelText: 'Transfer Amount',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                hintText: 'Enter transfer amount',
                                suffixText: 'LKR',
                                prefixIcon: const Icon(Icons.account_balance),
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              onChanged: (value) => _updatePaymentAmount('Bank Transfer', value),
                            ),
                            const SizedBox(height: 16),
                            _buildBankDropdownSection('transfer'),
                          ],
                        ),
                      ),
                   
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
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
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Credit Payment',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Customer: ${widget.selectedCustomer!.name}',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Available Credit: Rs. 10000.00",
                                          style: TextStyle(
                                            color: Colors.blue[700],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  TextField(
                                    controller: _creditAmountController,
                                    decoration: InputDecoration(
                                      labelText: 'Credit Amount to Use',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      hintText: 'Enter credit amount',
                                      suffixText: 'LKR',
                                      prefixIcon: const Icon(Icons.credit_card),
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
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Card Payment',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _cardAmountController,
                              decoration: InputDecoration(
                                labelText: 'Card Amount',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                hintText: 'Enter card amount',
                                suffixText: 'LKR',
                                prefixIcon: const Icon(Icons.credit_score),
                                helperText: widget.isDueTable
                                    ? 'Auto-filled with due table amount'
                                    : 'Auto-filled with remaining balance',
                                helperStyle: TextStyle(
                                  color: primaryColor,
                                  fontSize: 12,
                                ),
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              onChanged: (value) => _updatePaymentAmount('Card', value),
                            ),
                            const SizedBox(height: 16),
                            _buildBankDropdownSection('card'),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: 'VISA',
                              decoration: InputDecoration(
                                labelText: 'Card Type',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.credit_card),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'VISA', child: Text('VISA')),
                                DropdownMenuItem(value: 'MASTER', child: Text('MasterCard')),
                                DropdownMenuItem(value: 'AMEX', child: Text('American Express')),
                                DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                              ],
                              onChanged: (value) {
                                
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
       
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildPaymentSummaryRow("Invoice Amount", _fmt(widget.netAmount), isBold: true),
                          const SizedBox(height: 16),
                          _buildPaymentSummaryRow("Total Paid", _fmt(totalPaid)),
                          const SizedBox(height: 16),
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
               
                  const Spacer(),
               
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Breakdown',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildPaymentBreakdownRow('Cash:', cashPaid),
                          _buildPaymentBreakdownRow('Bank Transfer:', bankTransferPaid),
                          _buildPaymentBreakdownRow('Credit:', creditUsed),
                          _buildPaymentBreakdownRow('Card:', cardPaid),
                          const Divider(height: 20),
                          _buildPaymentBreakdownRow('TOTAL:', totalPaid, isTotal: true),
                        ],
                      ),
                    ),
                  ),
               
                  const SizedBox(height: 20),
               
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.18,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop({'success': false, 'invoiceNumber': null}),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            "CANCEL",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.18,
                        child: ElevatedButton(
                          onPressed: _isProcessingPayment ? null : () async {
                            final result = await _processPayment();
                            if (result['success'] == true) {
                             
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isProcessingPayment ? Colors.grey : accentColor,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isProcessingPayment
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                                  ),
                                )
                              : Text(
                                  "PROCESS PAYMENT",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
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
        ],
      ),
    );
  }
 
  Widget _buildPaymentSummaryRow(String label, String value, {bool isBold = false, bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            color: isNegative ? Colors.red : primaryColor,
          ),
        ),
      ],
    );
  }
 
  Widget _buildPaymentBreakdownRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal ? primaryColor : Colors.black87,
            ),
          ),
          Text(
            _fmt(amount),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal ? primaryColor : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
 
  String _fmt(double v) => 'Rs. ${v.toStringAsFixed(2)}';
}