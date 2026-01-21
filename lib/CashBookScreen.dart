import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teller Cash Book',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter',
      ),
      home: const TellerCashBook(),
    );
  }
}

// API Configuration
const apiBaseUrl = 'https://api-kafenio.sltcloud.lk';
const cashbookEndpoint = '/api/teller-cashbook';
const userBalanceEndpoint = '/api/teller-cashbook/user-balance';

// Transaction Model
class Transaction {
  final String id;
  final DateTime date;
  final String user;
  final String account;
  final String description;
  final double amount;
  final double dr;
  final double cr;
  final double balance;

  Transaction({
    required this.id,
    required this.date,
    required this.user,
    required this.account,
    required this.description,
    required this.amount,
    required this.dr,
    required this.cr,
    required this.balance,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Transaction(
      id: json['id']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      user: json['user_name']?.toString() ?? json['user']?.toString() ?? 'Unknown',
      account: json['account']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      amount: parseDouble(json['amount']),
      dr: parseDouble(json['dr']),
      cr: parseDouble(json['cr']),
      balance: parseDouble(json['balance']),
    );
  }
}

class UserBalance {
  final int id;
  final String name;
  final double balance;

  UserBalance({
    required this.id,
    required this.name,
    required this.balance,
  });

  factory UserBalance.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return UserBalance(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      balance: parseDouble(json['balance']),
    );
  }
}

class TransactionDataSource extends DataGridSource {
  TransactionDataSource({required List<Transaction> transactions}) {
    _transactions = transactions
        .map<DataGridRow>((transaction) => DataGridRow(cells: [
              DataGridCell<DateTime>(columnName: 'date', value: transaction.date),
              DataGridCell<String>(columnName: 'user', value: transaction.user),
              DataGridCell<String>(
                  columnName: 'description', value: transaction.description),
              DataGridCell<double>(columnName: 'amount', value: transaction.amount),
              DataGridCell<double>(columnName: 'debit', value: transaction.dr),
              DataGridCell<double>(columnName: 'credit', value: transaction.cr),
              DataGridCell<double>(columnName: 'balance', value: transaction.balance),
            ]))
        .toList();
  }

  List<DataGridRow> _transactions = [];
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₨', decimalDigits: 2);

  @override
  List<DataGridRow> get rows => _transactions;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
        cells: row.getCells().map<Widget>((dataGridCell) {
      final isAmount = dataGridCell.columnName == 'amount' ||
          dataGridCell.columnName == 'debit' ||
          dataGridCell.columnName == 'credit' ||
          dataGridCell.columnName == 'balance';

      Color? getTextColor() {
        if (dataGridCell.columnName == 'debit') {
          return const Color(0xFFDC2626);
        } else if (dataGridCell.columnName == 'credit') {
          return const Color(0xFF059669);
        } else if (dataGridCell.columnName == 'balance') {
          final balance = dataGridCell.value as double;
          return balance >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626);
        }
        return null;
      }

      return Container(
        alignment: isAmount ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Text(
          dataGridCell.columnName == 'date'
              ? DateFormat('MMM dd, yyyy').format(dataGridCell.value as DateTime)
              : isAmount
                  ? _currencyFormat.format(dataGridCell.value as double)
                  : dataGridCell.value.toString(),
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: getTextColor() ?? Colors.grey[800],
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }).toList());
  }
}

class TellerCashBook extends StatefulWidget {
  const TellerCashBook({super.key});

  @override
  State<TellerCashBook> createState() => _TellerCashBookScreenState();
}

class _TellerCashBookScreenState extends State<TellerCashBook> {
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  String _selectedUser = 'All';
  List<UserBalance> _users = [];
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₨', decimalDigits: 2);
  int _currentPage = 1;
  int _rowsPerPage = 50;
  final List<int> _rowsPerPageOptions = [10, 25, 50, 100];
  List<Transaction> _allTransactions = [];
  late TransactionDataSource _transactionDataSource;
  bool _isLoading = false;
  String _errorMessage = '';
  Timer? _tokenRefreshTimer;
  double _totalDebit = 0;
  double _totalCredit = 0;
  double _totalBalance = 0;
  String _selectedTimeRange = 'Today';

  @override
  void initState() {
    super.initState();
    _transactionDataSource = TransactionDataSource(transactions: _allTransactions);
    _fetchInitialData();
  }

  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    super.dispose();
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('Authentication token not found. Please login again.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  Future<void> _fetchInitialData() async {
    await _fetchUserBalances();
    await _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _allTransactions = [];
    });

    try {
      final headers = await _getAuthHeaders();
      final body = jsonEncode({
        'from': DateFormat('yyyy-MM-dd').format(_fromDate),
        'to': DateFormat('yyyy-MM-dd').format(_toDate),
        'user': _selectedUser == 'All'
            ? '0'
            : _users
                .firstWhere(
                  (u) => u.name == _selectedUser,
                  orElse: () => UserBalance(id: 0, name: '', balance: 0),
                )
                .id
                .toString(),
      });

      final uri = Uri.parse('$apiBaseUrl$cashbookEndpoint');
      final response = await http.post(uri, headers: headers, body: body);

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response received from server');
        }

        dynamic data;
        try {
          data = json.decode(response.body);
        } catch (e) {
          throw Exception('Failed to parse JSON: $e');
        }

        if (data == null || data['data'] == null) {
          throw Exception('Null or invalid response data');
        }

        final responseData = data['data'];
        double parseDouble(dynamic value) {
          if (value == null) return 0.0;
          if (value is num) return value.toDouble();
          if (value is String) return double.tryParse(value) ?? 0.0;
          return 0.0;
        }

        _totalDebit = parseDouble(responseData['totalDr']);
        _totalCredit = parseDouble(responseData['totalCr']);
        _totalBalance = _totalCredit - _totalDebit;

        List<dynamic> transactionsData = [];
        if (responseData['list'] is Map && responseData['list']['data'] is List) {
          transactionsData = responseData['list']['data'];
        } else if (responseData['list'] is List) {
          transactionsData = responseData['list'];
        } else {
          throw Exception('Unexpected data structure in response');
        }

        final transactions = transactionsData
            .map((item) => Transaction.fromJson(item as Map<String, dynamic>))
            .toList();

        setState(() {
          _allTransactions = transactions;
          _transactionDataSource =
              TransactionDataSource(transactions: _getPaginatedTransactions());
        });
      } else {
        final error = response.body.isNotEmpty
            ? json.decode(response.body)
            : {'message': 'Unknown error'};
        throw Exception(
            error['message'] ?? 'Failed to load transactions. Status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: ${e.toString()}';
      });
      _showErrorDialog(_errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchUserBalances() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$apiBaseUrl$userBalanceEndpoint'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response received from server');
        }

        dynamic data;
        try {
          data = json.decode(response.body);
        } catch (e) {
          throw Exception('Failed to parse JSON: $e');
        }

        if (data == null || data['data'] == null) {
          throw Exception('Null or invalid response data');
        }

        List<UserBalance> users = [];
        final responseData = data['data'];
        if (responseData is List) {
          users = responseData
              .map((user) => UserBalance.fromJson(user as Map<String, dynamic>))
              .toList();
        } else if (responseData is Map) {
          users.add(UserBalance.fromJson(Map<String, dynamic>.from(responseData)));
        } else {
          throw Exception('Unexpected data structure in response');
        }

        setState(() {
          _users = users;
          if (_users.isNotEmpty) {
            _selectedUser = 'All';
          }
        });
      } else {
        final error = response.body.isNotEmpty
            ? json.decode(response.body)
            : {'message': 'Unknown error'};
        throw Exception(
            error['message'] ?? 'Failed to load user balances. Status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        // _errorMessage = 'Error loading user balances: ${e.toString()}';
      });
      _showErrorDialog(_errorMessage);
    }
  }

  List<Transaction> _getPaginatedTransactions() {
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    return _allTransactions.sublist(
      startIndex.clamp(0, _allTransactions.length),
      endIndex.clamp(0, _allTransactions.length),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  List<Transaction> _getTodayTransactions() {
    final today = DateTime.now();
    return _allTransactions.where((transaction) {
      return transaction.date.year == today.year &&
             transaction.date.month == today.month &&
             transaction.date.day == today.day;
    }).toList();
  }

  Future<void> _showCustomDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[700]!,
              onPrimary: Colors.white,
              onSurface: Colors.blue[800]!,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue[700],
              ),
            ),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
        _currentPage = 1;
        _selectedTimeRange = 'Custom Range';
      });
      await _fetchTransactions();
    }
  }

  void _updateDateRange(String range) {
    setState(() {
      _selectedTimeRange = range;
      switch (range) {
        case 'Today':
          _fromDate = DateTime.now();
          _toDate = DateTime.now();
          break;
        case 'Yesterday':
          _fromDate = DateTime.now().subtract(const Duration(days: 1));
          _toDate = DateTime.now().subtract(const Duration(days: 1));
          break;
        case 'This Week':
          final now = DateTime.now();
          _fromDate = now.subtract(Duration(days: now.weekday - 1));
          _toDate = now;
          break;
        case 'Last Week':
          final now = DateTime.now();
          _fromDate = now.subtract(Duration(days: now.weekday + 6));
          _toDate = now.subtract(Duration(days: now.weekday));
          break;
        case 'This Month':
          final now = DateTime.now();
          _fromDate = DateTime(now.year, now.month, 1);
          _toDate = now;
          break;
        case 'Last Month':
          final now = DateTime.now();
          final lastMonth = DateTime(now.year, now.month - 1, 1);
          _fromDate = lastMonth;
          _toDate = DateTime(now.year, now.month, 0);
          break;
      }
      _currentPage = 1;
    });
    _fetchTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final todayTransactions = _getTodayTransactions();
    final transactionsToShow = _selectedTimeRange == 'Today' ? todayTransactions : _allTransactions.take(5).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Teller Cash Book',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[800],
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('MMM dd, yyyy').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Balance Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[700]!, Colors.blue[900]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CURRENT BALANCE',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue[100],
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _currencyFormat.format(_totalBalance),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Quick Stats Cards
              Row(
                children: [
                  _buildStatCard(
                    title: 'Total In',
                    amount: _totalCredit,
                    icon: Icons.arrow_downward_rounded,
                    color: const Color(0xFF059669),
                    iconColor: const Color(0xFF34D399),
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    title: 'Total Out',
                    amount: _totalDebit,
                    icon: Icons.arrow_upward_rounded,
                    color: const Color(0xFFDC2626),
                    iconColor: const Color(0xFFF87171),
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    title: 'Count',
                    amount: transactionsToShow.length.toDouble(),
                    icon: Icons.list_alt_rounded,
                    color: const Color(0xFF2563EB),
                    iconColor: const Color(0xFF60A5FA),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Time Range Selector
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildTimeRangeButton('Today', Icons.today),
                    _buildTimeRangeButton('Yesterday', Icons.calendar_today),
                    _buildTimeRangeButton('This Week', Icons.date_range),
                    _buildTimeRangeButton('Last Week', Icons.history),
                    _buildTimeRangeButton('This Month', Icons.calendar_month),
                    _buildTimeRangeButton('Last Month', Icons.history_toggle_off),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Custom Date Range Picker
              Row(
                children: [
                  Expanded(
                    child: _buildDatePickerButton(
                      'From: ${DateFormat('MMM dd, yyyy').format(_fromDate)}',
                      () => _selectDate(context, isFromDate: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDatePickerButton(
                      'To: ${DateFormat('MMM dd, yyyy').format(_toDate)}',
                      () => _selectDate(context, isFromDate: false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 120,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedUser,
                      icon: Icon(Icons.person_outline, size: 16, color: Colors.blue[700]),
                      elevation: 8,
                      style: TextStyle(color: Colors.blue[800], fontSize: 12),
                      underline: const SizedBox(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedUser = newValue;
                            _currentPage = 1;
                          });
                          _fetchTransactions();
                        }
                      },
                      items: ['All', ..._users.map((u) => u.name)]
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Recent Transactions Header
              Row(
                children: [
                  Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  if (_selectedTimeRange != 'Today')
                    TextButton.icon(
                      onPressed: () => _updateDateRange('Today'),
                      icon: Icon(Icons.refresh, size: 14, color: Colors.blue[700]),
                      label: Text(
                        'Show Today',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Transactions List
              _isLoading
                  ? Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : _errorMessage.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.error_outline, size: 32, color: Colors.red[400]),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage,
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : transactionsToShow.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 48,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _selectedTimeRange == 'Today'
                                        ? 'No transactions today'
                                        : 'No transactions found',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: transactionsToShow.map((transaction) {
                                return _buildTransactionCard(transaction);
                              }).toList(),
                            ),
              
              const SizedBox(height: 16),
              
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AllTransactionsScreen(
                            transactions: _allTransactions,
                            fromDate: _fromDate,
                            toDate: _toDate,
                            selectedUser: _selectedUser,
                            users: _users,
                            totalDebit: _totalDebit,
                            totalCredit: _totalCredit,
                            totalBalance: _totalBalance,
                            onDateRangeChanged: (from, to) {
                              setState(() {
                                _fromDate = from;
                                _toDate = to;
                                _currentPage = 1;
                              });
                              _fetchTransactions();
                            },
                            onUserChanged: (user) {
                              setState(() {
                                _selectedUser = user;
                                _currentPage = 1;
                              });
                              _fetchTransactions();
                            },
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    icon: Icon(Icons.list_alt, size: 16, color: Colors.white),
                    label: Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _printReport,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: Colors.blue[700]!),
                    ),
                    icon: Icon(Icons.print_outlined, size: 16, color: Colors.blue[700]),
                    label: Text(
                      'Print Report',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: iconColor,
                  ),
                ),
                Text(
                  title == 'Count'
                      ? '${amount.toInt()}'
                      : _currencyFormat.format(amount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
      );
  }

  Widget _buildTimeRangeButton(String label, IconData icon) {
    final isSelected = _selectedTimeRange == label;
    return Expanded(
      child: InkWell(
        onTap: () => _updateDateRange(label),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.blue[700] : Colors.grey[500],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? Colors.blue[700] : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 14, color: Colors.blue[700]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final isCredit = transaction.cr > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCredit
                  ? const Color(0xFFD1FAE5).withOpacity(0.2)
                  : const Color(0xFFFEE2E2).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCredit
                    ? const Color(0xFF34D399).withOpacity(0.3)
                    : const Color(0xFFF87171).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isCredit ? const Color(0xFF059669) : const Color(0xFFDC2626),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        transaction.description,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(transaction.amount),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isCredit ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        transaction.user,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isCredit ? 'CREDIT' : 'DEBIT',
                        style: TextStyle(
                          fontSize: 10,
                          color: isCredit ? Colors.green[700] : Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('hh:mm a').format(transaction.date),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM dd, yyyy').format(transaction.date),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, {required bool isFromDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _fromDate : _toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[700]!,
              onPrimary: Colors.white,
              onSurface: Colors.blue[800]!,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue[700],
              ),
            ),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
        _currentPage = 1;
        _selectedTimeRange = 'Custom Range';
      });
      await _fetchTransactions();
    }
  }

  void _printReport() {
    final report = StringBuffer();
    report.writeln('Teller Cash Book Report');
    report.writeln(
        'Date Range: ${DateFormat('MMM dd, yyyy').format(_fromDate)} to ${DateFormat('MMM dd, yyyy').format(_toDate)}');
    report.writeln('User: $_selectedUser');
    report.writeln('Total Debit: ${_currencyFormat.format(_totalDebit)}');
    report.writeln('Total Credit: ${_currencyFormat.format(_totalCredit)}');
    report.writeln('Balance: ${_currencyFormat.format(_totalBalance)}');
    report.writeln('\nTransactions:');
    for (var transaction in _allTransactions) {
      report.writeln(
          '${transaction.id} | ${DateFormat('MMM dd, yyyy').format(transaction.date)} | ${transaction.user} | ${transaction.description} | ${_currencyFormat.format(transaction.amount)}');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Report generated and ready to print'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green[700],
      ),
    );
  }
}

class AllTransactionsScreen extends StatefulWidget {
  final List<Transaction> transactions;
  final DateTime fromDate;
  final DateTime toDate;
  final String selectedUser;
  final List<UserBalance> users;
  final double totalDebit;
  final double totalCredit;
  final double totalBalance;
  final Function(DateTime, DateTime) onDateRangeChanged;
  final Function(String) onUserChanged;

  const AllTransactionsScreen({
    super.key,
    required this.transactions,
    required this.fromDate,
    required this.toDate,
    required this.selectedUser,
    required this.users,
    required this.totalDebit,
    required this.totalCredit,
    required this.totalBalance,
    required this.onDateRangeChanged,
    required this.onUserChanged,
  });

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  late DateTime _fromDate;
  late DateTime _toDate;
  late String _selectedUser;
  int _currentPage = 1;
  int _rowsPerPage = 50;
  final List<int> _rowsPerPageOptions = [10, 25, 50, 100];
  late TransactionDataSource _transactionDataSource;
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₨', decimalDigits: 2);
  bool _isLoading = false;
  String _errorMessage = '';
  List<Transaction> _allTransactions = [];
  double _totalDebit = 0.0;
  double _totalCredit = 0.0;
  double _totalBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _fromDate = widget.fromDate;
    _toDate = widget.toDate;
    _selectedUser = widget.selectedUser;
    _allTransactions = widget.transactions;
    _totalDebit = widget.totalDebit;
    _totalCredit = widget.totalCredit;
    _totalBalance = widget.totalBalance;
    _transactionDataSource = TransactionDataSource(transactions: _getPaginatedTransactions());
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      throw Exception('Authentication token not found. Please login again.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final headers = await _getAuthHeaders();
      final body = jsonEncode({
        'from': DateFormat('yyyy-MM-dd').format(_fromDate),
        'to': DateFormat('yyyy-MM-dd').format(_toDate),
        'user': _selectedUser == 'All'
            ? '0'
            : widget.users
                .firstWhere(
                  (u) => u.name == _selectedUser,
                  orElse: () => UserBalance(id: 0, name: '', balance: 0),
                )
                .id
                .toString(),
      });

      final uri = Uri.parse('$apiBaseUrl$cashbookEndpoint');
      final response = await http.post(uri, headers: headers, body: body);

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response received from server');
        }

        dynamic data;
        try {
          data = json.decode(response.body);
        } catch (e) {
          throw Exception('Failed to parse JSON: $e');
        }

        if (data == null || data['data'] == null) {
          throw Exception('Null or invalid response data');
        }

        final responseData = data['data'];
        double parseDouble(dynamic value) {
          if (value == null) return 0.0;
          if (value is num) return value.toDouble();
          if (value is String) return double.tryParse(value) ?? 0.0;
          return 0.0;
        }

        final totalDebit = parseDouble(responseData['totalDr']);
        final totalCredit = parseDouble(responseData['totalCr']);
        final totalBalance = totalCredit - totalDebit;

        List<dynamic> transactionsData = [];
        if (responseData['list'] is Map && responseData['list']['data'] is List) {
          transactionsData = responseData['list']['data'];
        } else if (responseData['list'] is List) {
          transactionsData = responseData['list'];
        } else {
          throw Exception('Unexpected data structure in response');
        }

        final transactions = transactionsData
            .map((item) => Transaction.fromJson(item as Map<String, dynamic>))
            .toList();

        setState(() {
          _allTransactions = transactions;
          _totalDebit = totalDebit;
          _totalCredit = totalCredit;
          _totalBalance = totalBalance;
          _transactionDataSource =
              TransactionDataSource(transactions: _getPaginatedTransactions());
        });

        widget.onDateRangeChanged(_fromDate, _toDate);
      } else {
        final error = response.body.isNotEmpty
            ? json.decode(response.body)
            : {'message': 'Unknown error'};
        throw Exception(
            error['message'] ?? 'Failed to load transactions. Status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: ${e.toString()}';
      });
      _showErrorDialog(_errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  List<Transaction> _getPaginatedTransactions() {
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    return _allTransactions.sublist(
      startIndex.clamp(0, _allTransactions.length),
      endIndex.clamp(0, _allTransactions.length),
    );
  }

  Future<void> _selectDate(BuildContext context, {required bool isFromDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _fromDate : _toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue[700]!,
              onPrimary: Colors.white,
              onSurface: Colors.blue[800]!,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue[700],
              ),
            ),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
        _currentPage = 1;
      });
      await _fetchTransactions();
      widget.onDateRangeChanged(_fromDate, _toDate);
    }
  }

  // Responsive column width calculation
  double _getColumnWidth(String columnName, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    
    // Define column widths based on screen size and orientation
    if (kIsWeb || screenWidth > 1200) {
      // Large screens (desktop/tablet landscape)
      switch (columnName) {
        case 'date':
          return 140;
        case 'user':
          return 150;
        case 'description':
          return 200;
        case 'amount':
          return 130;
        case 'debit':
          return 130;
        case 'credit':
          return 130;
        case 'balance':
          return 130;
        default:
          return 150;
      }
    } else if (screenWidth > 768) {
      // Medium screens (tablet portrait)
      switch (columnName) {
        case 'date':
          return isPortrait ? 120 : 130;
        case 'user':
          return isPortrait ? 120 : 130;
        case 'description':
          return isPortrait ? 180 : 200;
        case 'amount':
          return isPortrait ? 110 : 120;
        case 'debit':
          return isPortrait ? 110 : 120;
        case 'credit':
          return isPortrait ? 110 : 120;
        case 'balance':
          return isPortrait ? 110 : 120;
        default:
          return 120;
      }
    } else {
      // Small screens (mobile)
      switch (columnName) {
        case 'date':
          return isPortrait ? 100 : 110;
        case 'user':
          return isPortrait ? 90 : 100;
        case 'description':
          return isPortrait ? 150 : 160;
        case 'amount':
          return isPortrait ? 90 : 100;
        case 'debit':
          return isPortrait ? 90 : 100;
        case 'credit':
          return isPortrait ? 90 : 100;
        case 'balance':
          return isPortrait ? 90 : 100;
        default:
          return 100;
      }
    }
  }

  // Calculate total table width
  double _getTotalTableWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    
    if (kIsWeb || screenWidth > 1200) {
      return 140 + 150 + 200 + 130 + 130 + 130 + 130; // Sum of large screen widths
    } else if (screenWidth > 768) {
      if (isPortrait) {
        return 120 + 120 + 180 + 110 + 110 + 110 + 110; // Tablet portrait
      } else {
        return 130 + 130 + 200 + 120 + 120 + 120 + 120; // Tablet landscape
      }
    } else {
      if (isPortrait) {
        return 100 + 90 + 150 + 90 + 90 + 90 + 90; // Mobile portrait
      } else {
        return 110 + 100 + 160 + 100 + 100 + 100 + 100; // Mobile landscape
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMorePages = _allTransactions.length > _currentPage * _rowsPerPage;
    final screenWidth = MediaQuery.of(context).size.width;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'All Transactions',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue[800],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[900]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Controls
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDateFilter('From', _fromDate, true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateFilter('To', _toDate, false),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: screenWidth > 600 ? 160 : 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: DropdownButton<String>(
                          value: _selectedUser,
                          icon: Icon(Icons.arrow_drop_down, size: 20, color: Colors.blue[800]),
                          elevation: 8,
                          style: TextStyle(
                            color: Colors.blue[800], 
                            fontSize: screenWidth > 600 ? 13 : 12
                          ),
                          underline: const SizedBox(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedUser = newValue;
                                _currentPage = 1;
                              });
                              _fetchTransactions();
                              widget.onUserChanged(newValue);
                            }
                          },
                          items: ['All', ...widget.users.map((u) => u.name)]
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: TextStyle(fontSize: screenWidth > 600 ? 13 : 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Summary Cards - Responsive layout
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 600) {
                      // Horizontal layout for wider screens
                      return Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Total Debit',
                              _totalDebit,
                              const Color(0xFFDC2626),
                              Icons.arrow_upward,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSummaryCard(
                              'Total Credit',
                              _totalCredit,
                              const Color(0xFF059669),
                              Icons.arrow_downward,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSummaryCard(
                              'Balance',
                              _totalBalance,
                              _totalBalance >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              _totalBalance >= 0 ? Icons.account_balance_wallet : Icons.warning,
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Vertical layout for narrower screens
                      return Column(
                        children: [
                          _buildSummaryCard(
                            'Total Debit',
                            _totalDebit,
                            const Color(0xFFDC2626),
                            Icons.arrow_upward,
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryCard(
                            'Total Credit',
                            _totalCredit,
                            const Color(0xFF059669),
                            Icons.arrow_downward,
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryCard(
                            'Balance',
                            _totalBalance,
                            _totalBalance >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            _totalBalance >= 0 ? Icons.account_balance_wallet : Icons.warning,
                          ),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 40, color: Colors.red[400]),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                _errorMessage,
                                style: const TextStyle(color: Colors.red, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchTransactions,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _allTransactions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 48,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No transactions found',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            color: Colors.white,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final tableWidth = _getTotalTableWidth(context);
                                final availableWidth = constraints.maxWidth;
                                
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: availableWidth,
                                      maxWidth: tableWidth > availableWidth ? tableWidth : availableWidth,
                                    ),
                                  child: SfDataGrid(
  source: _transactionDataSource,
  columnWidthMode: ColumnWidthMode.none, // Changed from .fixed to .none
  gridLinesVisibility: GridLinesVisibility.both,
  headerGridLinesVisibility: GridLinesVisibility.both,
  headerRowHeight: screenWidth > 600 ? 56 : 50,
  rowHeight: screenWidth > 600 ? 56 : 48,
  allowSorting: true,
  columns: [
    GridColumn(
      columnName: 'date',
      width: _getColumnWidth('date', context),
      label: _buildColumnHeader('Date'),
    ),
    GridColumn(
      columnName: 'user',
      width: _getColumnWidth('user', context),
      label: _buildColumnHeader('User'),
    ),
    GridColumn(
      columnName: 'description',
      width: _getColumnWidth('description', context),
      label: _buildColumnHeader('Description'),
    ),
    GridColumn(
      columnName: 'amount',
      width: _getColumnWidth('amount', context),
      label: _buildColumnHeader('Amount'),
    ),
    GridColumn(
      columnName: 'debit',
      width: _getColumnWidth('debit', context),
      label: _buildColumnHeader('Debit'),
    ),
    GridColumn(
      columnName: 'credit',
      width: _getColumnWidth('credit', context),
      label: _buildColumnHeader('Credit'),
    ),
    GridColumn(
      columnName: 'balance',
      width: _getColumnWidth('balance', context),
      label: _buildColumnHeader('Balance'),
    ),
  ],
),
                                  ),
                                );
                              },
                            ),
                          ),
          ),

          // Footer with Pagination
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth > 600 ? 16 : 12, 
              vertical: screenWidth > 600 ? 12 : 8
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              children: [
                // Mobile layout for small screens
                if (screenWidth < 600) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Rows per page selector
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButton<int>(
                          value: _rowsPerPage,
                          icon: Icon(Icons.arrow_drop_down, size: 16, color: Colors.blue[800]),
                          elevation: 8,
                          style: TextStyle(color: Colors.blue[800], fontSize: 12),
                          underline: const SizedBox(),
                          onChanged: (int? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _rowsPerPage = newValue;
                                _currentPage = 1;
                                _transactionDataSource =
                                    TransactionDataSource(transactions: _getPaginatedTransactions());
                              });
                            }
                          },
                          items: _rowsPerPageOptions
                              .map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(value.toString(), style: const TextStyle(fontSize: 12)),
                            );
                          }).toList(),
                        ),
                      ),

                      // Total records
                      Text(
                        'Total: ${_allTransactions.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Desktop layout for wider screens
                    if (screenWidth >= 600) ...[
                      Row(
                        children: [
                          Text(
                            'Show:',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DropdownButton<int>(
                              value: _rowsPerPage,
                              icon: Icon(Icons.arrow_drop_down, size: 16, color: Colors.blue[800]),
                              elevation: 8,
                              style: TextStyle(color: Colors.blue[800], fontSize: 12),
                              underline: const SizedBox(),
                              onChanged: (int? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _rowsPerPage = newValue;
                                    _currentPage = 1;
                                    _transactionDataSource =
                                        TransactionDataSource(transactions: _getPaginatedTransactions());
                                  });
                                }
                              },
                              items: _rowsPerPageOptions
                                  .map<DropdownMenuItem<int>>((int value) {
                                return DropdownMenuItem<int>(
                                  value: value,
                                  child: Text(value.toString(), style: const TextStyle(fontSize: 12)),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'entries',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],

                    // Pagination controls
                    Row(
                      children: [
                        if (screenWidth >= 600) ...[
                          Text(
                            'Page $_currentPage of ${(_allTransactions.length / _rowsPerPage).ceil()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Container(
                          width: screenWidth > 600 ? 32 : 30,
                          height: screenWidth > 600 ? 32 : 30,
                          decoration: BoxDecoration(
                            color: _currentPage == 1 ? Colors.grey[200] : Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.chevron_left,
                              size: screenWidth > 600 ? 16 : 14,
                              color: _currentPage == 1 ? Colors.grey[400] : Colors.blue[700],
                            ),
                            onPressed: _currentPage == 1
                                ? null
                                : () {
                                    setState(() {
                                      _currentPage--;
                                      _transactionDataSource = TransactionDataSource(
                                          transactions: _getPaginatedTransactions());
                                    });
                                  },
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: screenWidth > 600 ? 32 : 30,
                          height: screenWidth > 600 ? 32 : 30,
                          decoration: BoxDecoration(
                            color: !hasMorePages ? Colors.grey[200] : Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.chevron_right,
                              size: screenWidth > 600 ? 16 : 14,
                              color: !hasMorePages ? Colors.grey[400] : Colors.blue[700],
                            ),
                            onPressed: !hasMorePages
                                ? null
                                : () {
                                    setState(() {
                                      _currentPage++;
                                      _transactionDataSource = TransactionDataSource(
                                          transactions: _getPaginatedTransactions());
                                    });
                                  },
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),

                    // Total records (desktop)
                    if (screenWidth >= 600) ...[
                      Text(
                        'Total: ${_allTransactions.length} records',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter(String label, DateTime date, bool isFromDate) {
    return InkWell(
      onTap: () => _selectDate(context, isFromDate: isFromDate),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12, 
          vertical: MediaQuery.of(context).size.width > 600 ? 10 : 8
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today, 
              size: MediaQuery.of(context).size.width > 600 ? 16 : 14, 
              color: Colors.blue[700]
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width > 600 ? 10 : 9,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    DateFormat('MMM dd, yyyy').format(date),
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width > 600 ? 12 : 11,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width > 600 ? 12 : 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: MediaQuery.of(context).size.width > 600 ? 36 : 32,
            height: MediaQuery.of(context).size.width > 600 ? 36 : 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: MediaQuery.of(context).size.width > 600 ? 18 : 16,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width > 600 ? 10 : 9,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _currencyFormat.format(amount),
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width > 600 ? 16 : 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeader(String title) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? 12 : 8, 
        vertical: screenWidth > 600 ? 8 : 6
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: screenWidth > 600 ? 12 : 11,
          color: const Color.fromARGB(255, 23, 109, 207),
        ),
      ),
    );
  }
}