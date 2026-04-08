import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:resturant/ApiConstants.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class InvoiceItem {
  final int id;
  final int invoiceHeadId;
  final int lotId;
  final String barCode;
  final String name;
  final String sName;
  final String unit;
  final String? exDate;
  final double qty;
  final double cost;
  final double price;
  final double dis;
  final double disVal;
  final double totalDiscount;
  final double total;
  final double profit;
  final int returnItem;
  final double returnQty;
  final int? tblRoomBookingDetailsId;
  final String createdAt;
  final String updatedAt;
  final String fullDiscount;

  InvoiceItem({
    required this.id,
    required this.invoiceHeadId,
    required this.lotId,
    required this.barCode,
    required this.name,
    required this.sName,
    required this.unit,
    this.exDate,
    required this.qty,
    required this.cost,
    required this.price,
    required this.dis,
    required this.disVal,
    required this.totalDiscount,
    required this.total,
    required this.profit,
    required this.returnItem,
    required this.returnQty,
    this.tblRoomBookingDetailsId,
    required this.createdAt,
    required this.updatedAt,
    required this.fullDiscount,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: json['id'] ?? 0,
      invoiceHeadId: json['invoice_head_id'] ?? 0,
      lotId: json['lot_id'] ?? 0,
      barCode: json['bar_code'] ?? '',
      name: json['name'] ?? '',
      sName: json['s_name'] ?? '',
      unit: json['unit'] ?? '',
      exDate: json['ex_date'],
      qty: (json['qty'] is num) ? (json['qty'] as num).toDouble() : 0.0,
      cost: (json['cost'] is num) ? (json['cost'] as num).toDouble() : 0.0,
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : 0.0,
      dis: (json['dis'] is num) ? (json['dis'] as num).toDouble() : 0.0,
      disVal: (json['disVal'] is num) ? (json['disVal'] as num).toDouble() : 0.0,
      totalDiscount: (json['total_discount'] is num) ? (json['total_discount'] as num).toDouble() : 0.0,
      total: (json['total'] is num) ? (json['total'] as num).toDouble() : 0.0,
      profit: (json['profit'] is num) ? (json['profit'] as num).toDouble() : 0.0,
      returnItem: json['returnItem'] ?? 0,
      returnQty: (json['returnQty'] is num) ? (json['returnQty'] as num).toDouble() : 0.0,
      tblRoomBookingDetailsId: json['tbl_room_booking_details_id'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      fullDiscount: json['full_discount'] ?? '0.00',
    );
  }
}

class Invoice {
  final int id;
  final String date;
  final String time;
  final String invoiceCode;
  final String saleType;
  final String? referenceNo;
  final String? customerName;
  final double total;
  final double netAmount;
  final double profit;
  final double grossAmount;
  final double pay;
  final double cash;
  final double credit;
  final int cancel;
  final String userName;
  final String createdAt;
  final String updatedAt;
  final List<InvoiceItem> items;
  final String? cancellationReason;

  Invoice({
    required this.id,
    required this.date,
    required this.time,
    required this.invoiceCode,
    required this.saleType,
    this.referenceNo,
    this.customerName,
    required this.total,
    required this.netAmount,
    required this.profit,
    required this.grossAmount,
    required this.pay,
    required this.cash,
    required this.credit,
    required this.cancel,
    required this.userName,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    this.cancellationReason,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    // FIXED: Properly parse cancel field from various formats
    int parseCancelStatus(dynamic cancelValue) {
      if (cancelValue == null) return 0;
      
      if (cancelValue is int) {
        return cancelValue;
      } else if (cancelValue is String) {
        if (cancelValue.toLowerCase() == 'true') return 1;
        if (cancelValue.toLowerCase() == 'false') return 0;
        return int.tryParse(cancelValue) ?? 0;
      } else if (cancelValue is bool) {
        return cancelValue ? 1 : 0;
      } else if (cancelValue is num) {
        return cancelValue.toInt();
      }
      return 0;
    }
    
    // Check multiple possible field names for cancellation
    int cancelStatus = parseCancelStatus(json['cancel']);
    
    // If cancel is 0, check other possible field names
    if (cancelStatus == 0) {
      cancelStatus = parseCancelStatus(json['is_cancelled'] ?? 
                                      json['is_canceled'] ?? 
                                      json['cancelled'] ?? 
                                      json['canceled']);
    }
    
    // Check status field for cancellation
    if (cancelStatus == 0 && json['status'] != null) {
      final status = json['status'].toString().toLowerCase();
      if (status.contains('cancel') || status == 'cancelled' || status == 'canceled') {
        cancelStatus = 1;
      }
    }

    return Invoice(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      invoiceCode: json['invoice_code'] ?? '',
      saleType: json['sale_type'] ?? 'RETAIL',
      referenceNo: json['reference_no'],
      customerName: json['customer_name'] ?? 'Walk-in Customer',
      total: (json['total'] is num) ? (json['total'] as num).toDouble() : 0.0,
      netAmount: (json['net_amount'] is num) ? (json['net_amount'] as num).toDouble() : 0.0,
      profit: (json['profit'] is num) ? (json['profit'] as num).toDouble() : 0.0,
      grossAmount: (json['gross_amount'] is num) ? (json['gross_amount'] as num).toDouble() : 0.0,
      pay: (json['pay'] is num) ? (json['pay'] as num).toDouble() : 0.0,
      cash: (json['cash'] is num) ? (json['cash'] as num).toDouble() : 0.0,
      credit: (json['credit'] is num) ? (json['credit'] as num).toDouble() : 0.0,
      cancel: cancelStatus, // Use parsed cancel status
      userName: json['user_name'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      items: (json['items'] as List?)?.map((item) => InvoiceItem.fromJson(item)).toList() ?? [],
      cancellationReason: json['cancellation_reason'] ?? 
                         json['cancel_reason'] ?? 
                         json['reason'],
    );
  }

  bool get isCancelled => cancel == 1;
  String get displayDate => '$date ${time.isNotEmpty ? time.split(':').take(2).join(':') : ''}';
}

class InvoiceManagementScreen extends StatefulWidget {
  const InvoiceManagementScreen({super.key});

  @override
  _InvoiceManagementScreenState createState() => _InvoiceManagementScreenState();
}

class _InvoiceManagementScreenState extends State<InvoiceManagementScreen> {
  List<Invoice> invoices = [];
  List<Invoice> filteredInvoices = [];
  bool isLoading = true;
  int currentPage = 1;
  int totalPages = 1;
  int totalItems = 0;
  String? _token;
  String _errorMessage = '';
  TextEditingController searchController = TextEditingController();
  bool isSearching = false;
  bool _hasError = false;
  bool _isDebugMode = true;
  
  // Bluetooth variables
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  List<BluetoothDevice> _devices = [];
  List<BluetoothDevice> _connectedDevices = [];
  List<BluetoothConnection> _connections = [];
  bool _isScanning = false;
  bool _isBluetoothEnabled = false;
  bool _isConnecting = false;
  bool _isAutoConnecting = false;
  
  // Target printer name (cashier printer)
  static const String TARGET_PRINTER_NAME = "Printer001";
  
  // Cancel invoice variables
  TextEditingController _cancelReasonController = TextEditingController();
  Invoice? _selectedInvoiceForCancel;
  
  // Store cancellation reasons
  Map<String, String> _cancellationReasons = {};

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Step 1: Fetch token and invoices
    await _fetchTokenAndData();
    
    // Step 2: Initialize Bluetooth and auto-connect to target printer
    await _initializeBluetoothAndConnect();
  }

  Future<void> _initializeBluetoothAndConnect() async {
    try {
      // Check if Bluetooth is enabled
      bool? isEnabled = await _bluetooth.isEnabled;
      
      if (isEnabled == null || !isEnabled) {
        // Try to enable Bluetooth
        isEnabled = await _bluetooth.requestEnable();
        
        if (isEnabled == null || !isEnabled) {
          if (_isDebugMode) print('Bluetooth is disabled');
          _showMessage('Please enable Bluetooth to connect to printer');
          return;
        }
      }
      
      setState(() {
        _isBluetoothEnabled = true;
      });
      
      // Load bonded devices
      await _loadBondedDevices();
      
      // Auto-connect to target printer
      await _autoConnectToTargetPrinter();
      
    } catch (e) {
      if (_isDebugMode) print('Bluetooth initialization error: $e');
      _showMessage('Bluetooth initialization error: ${e.toString()}');
    }
  }

  Future<void> _autoConnectToTargetPrinter() async {
    if (!_isBluetoothEnabled) {
      _showMessage('Bluetooth is not enabled');
      return;
    }
    
    setState(() {
      _isAutoConnecting = true;
    });
    
    try {
      // Find target printer in bonded devices
      BluetoothDevice? targetDevice;
      
      for (var device in _devices) {
        if (device.name != null && device.name!.contains(TARGET_PRINTER_NAME)) {
          targetDevice = device;
          break;
        }
      }
      
      if (targetDevice == null) {
        // If not found in bonded devices, try to discover
        _showMessage('Target printer not found in bonded devices. Scanning...');
        
        // Start discovery
        final stream = _bluetooth.startDiscovery();
        stream.listen((BluetoothDiscoveryResult result) {
          final device = result.device;
          if (device.name != null && device.name!.contains(TARGET_PRINTER_NAME)) {
            // Stop discovery
            _bluetooth.cancelDiscovery();
            
            // Connect to found device
            _connectToDevice(device, isAutoConnect: true);
          }
        });
        
        // Stop discovery after 10 seconds
        await Future.delayed(const Duration(seconds: 10));
        await _bluetooth.cancelDiscovery();
        
        if (!_connectedDevices.any((d) => d.name != null && d.name!.contains(TARGET_PRINTER_NAME))) {
          _showMessage('Could not find printer: $TARGET_PRINTER_NAME');
        }
      } else {
        // Connect to the found device
        await _connectToDevice(targetDevice, isAutoConnect: true);
      }
    } catch (e) {
      if (_isDebugMode) print('Auto-connect error: $e');
      _showMessage('Failed to auto-connect to printer: ${e.toString()}');
    } finally {
      setState(() {
        _isAutoConnecting = false;
      });
    }
  }

  @override
  void dispose() {
    // Don't disconnect when screen is disposed - keep the connection active
    // for faster printing next time
    _cancelReasonController.dispose();
    super.dispose();
  }

  Future<void> _checkBluetoothStatus() async {
    try {
      bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      setState(() {
        _isBluetoothEnabled = isEnabled ?? false;
      });
      if (_isBluetoothEnabled) {
        await _loadBondedDevices();
      }
    } catch (e) {
      _showMessage('Bluetooth status check error: $e');
    }
  }

  Future<void> _loadBondedDevices() async {
    try {
      List<BluetoothDevice> bondedDevices = await _bluetooth.getBondedDevices();
      setState(() {
        _devices = bondedDevices;
      });
      
      // Log found devices for debugging
      if (_isDebugMode) {
        print('Found ${bondedDevices.length} bonded devices:');
        for (var device in bondedDevices) {
          print('  - ${device.name} (${device.address})');
        }
      }
    } catch (e) {
      if (_isDebugMode) print('Error loading bonded devices: $e');
      _showMessage('Error loading bonded devices: ${e.toString()}');
    }
  }

  Future<void> _scanDevices() async {
    if (!_isBluetoothEnabled) {
      _showMessage('Please enable Bluetooth first');
      return;
    }

    setState(() {
      _isScanning = true;
      _devices = [];
    });

    try {
      // First load bonded devices
      await _loadBondedDevices();
      
      // Then start discovery for new devices
      final stream = _bluetooth.startDiscovery();
      stream.listen((BluetoothDiscoveryResult result) {
        final device = result.device;
        if (device.name != null && !_devices.any((d) => d.address == device.address)) {
          setState(() {
            _devices.add(device);
          });
        }
      });

      // Scan for 10 seconds
      await Future.delayed(const Duration(seconds: 10));
      await _bluetooth.cancelDiscovery();
    } catch (e) {
      if (_isDebugMode) print('Scan error: $e');
      _showMessage('Scan error: ${e.toString()}');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device, {bool isAutoConnect = false}) async {
    // Check if already connected
    if (_connectedDevices.any((d) => d.address == device.address)) {
      if (!isAutoConnect) {
        _showMessage('Already connected to ${device.name}');
      }
      return;
    }

    setState(() => _isConnecting = true);
    
    try {
      final connection = await BluetoothConnection.toAddress(device.address);
      
      // Listen for incoming data
      connection.input!.listen((data) {
        // Handle incoming data if needed
        if (_isDebugMode) {
          print('Received data from printer: ${String.fromCharCodes(data)}');
        }
      }).onDone(() {
        // Handle disconnection
        setState(() {
          _connections.removeWhere((conn) => _getDeviceForConnection(conn)?.address == device.address);
          _connectedDevices.removeWhere((d) => d.address == device.address);
        });
        
        if (!isAutoConnect) {
          _showMessage('${device.name} disconnected');
        }
        
        // Try to reconnect if this was the target printer
        if (device.name != null && device.name!.contains(TARGET_PRINTER_NAME)) {
          _showMessage('Target printer disconnected. Attempting to reconnect...');
          Future.delayed(const Duration(seconds: 2), () {
            _connectToDevice(device, isAutoConnect: true);
          });
        }
      });

      // Add to connections
      setState(() {
        _connections.add(connection);
        _connectedDevices.add(device);
        _isConnecting = false;
      });
      
      if (!isAutoConnect) {
        _showMessage('Connected to ${device.name}');
      }
      
      if (_isDebugMode) {
        print('Successfully connected to ${device.name} (${device.address})');
      }
    } catch (e) {
      setState(() => _isConnecting = false);
      
      if (!isAutoConnect) {
        _showMessage('Failed to connect to ${device.name}: ${e.toString()}');
      }
      
      if (_isDebugMode) {
        print('Connection error to ${device.name}: $e');
      }
      
      // If auto-connect failed, retry after delay
      if (isAutoConnect && device.name != null && device.name!.contains(TARGET_PRINTER_NAME)) {
        _showMessage('Auto-connect failed. Retrying in 5 seconds...');
        await Future.delayed(const Duration(seconds: 5));
        await _connectToDevice(device, isAutoConnect: true);
      }
    }
  }

  BluetoothDevice? _getDeviceForConnection(BluetoothConnection connection) {
    try {
      final index = _connections.indexOf(connection);
      if (index >= 0 && index < _connectedDevices.length) {
        return _connectedDevices[index];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _disconnectDevice(BluetoothDevice device) async {
    try {
      final index = _connectedDevices.indexWhere((d) => d.address == device.address);
      if (index >= 0 && index < _connections.length) {
        await _connections[index].finish();
        setState(() {
          _connections.removeAt(index);
          _connectedDevices.removeAt(index);
        });
        _showMessage('Disconnected from ${device.name}');
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
      _connectedDevices.clear();
    });
    _showMessage('Disconnected from all printers');
  }

  void _showMessage(String message) {
    if (_isDebugMode) print('Message: $message');
    
    // Only show snackbar if not in auto-connect mode
    if (!_isAutoConnecting && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _fetchTokenAndData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');
      if (_token == null || _token!.isEmpty) {
        if (_isDebugMode) print('No auth token found, redirecting to login');
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      if (_isDebugMode) print('Auth token found: ${_token!.substring(0, 20)}...');
      await fetchInvoices();
    } catch (e) {
      setState(() {
        _errorMessage = 'Token error: $e';
        _hasError = true;
        isLoading = false;
      });
    }
  }

  // Fetch cancellation reason for a specific invoice
  Future<String?> _fetchCancellationReason(String invoiceCode) async {
    try {
      if (_cancellationReasons.containsKey(invoiceCode)) {
        return _cancellationReasons[invoiceCode];
      }

      final url = ApiConstants.getFullUrl('${ApiConstants.canceledInvoices}/$invoiceCode');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['reason'] != null) {
          _cancellationReasons[invoiceCode] = data['reason'];
          return data['reason'];
        }
      }
      return null;
    } catch (e) {
      if (_isDebugMode) print('Error fetching cancellation reason: $e');
      return null;
    }
  }

  Future<void> fetchInvoices() async {
    setState(() {
      isLoading = true;
      _errorMessage = '';
      _hasError = false;
    });

    try {
      final url = ApiConstants.getFullUrl('${ApiConstants.getInvoices}?page=$currentPage');
      if (_isDebugMode) print('Fetching invoices from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (_isDebugMode) {
        print('Response status: ${response.statusCode}');
        print('Response body length: ${response.body.length}');
      }

      if (response.statusCode == 200) {
        String responseBody = response.body.trim();
        if (responseBody.isEmpty || responseBody == '{}' || responseBody == '[]' || responseBody == 'null') {
          if (_isDebugMode) print('Empty or invalid response body');
          setState(() {
            invoices = [];
            filteredInvoices = [];
            isLoading = false;
            _errorMessage = 'No invoice data available';
            _hasError = true;
          });
          return;
        }

        dynamic decodedData;
        try {
          decodedData = json.decode(responseBody);
        } catch (e) {
          throw FormatException('Invalid JSON response from server');
        }

        List<dynamic> invoiceList = [];
        Map<String, dynamic>? metaData = {};

        if (decodedData is Map<String, dynamic>) {
          if (decodedData['data'] != null) {
            if (decodedData['data'] is List) {
              invoiceList = decodedData['data'] as List;
              metaData = decodedData;
            } else if (decodedData['data'] is Map<String, dynamic>) {
              Map<String, dynamic> dataMap = decodedData['data'];
              if (dataMap['data'] != null && dataMap['data'] is List) {
                invoiceList = dataMap['data'] as List;
              }
              metaData = dataMap;
            }
          } else if (decodedData['invoices'] != null && decodedData['invoices'] is List) {
            invoiceList = decodedData['invoices'] as List;
            metaData = decodedData;
          } else if (decodedData['success'] == true && decodedData['data'] is List) {
            invoiceList = decodedData['data'] as List;
            metaData = decodedData;
          } else if (decodedData.isEmpty) {
            setState(() {
              invoices = [];
              filteredInvoices = [];
              isLoading = false;
              _errorMessage = 'No invoice data available';
              _hasError = true;
            });
            return;
          }
        } else if (decodedData is List) {
          invoiceList = decodedData;
        } else {
          throw Exception('Unexpected response format');
        }

        List<Invoice> parsedInvoices = [];
        for (var invoiceJson in invoiceList) {
          try {
            if (invoiceJson is Map<String, dynamic>) {
              // Debug raw invoice data
              if (_isDebugMode && invoiceJson['invoice_code'] != null) {
                print('Invoice ${invoiceJson['invoice_code']}: cancel=${invoiceJson['cancel']}, '
                    'is_cancelled=${invoiceJson['is_cancelled']}, cancelled=${invoiceJson['cancelled']}');
              }
              parsedInvoices.add(Invoice.fromJson(invoiceJson));
            }
          } catch (e) {
            if (_isDebugMode) print('Error parsing invoice: $e');
          }
        }

        setState(() {
          invoices = parsedInvoices;
          filteredInvoices = List.from(invoices);
          if (metaData != null && metaData.isNotEmpty) {
            currentPage = metaData['current_page'] ?? 1;
            totalPages = metaData['last_page'] ?? 1;
            totalItems = metaData['total'] ?? parsedInvoices.length;
          } else {
            currentPage = 1;
            totalPages = 1;
            totalItems = parsedInvoices.length;
          }
          isLoading = false;
          _hasError = false;
        });
        
        // Debug: Count cancelled invoices
        if (_isDebugMode) {
          int cancelledCount = parsedInvoices.where((inv) => inv.isCancelled).length;
          print('Total invoices: ${parsedInvoices.length}, Cancelled: $cancelledCount');
        }
      } else if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        Navigator.pushReplacementNamed(context, '/login');
      } else if (response.statusCode == 404) {
        setState(() {
          _errorMessage = 'API endpoint not found (404)';
          _hasError = true;
          isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
          _hasError = true;
          isLoading = false;
        });
      }
    } on FormatException catch (e) {
      setState(() {
        _errorMessage = 'Data format error: $e';
        _hasError = true;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching data: $e';
        _hasError = true;
        isLoading = false;
      });
    }
  }

  Future<void> searchInvoices(String query) async {
    if (query.isEmpty) {
      setState(() {
        filteredInvoices = List.from(invoices);
        isSearching = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
      isLoading = true;
    });

    try {
      final url = ApiConstants.getFullUrl('${ApiConstants.searchInvoices}?query=$query');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        String responseBody = response.body.trim();
        if (responseBody.isEmpty || responseBody == '{}' || responseBody == '[]') {
          setState(() {
            filteredInvoices = [];
            isLoading = false;
          });
          return;
        }

        dynamic decodedData;
        try {
          decodedData = json.decode(responseBody);
        } catch (e) {
          throw FormatException('Invalid search response');
        }

        List<dynamic> searchResults = [];
        if (decodedData is Map<String, dynamic>) {
          if (decodedData['data'] != null && decodedData['data'] is List) {
            searchResults = decodedData['data'] as List;
          } else if (decodedData['results'] != null && decodedData['results'] is List) {
            searchResults = decodedData['results'] as List;
          } else if (decodedData is List) {
            searchResults = decodedData as List;
          }
        } else if (decodedData is List) {
          searchResults = decodedData;
        }

        setState(() {
          filteredInvoices = searchResults
              .map((invoiceJson) => Invoice.fromJson(invoiceJson))
              .toList();
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        setState(() {
          _errorMessage = 'Search failed: ${response.statusCode}';
          isLoading = false;
        });
      }
    } on FormatException catch (e) {
      setState(() {
        _errorMessage = 'Search format error: $e';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching: $e';
        isLoading = false;
      });
    }
  }

  void filterInvoices(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredInvoices = List.from(invoices);
        isSearching = false;
      });
      return;
    }

    setState(() {
      filteredInvoices = invoices.where((invoice) {
        final customerName = invoice.customerName ?? '';
        return invoice.invoiceCode.toLowerCase().contains(query.toLowerCase()) ||
            customerName.toLowerCase().contains(query.toLowerCase()) ||
            invoice.date.toLowerCase().contains(query.toLowerCase()) ||
            invoice.userName.toLowerCase().contains(query.toLowerCase()) ||
            invoice.saleType.toLowerCase().contains(query.toLowerCase());
      }).toList();
      isSearching = true;
    });
  }

  // Cancel invoice method
  Future<void> cancelInvoice(int id, String invoiceCode, String reason) async {
    try {
      final url = ApiConstants.getFullUrl(ApiConstants.invoiceCancel);
      if (_isDebugMode) print('Cancelling invoice: $url');
     
      final Map<String, dynamic> requestBody = {
        'invoice_code': invoiceCode,
        'reason': reason,
      };
     
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode(requestBody),
      );
     
      if (_isDebugMode) {
        print('Cancel response: ${response.statusCode} - ${response.body}');
      }
     
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice cancelled successfully')),
        );
        
        // Store the cancellation reason locally
        _cancellationReasons[invoiceCode] = reason;
        
        _cancelReasonController.clear();
        
        // Force immediate UI update by marking invoice as cancelled locally
        setState(() {
          // Update the invoice in the lists
          for (int i = 0; i < invoices.length; i++) {
            if (invoices[i].invoiceCode == invoiceCode) {
              invoices[i] = Invoice(
                id: invoices[i].id,
                date: invoices[i].date,
                time: invoices[i].time,
                invoiceCode: invoices[i].invoiceCode,
                saleType: invoices[i].saleType,
                referenceNo: invoices[i].referenceNo,
                customerName: invoices[i].customerName,
                total: invoices[i].total,
                netAmount: invoices[i].netAmount,
                profit: invoices[i].profit,
                grossAmount: invoices[i].grossAmount,
                pay: invoices[i].pay,
                cash: invoices[i].cash,
                credit: invoices[i].credit,
                cancel: 1, // Mark as cancelled
                userName: invoices[i].userName,
                createdAt: invoices[i].createdAt,
                updatedAt: invoices[i].updatedAt,
                items: invoices[i].items,
                cancellationReason: reason,
              );
              break;
            }
          }
          
          // Also update filtered invoices
          filteredInvoices = List.from(invoices);
          
          // Reset to first page to see the cancelled invoice
          currentPage = 1;
        });
        
        // Then fetch fresh data from server
        await fetchInvoices();
      } else if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        dynamic errorData;
        try {
          errorData = json.decode(response.body);
        } catch (_) {
          errorData = {'message': response.body};
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${errorData['message'] ?? 'Unknown error'}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Generate receipt bytes
  Future<List<int>> _generateReceipt(Invoice invoice, {bool isReprint = true}) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    // ================= HEADER =================
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
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Tel: 0712901901',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.hr();

    // Reprint Header if it's a reprint
    if (isReprint) {
      bytes += generator.text(
        '*** REPRINT ***',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          reverse: true,
        ),
      );
      bytes += generator.hr();
    }

    // Cancelled Header if cancelled
    if (invoice.isCancelled) {
      bytes += generator.text(
        '*** CANCELLED INVOICE ***',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          reverse: true,
        ),
      );
      bytes += generator.hr();
    }

    bytes += generator.text(
      'Invoice No: ${invoice.invoiceCode}',
      styles: const PosStyles(align: PosAlign.left, bold: true),
    );
    bytes += generator.text('Cashier: ${invoice.userName}',
      styles: const PosStyles(align: PosAlign.left));
    bytes += generator.text(
      'Date: ${invoice.date}',
      styles: const PosStyles(align: PosAlign.right),
    );
    bytes += generator.text(
      'Time: ${invoice.time}',
      styles: const PosStyles(align: PosAlign.right),
    );

    if (invoice.customerName != null && invoice.customerName != 'Walk-in Customer') {
      bytes += generator.text(
        'Customer: ${invoice.customerName}',
        styles: const PosStyles(align: PosAlign.left),
      );
    }

    bytes += generator.text(
      'Order Type: ${invoice.saleType}',
      styles: const PosStyles(align: PosAlign.left),
    );
    bytes += generator.hr(ch: '-');

    // ================= TABLE HEADER =================
    bytes += generator.row([
      PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true)),
      PosColumn(
        text: 'Unit Price',
        width: 3,
        styles: const PosStyles(bold: true, align: PosAlign.center),
      ),
      PosColumn(
        text: 'Dis',
        width: 3,
        styles: const PosStyles(bold: true, align: PosAlign.center),
      ),
      PosColumn(
        text: 'Amount',
        width: 4,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]);
    bytes += generator.hr(ch: '-');

    // ================= ITEMS =================
    for (var item in invoice.items) {
      bytes += generator.text(
        item.name.toUpperCase(),
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.row([
        PosColumn(
          text: item.qty.toStringAsFixed(0),
          width: 2,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: item.price.toStringAsFixed(2),
          width: 3,
          styles: const PosStyles(align: PosAlign.center),
        ),
        PosColumn(
          text: item.totalDiscount.toStringAsFixed(2),
          width: 3,
          styles: const PosStyles(align: PosAlign.center),
        ),
        PosColumn(
          text: item.total.toStringAsFixed(2),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();

    // ================= TOTALS =================
    double grossAmount = invoice.grossAmount;
    double totalDiscount = invoice.items.fold(0.0, (sum, item) => sum + item.totalDiscount);
    double discountPercentage = grossAmount > 0 ? (totalDiscount / grossAmount * 100).roundToDouble() : 0.0;
    double serviceAmount = 0.0;
    double netAmount = invoice.netAmount;

    bytes += generator.row([
      PosColumn(text: 'Gross Amount', width: 7),
      PosColumn(
        text: grossAmount.toStringAsFixed(2),
        width: 5,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    if (totalDiscount > 0) {
      bytes += generator.row([
        PosColumn(
          text: 'Discount (${discountPercentage.toStringAsFixed(0)}%)',
          width: 7,
        ),
        PosColumn(
          text: '-${totalDiscount.toStringAsFixed(2)}',
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    if (serviceAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Service Charge', width: 7),
        PosColumn(
          text: serviceAmount.toStringAsFixed(2),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(
        text: 'NET AMOUNT',
        width: 7,
        styles: const PosStyles(bold: true),
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
    bytes += generator.hr();

    // ================= FOOTER =================
    if (isReprint) {
      bytes += generator.text(
        '*** REPRINT - NOT ORIGINAL ***',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.hr();
    }

    bytes += generator.text(
      'THANK YOU, COME AGAIN',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'Software By (e) SLT Cloud POS',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      '0252264723 | 0702967270',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'www.posmasters.lk',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  Future<void> _printReceipt(Invoice invoice) async {
    if (_connectedDevices.isEmpty) {
      _showMessage('Please connect to a Bluetooth printer first');
      return;
    }

    try {
      final bytes = await _generateReceipt(invoice);
      bool printSuccess = false;
      
      for (int i = 0; i < _connectedDevices.length; i++) {
        try {
          // Check if connection is still active
          if (_connections[i].isConnected) {
            _connections[i].output.add(Uint8List.fromList(bytes));
            await _connections[i].output.allSent;
            _showMessage('Receipt sent to ${_connectedDevices[i].name}');
            printSuccess = true;
          } else {
            _showMessage('Connection lost to ${_connectedDevices[i].name}. Reconnecting...');
            // Try to reconnect
            await _connectToDevice(_connectedDevices[i], isAutoConnect: true);
          }
        } catch (e) {
          _showMessage('Error printing to ${_connectedDevices[i].name}: $e');
        }
      }
      
      if (!printSuccess) {
        _showMessage('Failed to print. No active printer connections.');
      }
    } catch (e) {
      _showMessage('Error generating receipt: $e');
    }
  }

  // Show invoice details with print option and cancellation reason
  void showInvoiceDetails(Invoice invoice) async {
    // Fetch cancellation reason if invoice is cancelled
    String? cancellationReason = invoice.cancellationReason;
    if (invoice.isCancelled && cancellationReason == null) {
      cancellationReason = await _fetchCancellationReason(invoice.invoiceCode);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Invoice Details - ${invoice.invoiceCode}',
            style: TextStyle(
              color: invoice.isCancelled ? Colors.red : Colors.black,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (invoice.isCancelled) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.red[800], size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'INVOICE CANCELLED',
                                style: TextStyle(
                                  color: Colors.red[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (cancellationReason != null && cancellationReason.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Reason: $cancellationReason',
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildDetailRow('Invoice Code', invoice.invoiceCode),
                _buildDetailRow('Date', invoice.displayDate),
                _buildDetailRow('Customer', invoice.customerName ?? 'Walk-in Customer'),
                _buildDetailRow('Sale Type', invoice.saleType),
                _buildDetailRow('Net Amount', 'Rs ${invoice.netAmount.toStringAsFixed(2)}'),
                _buildDetailRow('Gross Amount', 'Rs ${invoice.grossAmount.toStringAsFixed(2)}'),
                _buildDetailRow('Profit', 'Rs ${invoice.profit.toStringAsFixed(2)}'),
                _buildDetailRow('Paid', 'Rs ${invoice.pay.toStringAsFixed(2)}'),
                _buildDetailRow('Cash', 'Rs ${invoice.cash.toStringAsFixed(2)}'),
                _buildDetailRow('Credit', 'Rs ${invoice.credit.toStringAsFixed(2)}'),
                _buildDetailRow('Processed By', invoice.userName),
                _buildDetailRow('Status', invoice.isCancelled ? 'Cancelled' : 'Active'),
                _buildDetailRow('Created', invoice.createdAt),
                if (invoice.isCancelled && cancellationReason != null && cancellationReason.isNotEmpty)
                  _buildDetailRow('Cancellation Reason', cancellationReason),
                // Show printer connection status
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _connectedDevices.isNotEmpty ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _connectedDevices.isNotEmpty ? Colors.green[200]! : Colors.orange[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _connectedDevices.isNotEmpty ? Icons.print : Icons.print_disabled,
                        color: _connectedDevices.isNotEmpty ? Colors.green[800] : Colors.orange[800],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _connectedDevices.isNotEmpty 
                                  ? 'Printer Connected' 
                                  : 'Printer Not Connected',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _connectedDevices.isNotEmpty ? Colors.green[800] : Colors.orange[800],
                                fontSize: 12,
                              ),
                            ),
                            if (_connectedDevices.isNotEmpty)
                              Text(
                                _connectedDevices.map((d) => d.name ?? 'Unknown').join(', '),
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 11,
                                ),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            if (_connectedDevices.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _printReceipt(invoice);
                },
                icon: const Icon(Icons.print, color: Colors.blue),
                label: const Text('Print', style: TextStyle(color: Colors.blue)),
              ),
            if (!invoice.isCancelled)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  showCancelInvoiceDialog(invoice);
                },
                child: const Text('Cancel Invoice', style: TextStyle(color: Colors.red)),
              ),
          ],
        );
      },
    );
  }

  // Show cancel invoice dialog
  void showCancelInvoiceDialog(Invoice invoice) {
    _selectedInvoiceForCancel = invoice;
    _cancelReasonController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Cancel Invoice',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Please provide a reason for canceling invoice ${invoice.invoiceCode}:',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _cancelReasonController,
                    maxLines: 3,
                    minLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Enter reason here...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  if (_cancelReasonController.text.isEmpty)
                    const Text(
                      'Please enter a cancellation reason',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _selectedInvoiceForCancel = null;
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text(
                        'NO',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _cancelReasonController.text.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              _confirmCancelInvoice();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        disabledBackgroundColor: Colors.red.withOpacity(0.5),
                      ),
                      child: const Text(
                        'YES, CANCEL',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmCancelInvoice() {
    if (_selectedInvoiceForCancel == null || _cancelReasonController.text.isEmpty) {
      return;
    }
   
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Cancellation'),
          content: Text(
            'Are you sure you want to cancel invoice ${_selectedInvoiceForCancel!.invoiceCode}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                cancelInvoice(
                  _selectedInvoiceForCancel!.id,
                  _selectedInvoiceForCancel!.invoiceCode,
                  _cancelReasonController.text,
                );
                _selectedInvoiceForCancel = null;
              },
              child: const Text('Yes', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // Show printer connection dialog
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
                    // Connection Status
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _connectedDevices.isNotEmpty ? Colors.green[50] : Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isAutoConnecting ? Icons.bluetooth_searching :
                            _connectedDevices.isNotEmpty ? Icons.bluetooth_connected : Icons.bluetooth,
                            color: _connectedDevices.isNotEmpty ? Colors.green : 
                                  _isAutoConnecting ? Colors.blue : Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isAutoConnecting 
                                      ? 'Auto-connecting to printer...' 
                                      : _connectedDevices.isNotEmpty 
                                          ? 'Connected to ${_connectedDevices.length} printer(s)' 
                                          : 'Printer disconnected',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _connectedDevices.isNotEmpty ? Colors.green[800] : Colors.orange[800],
                                  ),
                                ),
                                if (_connectedDevices.isNotEmpty)
                                  Text(
                                    _connectedDevices.map((d) => d.name ?? 'Unknown').join(', '),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                if (!_isBluetoothEnabled)
                                  const Text(
                                    'Bluetooth is disabled',
                                    style: TextStyle(color: Colors.red, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    if (_isAutoConnecting)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Auto-connecting to target printer...', textAlign: TextAlign.center),
                            SizedBox(height: 4),
                            Text('Printer001', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    else if (_isScanning)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('Scanning for devices...'),
                          ],
                        ),
                      )
                    else if (_devices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('No devices found. Tap scan to search for printers.'),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          itemCount: _devices.length,
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            final isConnected = _connectedDevices.any((d) => d.address == device.address);
                            final isTargetPrinter = device.name != null && device.name!.contains(TARGET_PRINTER_NAME);
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: isTargetPrinter ? Colors.blue[50] : null,
                              child: ListTile(
                                leading: Icon(
                                  isConnected ? Icons.check_circle : Icons.bluetooth,
                                  color: isConnected ? Colors.green : Colors.blue,
                                ),
                                title: Text(
                                  device.name ?? 'Unknown Device',
                                  style: TextStyle(
                                    fontWeight: isTargetPrinter ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(device.address),
                                    if (isTargetPrinter)
                                      const Text(
                                        'Target Printer',
                                        style: TextStyle(color: Colors.blue, fontSize: 10),
                                      ),
                                  ],
                                ),
                                trailing: isConnected
                                    ? IconButton(
                                        icon: const Icon(Icons.close, color: Colors.red),
                                        onPressed: () => _disconnectDevice(device),
                                      )
                                    : _isConnecting
                                        ? const CircularProgressIndicator()
                                        : IconButton(
                                            icon: const Icon(Icons.link, color: Colors.blue),
                                            onPressed: () => _connectToDevice(device),
                                          ),
                              ),
                            );
                          },
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Auto-connect button
                        ElevatedButton.icon(
                          onPressed: _isAutoConnecting ? null : _autoConnectToTargetPrinter,
                          icon: const Icon(Icons.autorenew, size: 18),
                          label: const Text('Auto Connect'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[100],
                            foregroundColor: Colors.blue[800],
                          ),
                        ),
                        
                        // Scan button
                        ElevatedButton.icon(
                          onPressed: _scanDevices,
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text('Scan'),
                        ),
                        
                        // Close button
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                    
                    // Disconnect all button
                    if (_connectedDevices.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ElevatedButton.icon(
                          onPressed: _disconnectAllDevices,
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Disconnect All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[100],
                            foregroundColor: Colors.red[800],
                          ),
                        ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    if (isSearching || totalPages <= 1) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: currentPage > 1
                ? () {
                    setState(() => currentPage--);
                    fetchInvoices();
                  }
                : null,
          ),
          Text(
            'Page $currentPage of $totalPages ($totalItems items)',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: currentPage < totalPages
                ? () {
                    setState(() => currentPage++);
                    fetchInvoices();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[600]),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error Loading Data',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red[700]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20, color: Colors.red),
              onPressed: () => setState(() {
                _errorMessage = '';
                _hasError = false;
              }),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20, color: Colors.red),
              onPressed: fetchInvoices,
            ),
          ],
        ),
      ),
    );
  }

  // Invoice card with red background for cancelled invoices
  Widget _buildInvoiceCard(Invoice invoice) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2,
      // RED BACKGROUND FOR CANCELLED INVOICES
      color: invoice.isCancelled ? Colors.red[50] : Colors.white,
      shape: invoice.isCancelled 
          ? RoundedRectangleBorder(
              side: BorderSide(color: Colors.red[300]!, width: 1),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.invoiceCode,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: invoice.isCancelled ? Colors.red[800] : Colors.black,
                    ),
                  ),
                  Text(
                    invoice.customerName ?? 'Walk-in Customer',
                    style: TextStyle(
                      fontSize: 14,
                      color: invoice.isCancelled ? Colors.red[700] : Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (invoice.isCancelled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cancel, size: 14, color: Colors.red[800]),
                    const SizedBox(width: 4),
                    Text(
                      'CANCELLED',
                      style: TextStyle(
                        color: Colors.red[800],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              invoice.displayDate,
              style: TextStyle(
                color: invoice.isCancelled ? Colors.red[600] : Colors.black54,
              ),
            ),
            Row(
              children: [
                Text(
                  'Amount: Rs ${invoice.grossAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: invoice.isCancelled ? Colors.red[700] : Colors.green,
                  ),
                ),
                
              ],
            ),
            Text(
              'By: ${invoice.userName}',
              style: TextStyle(
                fontSize: 12,
                color: invoice.isCancelled ? Colors.red[600] : Colors.black54,
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios, 
          size: 16, 
          color: invoice.isCancelled ? Colors.red[400] : Colors.grey
        ),
        onTap: () => showInvoiceDetails(invoice),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Management'),
        backgroundColor: const Color(0xFF1A3C34),
        foregroundColor: Colors.white,
        actions: [
          // Printer status indicator
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  _isAutoConnecting ? Icons.bluetooth_searching :
                  _connectedDevices.isNotEmpty ? Icons.print : Icons.print_disabled,
                  color: _connectedDevices.isNotEmpty ? Colors.white : Colors.grey[400],
                ),
                onPressed: _showPrinterDialog,
                tooltip: 'Printer Settings',
              ),
              if (_connectedDevices.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              if (_isAutoConnecting)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.blue[400],
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchInvoices,
            tooltip: 'Refresh Invoices',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F0F2), Color(0xFFF5F8FA)],
          ),
        ),
        child: Column(
          children: [
            // Auto-connect status indicator
            if (_isAutoConnecting)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.blue[50],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    const Text('Auto-connecting to printer...'),
                    const SizedBox(width: 4),
                    Text(
                      TARGET_PRINTER_NAME,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            
            // Printer connection status banner
            if (_connectedDevices.isNotEmpty && !_isAutoConnecting)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.green[50],
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[800], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Connected to: ${_connectedDevices.map((d) => d.name ?? 'Printer').join(', ')}',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info, size: 18),
                      onPressed: _showPrinterDialog,
                      color: Colors.green[800],
                    ),
                  ],
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search by invoice code, customer, date, or user...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            setState(() {
                              filteredInvoices = List.from(invoices);
                              isSearching = false;
                            });
                          },
                        )
                      : null,
                ),
                onChanged: filterInvoices,
                onSubmitted: searchInvoices,
              ),
            ),
            if (_hasError) _buildErrorWidget(),
            _buildPaginationControls(),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading invoices...'),
                        ],
                      ),
                    )
                  : filteredInvoices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                searchController.text.isNotEmpty
                                    ? 'No invoices found matching your search'
                                    : 'No invoices available',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: fetchInvoices,
                                child: const Text('Refresh'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: fetchInvoices,
                          child: ListView.builder(
                            itemCount: filteredInvoices.length,
                            itemBuilder: (context, index) {
                              final invoice = filteredInvoices[index];
                              return _buildInvoiceCard(invoice);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!_connectedDevices.isNotEmpty && !_isAutoConnecting)
            FloatingActionButton.small(
              onPressed: _autoConnectToTargetPrinter,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.bluetooth, color: Colors.white),
              tooltip: 'Connect Printer',
            ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: fetchInvoices,
            backgroundColor: const Color(0xFF1A3C34),
            child: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Invoices',
          ),
        ],
      ),
    );
  }
}