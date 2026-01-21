import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:resturant/AddCustomerScreen.dart';
import 'package:resturant/AddSupplierScreen.dart';
import 'package:resturant/AddUserScreen.dart';
import 'package:resturant/ApiConstants.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;


// Color Constants
// =============================
const Color primaryColor = Color(0xFF4F46E5);
const Color secondaryColor = Color(0xFFF8FAFC);
const Color cardColor = Colors.white;
const Color textPrimary = Color(0xFF1F2937);
const Color textSecondary = Color(0xFF6B7280);
const Color successColor = Color(0xFF10B981);
const Color warningColor = Color(0xFFF59E0B);
const Color errorColor = Color(0xFFEF4444);
const Color infoColor = Color(0xFF3B82F6);

// Models
// =============================
class Bank {
  final int? id;
  final String code;
  final String name;
  final String branch;
  final String accountType;
  final String accountNo;
  final DateTime? createdAt;

  Bank({
    this.id,
    required this.code,
    required this.name,
    required this.branch,
    required this.accountType,
    required this.accountNo,
    this.createdAt,
  });

  factory Bank.fromJson(Map<String, dynamic> json) {
    return Bank(
      id: json['id'],
      code: json['bank_code'] ?? '',
      name: json['bank_name'] ?? '',
      branch: json['branch'] ?? '',
      accountType: json['account_type'] ?? '',
      accountNo: json['account_no'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}

class Table {
  final int id;
  final String name;
  final double? serviceCharge;
  final DateTime createdAt;
  final DateTime updatedAt;

  Table({
    required this.id,
    required this.name,
    this.serviceCharge,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Table.fromJson(Map<String, dynamic> json) {
    return Table(
      id: json['id'],
      name: json['name'],
      serviceCharge: json['service_charge'] != null ? double.tryParse(json['service_charge'].toString()) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class Waiter {
  final int id;
  final String name;
  final String nic;
  final String phone;
  final String address;
  final DateTime bday;
  final DateTime createdAt;
  final DateTime updatedAt;

  Waiter({
    required this.id,
    required this.name,
    required this.nic,
    required this.phone,
    required this.address,
    required this.bday,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Waiter.fromJson(Map<String, dynamic> json) {
    return Waiter(
      id: json['id'] as int,
      name: json['name'] as String,
      nic: json['nic'] as String,
      phone: json['phone'] as String,
      address: json['address'] as String,
      bday: DateTime.parse(json['bday'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'nic': nic,
      'phone': phone,
      'address': address,
      'bday': DateFormat('yyyy-MM-dd').format(bday),
    };
  }
}

// API Service Helper
// =============================
class ApiService {
  static Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Referer': ApiConstants.refererHeader,
    };
  }

  static Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (_) {
      return null;
    }
  }

  static Future<http.Response> getRequest(String endpoint) async {
    final headers = await getHeaders();
    return await http.get(
      Uri.parse(ApiConstants.getFullUrl(endpoint)),
      headers: headers,
    ).timeout(const Duration(seconds: 10));
  }

  static Future<http.Response> postRequest(String endpoint, Map<String, dynamic> body) async {
    final headers = await getHeaders();
    return await http.post(
      Uri.parse(ApiConstants.getFullUrl(endpoint)),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));
  }

  static Future<http.Response> putRequest(String endpoint, Map<String, dynamic> body) async {
    final headers = await getHeaders();
    return await http.put(
      Uri.parse(ApiConstants.getFullUrl(endpoint)),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));
  }

  static Future<http.Response> deleteRequest(String endpoint) async {
    final headers = await getHeaders();
    return await http.delete(
      Uri.parse(ApiConstants.getFullUrl(endpoint)),
      headers: headers,
    ).timeout(const Duration(seconds: 10));
  }
}

// Profile Screen
// =============================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;
    
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 227, 243, 243),
                Color.fromARGB(255, 241, 241, 245),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: AppBar(
            title: Text(
              'Profile Options',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            elevation: 0,
            centerTitle: true,
            scrolledUnderElevation: 2,
            backgroundColor: Colors.transparent,
            shadowColor: colors.shadow.withOpacity(0.3),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _buildSectionHeader(
                    context,
                    title: 'Create New',
                    subtitle: 'Add new entities to your system',
                  ),
                  const SizedBox(height: 16),
                  _buildProfileOption(
                    context,
                    title: 'New Supplier',
                    icon: Icons.storefront_rounded,
                    description: 'Add new supplier to your system',
                    color: colors.primary,
                    onTap: () => _navigateWithFeedback(
                      context,
                      const AddSupplierScreen(),
                      'Supplier added successfully',
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
                  const SizedBox(height: 12),
                  _buildProfileOption(
                    context,
                    title: 'New Customer',
                    icon: Icons.person_add_alt_1_rounded,
                    description: 'Register new customer account',
                    color: colors.secondary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddCustomerScreen(),
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                  const SizedBox(height: 12),
                  _buildProfileOption(
                    context,
                    title: 'User Account',
                    icon: Icons.person_2_rounded,
                    description: 'Create new user account',
                    color: colors.tertiary,
                    onTap: () => _handleUserAccountNavigation(context),
                  ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),
                  const SizedBox(height: 12),
                  _buildProfileOption(
                    context,
                    title: 'Bank List',
                    icon: Icons.account_balance_rounded,
                    description: 'Manage bank accounts',
                    color: colors.secondary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BankListScreen(),
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                  const SizedBox(height: 12),
                  _buildProfileOption(
                    context,
                    title: 'Table',
                    icon: Icons.table_restaurant_rounded,
                    description: 'Manage restaurant tables',
                    color: colors.secondary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TableManagementScreen(),
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                  const SizedBox(height: 12),
                  _buildProfileOption(
                    context,
                    title: 'Waiters',
                    icon: Icons.person_rounded,
                    description: 'Manage waiter staff',
                    color: colors.secondary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WaiterManagementScreen(),
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                  const SizedBox(height: 32),
                  _buildSectionHeader(
                    context,
                    title: 'Services',
                    subtitle: 'Manage your service offerings',
                  ),
                  const SizedBox(height: 16),
                  _buildProfileOption(
                    context,
                    title: 'Service List',
                    icon: Icons.ballot_rounded,
                    description: 'View all available services',
                    color: colors.primaryContainer,
                    onTap: () => _showSnackbar(
                      context,
                      'Service List selected',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.25,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateWithFeedback(
    BuildContext context,
    Widget page,
    String successMessage,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    ).then((_) {
      _showSnackbar(context, successMessage);
    });
  }

  void _handleUserAccountNavigation(BuildContext context) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AddUserScreen(),
        ),
      );
    } catch (e) {
      _showErrorSnackbar(context, 'Error: ${e.toString()}');
    }
  }

  void _showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 2,
      ),
    );
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 2,
      ),
    );
  }
}

// Bank List Screen
// =============================
class BankListScreen extends StatefulWidget {
  const BankListScreen({super.key});

  @override
  State<BankListScreen> createState() => _BankListScreenState();
}

class _BankListScreenState extends State<BankListScreen> {
  List<Bank> _banks = [];
  List<Bank> _filteredBanks = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  bool _isAuthenticated = false;
  bool _hasMoreData = true;
  int _currentPage = 1;
  final int _perPage = 10;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _accountNoController = TextEditingController();

  String? _selectedAccountType;
  final List<String> _accountTypes = ['Current', 'Saving'];
  bool _showAddForm = false;
  Bank? _editingBank;

  @override
  void initState() {
    super.initState();
    _checkAuthAndFetchBanks();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _branchController.dispose();
    _accountNoController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreBanks();
    }
  }

  Future<void> _checkAuthAndFetchBanks() async {
    final token = await ApiService.getAuthToken();

    if (token == null || token.isEmpty) {
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
        _errorMessage = 'Authentication required. Please login again.';
      });
      return;
    }

    await _fetchBanks(reset: true);
  }

  Future<void> _fetchBanks({bool reset = false}) async {
    if (reset) {
      setState(() {
        _currentPage = 1;
        _hasMoreData = true;
        _isLoading = true;
        _errorMessage = null;
        _banks.clear();
        _filteredBanks.clear();
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final response = await ApiService.getRequest(
        ApiConstants.bankListWithPagination(_currentPage, _perPage),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> bankData = data is Map && data['data'] is List
            ? data['data'] as List<dynamic>
            : data is List
                ? data
                : [];

        final totalItems = data is Map && data['total'] != null
            ? data['total'] as int
            : bankData.length;
        final totalPages = data is Map && data['last_page'] != null
            ? data['last_page'] as int
            : (totalItems / _perPage).ceil();

        setState(() {
          if (reset) {
            _banks = bankData.map((item) => Bank.fromJson(item)).toList();
          } else {
            _banks.addAll(bankData.map((item) => Bank.fromJson(item)).toList());
          }

          _filteredBanks = List.from(_banks);
          _isLoading = false;
          _isLoadingMore = false;
          _isAuthenticated = true;
          _hasMoreData = _currentPage < totalPages;
          if (_hasMoreData) _currentPage++;
        });

        _applyFilters();
      } else if (response.statusCode == 401) {
        final error = jsonDecode(response.body);
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _isAuthenticated = false;
          _errorMessage =
              error['message'] ?? 'Authentication failed. Please login again.';
        });
      } else {
        throw Exception('Failed to load banks. Status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = 'Failed to load banks: ${e.toString()}';
      });
    }
  }

  Future<void> _loadMoreBanks() async {
    if (!_hasMoreData) return;
    await _fetchBanks();
  }

  Future<void> _saveBank() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final requestBody = jsonEncode({
        'bankCode': _codeController.text,
        'bankName': _nameController.text,
        'branch': _branchController.text,
        'accountType': _selectedAccountType,
        'accountNo': _accountNoController.text,
      });

      http.Response response;
      
      if (_editingBank == null) {
        // Create new bank
        response = await ApiService.postRequest(
          ApiConstants.bankList,
          jsonDecode(requestBody),
        );
      } else {
        // Update existing bank
        response = await ApiService.putRequest(
          ApiConstants.bankListById(_editingBank!.id!),
          jsonDecode(requestBody),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true ||
            responseData['id'] != null ||
            response.statusCode == 201) {
          await _fetchBanks(reset: true);
          _clearForm();
          setState(() {
            _showAddForm = false;
            _editingBank = null;
          });

          _showSuccessDialog(_editingBank == null
              ? 'Bank added successfully'
              : 'Bank updated successfully');
        } else {
          throw Exception(responseData['message'] ?? 'Failed to save bank');
        }
      } else if (response.statusCode == 401) {
        final error = jsonDecode(response.body);
        setState(() {
          _isLoading = false;
          _isAuthenticated = false;
          _errorMessage =
              error['message'] ?? 'Authentication failed. Please login again.';
        });
      } else if (response.statusCode == 422) {
        final error = jsonDecode(response.body);
        final errors = error['errors'] as Map<String, dynamic>;
        final errorMessages = errors.entries
            .map((e) => '${e.key}: ${(e.value as List).join(', ')}')
            .join('\n');
        setState(() {
          _isLoading = false;
          _errorMessage =
              error['message'] ?? 'Validation failed:\n$errorMessages';
        });
      } else {
        final error = jsonDecode(response.body);
        throw Exception(
            error['message'] ?? 'Failed to save bank. Status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save bank: ${e.toString()}';
      });

      _showSnackBar('Error: ${e.toString()}', isError: true);
    }
  }

  Future<void> _deleteBank(int id) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.deleteRequest(
        ApiConstants.bankListById(id),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _fetchBanks(reset: true);
        _showSnackBar('Bank deleted successfully', isError: false);
      } else if (response.statusCode == 401) {
        final error = jsonDecode(response.body);
        setState(() {
          _isLoading = false;
          _isAuthenticated = false;
          _errorMessage =
              error['message'] ?? 'Authentication failed. Please login again.';
        });
      } else {
        final error = jsonDecode(response.body);
        throw Exception(
            error['message'] ?? 'Failed to delete bank. Status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to delete bank: ${e.toString()}';
      });

      _showSnackBar('Error: ${e.toString()}', isError: true);
    }
  }

  void _editBank(Bank bank) {
    setState(() {
      _editingBank = bank;
      _codeController.text = bank.code;
      _nameController.text = bank.name;
      _branchController.text = bank.branch;
      _selectedAccountType = bank.accountType;
      _accountNoController.text = bank.accountNo;
      _showAddForm = true;
    });
  }

  void _clearForm() {
    _codeController.clear();
    _nameController.clear();
    _branchController.clear();
    _selectedAccountType = null;
    _accountNoController.clear();
    _editingBank = null;
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? errorColor : successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: successColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 50,
                    color: successColor,
                  ),
                ).animate().fadeIn(duration: 250.ms).scale(duration: 350.ms),
                const SizedBox(height: 16),
                Text(
                  'Success',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Continue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBankDetails(Bank bank) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bank Details',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ).animate().fadeIn(duration: 250.ms),
                const SizedBox(height: 16),
                _buildDetailRow('Bank Code', bank.code),
                _buildDetailRow('Bank Name', bank.name),
                _buildDetailRow('Branch', bank.branch),
                _buildDetailRow('Account Type', bank.accountType),
                _buildDetailRow('Account No', bank.accountNo),
                if (bank.createdAt != null) ...[
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey.shade300, height: 1),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                      'Created At',
                      bank.createdAt != null
                          ? '${bank.createdAt!.toLocal().day}/${bank.createdAt!.toLocal().month}/${bank.createdAt!.toLocal().year} ${bank.createdAt!.toLocal().hour}:${bank.createdAt!.toLocal().minute.toString().padLeft(2, '0')}'
                          : 'N/A'),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _editBank(bank);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: errorColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Authentication Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Please login again to access bank details',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _checkAuthAndFetchBanks();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required FocusNode focusNode,
  }) {
    final isFocused = focusNode.hasFocus;

    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(color: textSecondary.withOpacity(0.65), fontSize: 14),
      prefixIcon:
          Icon(icon, color: isFocused ? primaryColor : textSecondary, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    );
  }

  Widget _buildBankForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: cardColor,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _editingBank == null ? 'Add New Bank' : 'Edit Bank',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: Colors.grey.shade600, size: 22),
                    onPressed: () {
                      setState(() {
                        _showAddForm = false;
                        _clearForm();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Bank Information',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _codeController,
                decoration: _inputDecoration(
                  hint: 'Enter bank code',
                  icon: Icons.code,
                  focusNode: FocusNode(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Bank Code is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration(
                  hint: 'Enter bank name',
                  icon: Icons.account_balance,
                  focusNode: FocusNode(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Bank Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _branchController,
                decoration: _inputDecoration(
                  hint: 'Enter branch',
                  icon: Icons.location_city,
                  focusNode: FocusNode(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Branch is required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedAccountType,
                decoration: _inputDecoration(
                  hint: 'Select account type',
                  icon: Icons.credit_card,
                  focusNode: FocusNode(),
                ),
                items: _accountTypes.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value,
                        style: const TextStyle(color: textPrimary)),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedAccountType = newValue;
                  });
                },
                validator: (value) =>
                    value == null ? 'Account Type is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accountNoController,
                decoration: _inputDecoration(
                  hint: 'Enter account number',
                  icon: Icons.numbers,
                  focusNode: FocusNode(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Account No is required' : null,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveBank,
                  icon: Icon(
                    _editingBank == null ? Icons.save_rounded : Icons.update_rounded,
                    size: 18,
                  ),
                  label: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _editingBank == null
                              ? 'SAVE BANK'
                              : 'UPDATE BANK',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBankCard(Bank bank) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showBankDetails(bank),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Accent bar
              Container(
                width: 3,
                height: 50,
                margin: const EdgeInsets.only(right: 12, top: 2),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bank name and code
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            bank.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            bank.code,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Account number
                    Row(
                      children: [
                        const Icon(
                          Icons.credit_card,
                          size: 14,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            bank.accountNo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Branch and account type
                    Row(
                      children: [
                        const Icon(
                          Icons.location_city,
                          size: 14,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${bank.branch} • ${bank.accountType}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: Colors.grey.shade700,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'view':
                      _showBankDetails(bank);
                      break;
                    case 'edit':
                      _editBank(bank);
                      break;
                    case 'delete':
                      _showDeleteConfirmation(bank);
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'view', child: Text('View Details')),
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: errorColor),
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

  void _showDeleteConfirmation(Bank bank) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: errorColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    size: 32,
                    color: errorColor,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Confirm Delete',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete ${bank.name}?',
                  style: const TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteBank(bank.id!);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: errorColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Banks Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first bank to get started',
              style: TextStyle(
                fontSize: 14,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showAddForm = true;
                });
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Bank'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: TextFormField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search banks...',
          hintStyle: TextStyle(color: textSecondary.withOpacity(0.65)),
          prefixIcon: const Icon(Icons.search_rounded, color: textSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
        ),
        onChanged: (value) => _applyFilters(),
      ),
    );
  }

  void _applyFilters() {
    final searchTerm = _searchController.text.toLowerCase();

    setState(() {
      _filteredBanks = _banks.where((bank) {
        return bank.name.toLowerCase().contains(searchTerm) ||
            bank.code.toLowerCase().contains(searchTerm) ||
            bank.accountNo.toLowerCase().contains(searchTerm) ||
            bank.branch.toLowerCase().contains(searchTerm) ||
            bank.accountType.toLowerCase().contains(searchTerm);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        title: const Text(
          'Bank Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isAuthenticated && !_showAddForm && _filteredBanks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: () {
                setState(() {
                  _showAddForm = true;
                  _clearForm();
                });
              },
              tooltip: 'Add Bank',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 2.5,
              ),
            )
          : _isAuthenticated
              ? _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: errorColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _fetchBanks(reset: true),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _fetchBanks(reset: true),
                      color: primaryColor,
                      child: CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          if (_showAddForm)
                            SliverToBoxAdapter(
                              child: _buildBankForm(),
                            ),
                          if (!_showAddForm)
                            SliverToBoxAdapter(
                              child: _buildSearchBar(),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.only(bottom: 16),
                            sliver: _filteredBanks.isEmpty && !_showAddForm
                                ? SliverFillRemaining(
                                    child: _buildEmptyState(),
                                  )
                                : SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        if (index == _filteredBanks.length) {
                                          return _isLoadingMore
                                              ? const Padding(
                                                  padding: EdgeInsets.all(16),
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      color: primaryColor,
                                                      strokeWidth: 2.5,
                                                    ),
                                                  ),
                                                )
                                              : _hasMoreData
                                                  ? Container()
                                                  : const Padding(
                                                      padding:
                                                          EdgeInsets.all(16),
                                                      child: Center(
                                                        child: Text(
                                                          'No more banks to load',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: textSecondary,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                        }
                                        return _buildBankCard(
                                            _filteredBanks[index]);
                                      },
                                      childCount: _filteredBanks.length +
                                          (_hasMoreData ? 1 : 0),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    )
              : _buildAuthError(),
      floatingActionButton: _isAuthenticated &&
              !_showAddForm &&
              _filteredBanks.isNotEmpty &&
              MediaQuery.of(context).viewInsets.bottom == 0
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _showAddForm = true;
                  _clearForm();
                });
              },
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}

// Table Management Screen
// =============================
class TableManagementScreen extends StatefulWidget {
  const TableManagementScreen({super.key});

  @override
  _TableManagementScreenState createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController serviceChargeController = TextEditingController();

  bool _isLoading = false;
  bool _viewingTables = false;
  int? _editingId;

  List<Table> _tables = [];

  static const double _formMaxWidth = 640;
  static const double _listMaxWidth = 980;

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _serviceChargeFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_onFocusChange);
    _serviceChargeFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    nameController.dispose();
    serviceChargeController.dispose();
    _nameFocus.dispose();
    _serviceChargeFocus.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? errorColor : successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _fetchTables() async {
    setState(() {
      _isLoading = true;
      _tables = [];
    });

    try {
      final token = await ApiService.getAuthToken();
      if (token == null) {
        _showSnackBar('Authentication required. Please login again.');
        return;
      }

      final response = await ApiService.getRequest(ApiConstants.getTables);

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        List<dynamic> tables;
        if (data is List) {
          tables = data;
        } else if (data is Map && data['data'] is List) {
          tables = data['data'] as List<dynamic>;
        } else {
          throw Exception('Unexpected data format received');
        }

        setState(() {
          _tables = tables.map((json) => Table.fromJson(json)).toList();
          _viewingTables = true;
        });
      } else {
        String errorMsg = 'Failed to fetch tables (${response.statusCode})';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] is String) {
            errorMsg = decoded['message'] as String;
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      _showSnackBar('Failed to load tables: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteTable(int id) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.deleteRequest(ApiConstants.tableById(id));

      if (response.statusCode == 200) {
        _showSnackBar('Table deleted successfully', isError: false);
        await _fetchTables();
      } else {
        String errorMsg = 'Failed to delete table';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] is String) {
            errorMsg = decoded['message'] as String;
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showDeleteConfirmation(int id) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Confirm Delete',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Are you sure you want to delete this table?',
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteTable(id);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: errorColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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

  Future<void> _saveTable() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await ApiService.getAuthToken();
      if (token == null) {
        _showSnackBar('Authentication required. Please login again.');
        return;
      }

      final Map<String, dynamic> body = {
        'name': nameController.text.trim(),
        'service_charge': serviceChargeController.text.trim().isNotEmpty ? serviceChargeController.text.trim() : null,
      };

      http.Response response;
      
      if (_editingId != null) {
        // Update existing table
        response = await ApiService.putRequest(
          ApiConstants.tableById(_editingId!),
          body,
        );
      } else {
        // Create new table
        response = await ApiService.postRequest(
          ApiConstants.getTables,
          body,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _resetForm();
        _showSuccessDialog(_editingId != null);
        await _fetchTables();
      } else {
        String errorMsg = _editingId != null ? 'Failed to update table' : 'Failed to save table';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] is String) {
            errorMsg = decoded['message'] as String;
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog(bool isUpdate) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: successColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 50,
                    color: successColor,
                  ),
                ).animate().fadeIn(duration: 250.ms).scale(duration: 350.ms),
                const SizedBox(height: 16),
                Text(
                  isUpdate ? 'Table Updated' : 'Table Added',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 8),
                Text(
                  isUpdate 
                    ? 'Table has been updated successfully.'
                    : 'Table has been added successfully.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Continue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTableDetails(Table table) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Table Details',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('ID', table.id.toString()),
                  _buildDetailRow('Name', table.name),
                  _buildDetailRow('Service Charge', 
                    table.serviceCharge != null ? '${table.serviceCharge}%' : 'Not set'),
                  _buildDetailRow('Created', DateFormat('MMM dd, yyyy').format(table.createdAt)),
                  _buildDetailRow('Updated', DateFormat('MMM dd, yyyy').format(table.updatedAt)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    FocusNode? focusNode,
    Widget? suffixIcon,
  }) {
    final bool focused = focusNode?.hasFocus ?? false;

    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(color: textSecondary.withOpacity(0.65), fontSize: 14),
      prefixIcon: Icon(icon,
          color: focused ? primaryColor : textSecondary, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    );
  }

  void _editTable(Table table) {
    setState(() {
      _editingId = table.id;
      nameController.text = table.name;
      serviceChargeController.text = table.serviceCharge?.toString() ?? '';
      _viewingTables = false;
    });
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      nameController.clear();
      serviceChargeController.clear();
    });
    _formKey.currentState?.reset();
  }

  Widget _buildTableCards() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(
            color: primaryColor,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (_tables.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Text(
            'No tables found',
            style: TextStyle(fontSize: 13, color: textSecondary),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _tables.length,
        separatorBuilder: (_, __) => Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: Colors.grey.shade300,
        ),
        itemBuilder: (context, index) {
          final table = _tables[index];

          return InkWell(
            onTap: () => _showTableDetails(table),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Accent bar
                  Container(
                    width: 3,
                    height: 40,
                    margin: const EdgeInsets.only(right: 10, top: 2),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Table Name
                        Text(
                          table.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),

                        const SizedBox(height: 3),

                        // Table ID
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12.5),
                            children: [
                              const TextSpan(
                                text: 'ID: ',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextSpan(
                                text: table.id.toString(),
                                style: const TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 1),

                        // Service Charge
                        if (table.serviceCharge != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.percent,
                                size: 13,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Service Charge: ${table.serviceCharge}%',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Created Date
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      DateFormat('MMM dd').format(table.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),

                  // Actions
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: Colors.grey.shade700,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'view':
                          _showTableDetails(table);
                          break;
                        case 'edit':
                          _editTable(table);
                          break;
                        case 'delete':
                          _showDeleteConfirmation(table.id);
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'view', child: Text('View')),
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: errorColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title =
        _viewingTables ? 'View Tables' : (_editingId != null ? 'Edit Table' : 'Add New Table');

    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (_viewingTables) {
              setState(() {
                _viewingTables = false;
              });
            } else if (_editingId != null) {
              _resetForm();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_viewingTables)
            IconButton(
              onPressed: _fetchTables,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Refresh',
            )
          else if (_editingId != null)
            IconButton(
              icon: const Icon(Icons.clear_all_rounded, color: Colors.white),
              onPressed: _resetForm,
              tooltip: 'Clear Form',
            )
          else
            IconButton(
              icon: const Icon(Icons.list_rounded, color: Colors.white),
              onPressed: _fetchTables,
              tooltip: 'View Tables',
            ),
        ],
      ),
      body: SafeArea(
        child: _viewingTables
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _listMaxWidth),
                    child: RefreshIndicator(
                      onRefresh: _fetchTables,
                      color: primaryColor,
                      child: ListView(
                        children: [
                          _buildTableCards(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _formMaxWidth),
                    child: Form(
                      key: _formKey,
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: cardColor,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _editingId != null ? 'Edit Table' : 'Add New Table',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              )
                                  .animate()
                                  .fadeIn(duration: 250.ms)
                                  .slideY(begin: 0.08, end: 0),
                              const SizedBox(height: 4),
                              Text(
                                _editingId != null 
                                  ? 'Update the table details below'
                                  : 'Fill in the details below to add a new table',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: textSecondary,
                                ),
                              )
                                  .animate()
                                  .fadeIn(duration: 250.ms)
                                  .slideY(begin: 0.08, end: 0),
                              const SizedBox(height: 20),

                              _buildLabeledField(
                                label: 'Table Name *',
                                child: TextFormField(
                                  controller: nameController,
                                  focusNode: _nameFocus,
                                  style: const TextStyle(
                                      fontSize: 14, color: textPrimary),
                                  decoration: _inputDecoration(
                                    hint: 'Enter table name',
                                    icon: Icons.table_restaurant_outlined,
                                    focusNode: _nameFocus,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Table name is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              _buildLabeledField(
                                label: 'Service Charge (%)',
                                child: TextFormField(
                                  controller: serviceChargeController,
                                  focusNode: _serviceChargeFocus,
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                  ],
                                  style: const TextStyle(
                                      fontSize: 14, color: textPrimary),
                                  decoration: _inputDecoration(
                                    hint: 'Enter service charge percentage (optional)',
                                    icon: Icons.percent_outlined,
                                    focusNode: _serviceChargeFocus,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isSmall = constraints.maxWidth < 420;

                                  final saveButton = SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          _isLoading ? null : _saveTable,
                                      icon: Icon(
                                        _editingId != null ? Icons.update_rounded : Icons.save_rounded,
                                        size: 18,
                                      ),
                                      label: _isLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              _editingId != null ? 'Update Table' : 'Save Table',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  );

                                  final viewButton = SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          _isLoading ? null : _fetchTables,
                                      icon: const Icon(Icons.list_rounded,
                                          size: 18, color: primaryColor),
                                      label: const Text(
                                        'View Tables',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: primaryColor,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side:
                                            const BorderSide(color: primaryColor),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  );

                                  if (_editingId != null) {
                                    final cancelButton = SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: OutlinedButton.icon(
                                        onPressed: _isLoading ? null : _resetForm,
                                        icon: const Icon(Icons.close_rounded,
                                            size: 18, color: textSecondary),
                                        label: const Text(
                                          'Cancel',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: textSecondary,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Colors.grey.shade400),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    );

                                    if (isSmall) {
                                      return Column(
                                        children: [
                                          saveButton,
                                          const SizedBox(height: 12),
                                          cancelButton,
                                        ],
                                      );
                                    }

                                    return Row(
                                      children: [
                                        Expanded(child: saveButton),
                                        const SizedBox(width: 12),
                                        Expanded(child: cancelButton),
                                      ],
                                    );
                                  }

                                  if (isSmall) {
                                    return Column(
                                      children: [
                                        saveButton,
                                        const SizedBox(height: 12),
                                        viewButton,
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(child: saveButton),
                                      const SizedBox(width: 12),
                                      Expanded(child: viewButton),
                                    ],
                                  );
                                },
                              ).animate().fadeIn(delay: 120.ms).slideY(
                                      begin: 0.12, end: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

// Waiter Management Screen
// =============================
class WaiterManagementScreen extends StatefulWidget {
  const WaiterManagementScreen({super.key});

  @override
  _WaiterManagementScreenState createState() => _WaiterManagementScreenState();
}

class _WaiterManagementScreenState extends State<WaiterManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController nicController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController bdayController = TextEditingController();

  bool _isLoading = false;
  bool _viewingWaiters = false;
  int? _editingId;

  List<Waiter> _waiters = [];

  static const double _formMaxWidth = 640;
  static const double _listMaxWidth = 980;

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _nicFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _bdayFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_onFocusChange);
    _nicFocus.addListener(_onFocusChange);
    _phoneFocus.addListener(_onFocusChange);
    _addressFocus.addListener(_onFocusChange);
    _bdayFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    nameController.dispose();
    nicController.dispose();
    phoneController.dispose();
    addressController.dispose();
    bdayController.dispose();
    
    _nameFocus.dispose();
    _nicFocus.dispose();
    _phoneFocus.dispose();
    _addressFocus.dispose();
    _bdayFocus.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? errorColor : successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _fetchWaiters() async {
    setState(() {
      _isLoading = true;
      _waiters = [];
    });

    try {
      final token = await ApiService.getAuthToken();
      if (token == null) {
        _showSnackBar('Authentication required. Please login again.');
        return;
      }

      final response = await ApiService.getRequest(ApiConstants.getWaiters);

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        List<dynamic> waiters;
        if (data is List) {
          waiters = data;
        } else if (data is Map && data['data'] is List) {
          waiters = data['data'] as List<dynamic>;
        } else if (data is Map && data['waiters'] is List) {
          waiters = data['waiters'] as List<dynamic>;
        } else {
          throw Exception('Unexpected data format received');
        }

        setState(() {
          _waiters = waiters.map((json) => Waiter.fromJson(json)).toList();
          _viewingWaiters = true;
        });
      } else {
        String errorMsg = 'Failed to fetch waiters (${response.statusCode})';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] is String) {
            errorMsg = decoded['message'] as String;
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      _showSnackBar('Failed to load waiters: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteWaiter(int id) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.deleteRequest(ApiConstants.waiterById(id));

      if (response.statusCode == 200) {
        _showSnackBar('Waiter deleted successfully', isError: false);
        await _fetchWaiters();
      } else {
        String errorMsg = 'Failed to delete waiter';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] is String) {
            errorMsg = decoded['message'] as String;
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showDeleteConfirmation(int id, String name) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Confirm Delete',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to delete waiter "$name"?',
                  style: const TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteWaiter(id);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: errorColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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

  Future<void> _saveWaiter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await ApiService.getAuthToken();
      if (token == null) {
        _showSnackBar('Authentication required. Please login again.');
        return;
      }

      final Map<String, dynamic> body = {
        'name': nameController.text.trim(),
        'nic': nicController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'bday': bdayController.text.trim(),
      };

      http.Response response;
      
      if (_editingId != null) {
        // Update existing waiter
        response = await ApiService.putRequest(
          ApiConstants.waiterById(_editingId!),
          body,
        );
      } else {
        // Create new waiter
        response = await ApiService.postRequest(
          ApiConstants.getWaiters,
          body,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData is Map && responseData['message'] != null) {
          _showSnackBar(responseData['message'] as String, isError: false);
        } else {
          _showSnackBar(
            _editingId != null ? 'Waiter updated successfully' : 'Waiter created successfully',
            isError: false,
          );
        }
        
        _resetForm();
        await _fetchWaiters();
      } else {
        String errorMsg = _editingId != null ? 'Failed to update waiter' : 'Failed to save waiter';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] is String) {
            errorMsg = decoded['message'] as String;
          } else if (decoded is Map && decoded['errors'] is Map) {
            final errors = decoded['errors'] as Map<String, dynamic>;
            errorMsg = errors.values.first?.first?.toString() ?? errorMsg;
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showWaiterDetails(Waiter waiter) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Waiter Details',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('ID', waiter.id.toString()),
                  _buildDetailRow('Name', waiter.name),
                  _buildDetailRow('NIC', waiter.nic),
                  _buildDetailRow('Phone', waiter.phone),
                  _buildDetailRow('Address', waiter.address),
                  _buildDetailRow('Birth Date', DateFormat('MMM dd, yyyy').format(waiter.bday)),
                  _buildDetailRow('Age', '${DateTime.now().difference(waiter.bday).inDays ~/ 365} years'),
                  _buildDetailRow('Created', DateFormat('MMM dd, yyyy - hh:mm a').format(waiter.createdAt)),
                  _buildDetailRow('Updated', DateFormat('MMM dd, yyyy - hh:mm a').format(waiter.updatedAt)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    FocusNode? focusNode,
    Widget? suffixIcon,
  }) {
    final bool focused = focusNode?.hasFocus ?? false;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: textSecondary.withOpacity(0.65), 
        fontSize: 14
      ),
      prefixIcon: Icon(
        icon,
        color: focused ? primaryColor : textSecondary, 
        size: 20
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    );
  }

  void _editWaiter(Waiter waiter) {
    setState(() {
      _editingId = waiter.id;
      nameController.text = waiter.name;
      nicController.text = waiter.nic;
      phoneController.text = waiter.phone;
      addressController.text = waiter.address;
      bdayController.text = DateFormat('yyyy-MM-dd').format(waiter.bday);
      _viewingWaiters = false;
    });
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      nameController.clear();
      nicController.clear();
      phoneController.clear();
      addressController.clear();
      bdayController.clear();
    });
    _formKey.currentState?.reset();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      bdayController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Widget _buildWaiterCards() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(
            color: primaryColor,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (_waiters.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 60,
                color: Color(0xFFCCCCCC),
              ),
              SizedBox(height: 12),
              Text(
                'No waiters found',
                style: TextStyle(fontSize: 14, color: textSecondary),
              ),
              SizedBox(height: 8),
              Text(
                'Add your first waiter to get started',
                style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _waiters.length,
        separatorBuilder: (_, __) => Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: Colors.grey.shade300,
        ),
        itemBuilder: (context, index) {
          final waiter = _waiters[index];
          final age = DateTime.now().difference(waiter.bday).inDays ~/ 365;

          return InkWell(
            onTap: () => _showWaiterDetails(waiter),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 10, top: 2),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      size: 22,
                      color: primaryColor.withOpacity(0.7),
                    ),
                  ),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Waiter Name
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                waiter.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$age yrs',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor.withOpacity(0.9),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 3),

                        // NIC
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12.5),
                            children: [
                              const TextSpan(
                                text: 'NIC: ',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextSpan(
                                text: waiter.nic,
                                style: const TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 1),

                        // Phone
                        Row(
                          children: [
                            const Icon(
                              Icons.phone,
                              size: 13,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                waiter.phone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Created Date
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      DateFormat('MMM dd').format(waiter.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),

                  // Actions
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: Colors.grey.shade700,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'view':
                          _showWaiterDetails(waiter);
                          break;
                        case 'edit':
                          _editWaiter(waiter);
                          break;
                        case 'delete':
                          _showDeleteConfirmation(waiter.id, waiter.name);
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'view', child: Text('View Details')),
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: errorColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title = _viewingWaiters 
      ? 'Waiters List' 
      : (_editingId != null ? 'Edit Waiter' : 'Add New Waiter');

    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (_viewingWaiters) {
              setState(() {
                _viewingWaiters = false;
              });
            } else if (_editingId != null) {
              _resetForm();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_viewingWaiters)
            IconButton(
              onPressed: _fetchWaiters,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Refresh',
            )
          else if (_editingId != null)
            IconButton(
              icon: const Icon(Icons.clear_all_rounded, color: Colors.white),
              onPressed: _resetForm,
              tooltip: 'Clear Form',
            )
          else
            IconButton(
              icon: const Icon(Icons.list_rounded, color: Colors.white),
              onPressed: _fetchWaiters,
              tooltip: 'View Waiters',
            ),
        ],
      ),
      body: SafeArea(
        child: _viewingWaiters
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _listMaxWidth),
                    child: RefreshIndicator(
                      onRefresh: _fetchWaiters,
                      color: primaryColor,
                      child: ListView(
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Waiters',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_waiters.length} waiter${_waiters.length != 1 ? 's' : ''}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _viewingWaiters = false;
                                      _resetForm();
                                    });
                                  },
                                  icon: const Icon(Icons.person_add_rounded, size: 16),
                                  label: const Text('Add Waiter'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          _buildWaiterCards(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _formMaxWidth),
                    child: Form(
                      key: _formKey,
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: cardColor,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _editingId != null ? 'Edit Waiter' : 'Add New Waiter',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              )
                                  .animate()
                                  .fadeIn(duration: 250.ms)
                                  .slideY(begin: 0.08, end: 0),
                              const SizedBox(height: 4),
                              Text(
                                _editingId != null 
                                  ? 'Update the waiter details below'
                                  : 'Fill in the details below to add a new waiter',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: textSecondary,
                                ),
                              )
                                  .animate()
                                  .fadeIn(duration: 250.ms)
                                  .slideY(begin: 0.08, end: 0),
                              const SizedBox(height: 20),

                              // Name Field
                              _buildLabeledField(
                                label: 'Full Name *',
                                child: TextFormField(
                                  controller: nameController,
                                  focusNode: _nameFocus,
                                  style: const TextStyle(
                                      fontSize: 14, color: textPrimary),
                                  decoration: _inputDecoration(
                                    hint: 'Enter waiter full name',
                                    icon: Icons.person_outline_rounded,
                                    focusNode: _nameFocus,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Name is required';
                                    }
                                    if (value.trim().length < 2) {
                                      return 'Name must be at least 2 characters';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // NIC Field
                              _buildLabeledField(
                                label: 'NIC *',
                                child: TextFormField(
                                  controller: nicController,
                                  focusNode: _nicFocus,
                                  style: const TextStyle(
                                      fontSize: 14, color: textPrimary),
                                  decoration: _inputDecoration(
                                    hint: 'Enter NIC number',
                                    icon: Icons.badge_outlined,
                                    focusNode: _nicFocus,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'NIC is required';
                                    }
                                    final nicPattern = RegExp(r'^(\d{9}[vVxX]|\d{12})$');
                                    if (!nicPattern.hasMatch(value.trim())) {
                                      return 'Enter a valid NIC number (e.g., 993026347V or 199930263447)';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Phone Field
                              _buildLabeledField(
                                label: 'Phone Number *',
                                child: TextFormField(
                                  controller: phoneController,
                                  focusNode: _phoneFocus,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  style: const TextStyle(
                                      fontSize: 14, color: textPrimary),
                                  decoration: _inputDecoration(
                                    hint: 'Enter phone number',
                                    icon: Icons.phone_outlined,
                                    focusNode: _phoneFocus,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Phone number is required';
                                    }
                                    if (value.trim().length < 9) {
                                      return 'Enter a valid phone number';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Birthday Field
                              _buildLabeledField(
                                label: 'Birth Date *',
                                child: TextFormField(
                                  controller: bdayController,
                                  focusNode: _bdayFocus,
                                  readOnly: true,
                                  style: const TextStyle(
                                      fontSize: 14, color: textPrimary),
                                  decoration: _inputDecoration(
                                    hint: 'Select birth date (YYYY-MM-DD)',
                                    icon: Icons.cake_outlined,
                                    focusNode: _bdayFocus,
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                                      onPressed: _selectDate,
                                      color: textSecondary,
                                    ),
                                  ),
                                  onTap: _selectDate,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Birth date is required';
                                    }
                                    try {
                                      final date = DateTime.parse(value.trim());
                                      if (date.isAfter(DateTime.now())) {
                                        return 'Birth date cannot be in the future';
                                      }
                                    } catch (e) {
                                      return 'Enter a valid date (YYYY-MM-DD)';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Address Field
                              _buildLabeledField(
                                label: 'Address *',
                                child: TextFormField(
                                  controller: addressController,
                                  focusNode: _addressFocus,
                                  maxLines: 3,
                                  style: const TextStyle(
                                      fontSize: 14, color: textPrimary),
                                  decoration: _inputDecoration(
                                    hint: 'Enter address',
                                    icon: Icons.location_on_outlined,
                                    focusNode: _addressFocus,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Address is required';
                                    }
                                    if (value.trim().length < 5) {
                                      return 'Address must be at least 5 characters';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Buttons Section
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isSmall = constraints.maxWidth < 420;

                                  final saveButton = SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      onPressed: _isLoading ? null : _saveWaiter,
                                      icon: Icon(
                                        _editingId != null 
                                          ? Icons.update_rounded 
                                          : Icons.save_rounded,
                                        size: 18,
                                      ),
                                      label: _isLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              _editingId != null 
                                                ? 'Update Waiter' 
                                                : 'Save Waiter',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  );

                                  final viewButton = SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: OutlinedButton.icon(
                                      onPressed: _isLoading ? null : _fetchWaiters,
                                      icon: const Icon(
                                        Icons.list_rounded,
                                        size: 18, 
                                        color: primaryColor,
                                      ),
                                      label: const Text(
                                        'View Waiters',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: primaryColor,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: primaryColor),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  );

                                  if (_editingId != null) {
                                    final cancelButton = SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: OutlinedButton.icon(
                                        onPressed: _isLoading ? null : _resetForm,
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 18, 
                                          color: textSecondary,
                                        ),
                                        label: const Text(
                                          'Cancel',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: textSecondary,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Colors.grey.shade400),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    );

                                    if (isSmall) {
                                      return Column(
                                        children: [
                                          saveButton,
                                          const SizedBox(height: 12),
                                          cancelButton,
                                        ],
                                      );
                                    }

                                    return Row(
                                      children: [
                                        Expanded(child: saveButton),
                                        const SizedBox(width: 12),
                                        Expanded(child: cancelButton),
                                      ],
                                    );
                                  }

                                  if (isSmall) {
                                    return Column(
                                      children: [
                                        saveButton,
                                        const SizedBox(height: 12),
                                        viewButton,
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(child: saveButton),
                                      const SizedBox(width: 12),
                                      Expanded(child: viewButton),
                                    ],
                                  );
                                },
                              ).animate().fadeIn(delay: 120.ms).slideY(
                                      begin: 0.12, end: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}