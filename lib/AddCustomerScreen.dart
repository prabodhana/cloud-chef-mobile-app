import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Match the InvoiceManagementScreen palette exactly
const Color primaryColor = Color(0xFF4F46E5);
const Color secondaryColor = Color(0xFFF8FAFC); // page background
const Color cardColor = Colors.white;
const Color textPrimary = Color(0xFF1F2937);
const Color textSecondary = Color(0xFF6B7280);
const Color successColor = Color(0xFF10B981);
const Color warningColor = Color(0xFFF59E0B);
const Color errorColor = Color(0xFFEF4444);
const Color infoColor = Color(0xFF3B82F6);

class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController nicController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController bdayController = TextEditingController();

  bool _isLoading = false;
  bool _viewingCustomers = false;

  List<dynamic> _customers = [];

  // Responsive max widths similar to invoice dialog constraints
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

  Future<String?> _getValidToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (_) {
      return null;
    }
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

  Future<void> _fetchCustomers() async {
    setState(() {
      _isLoading = true;
      _customers = [];
    });

    try {
      final token = await _getValidToken();
      if (token == null) {
        _showSnackBar('Authentication required. Please login again.');
        return;
      }

      final response = await http
          .get(
            Uri.parse('https://api-kafenio.sltcloud.lk/api/customers'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        List<dynamic> customers;
        if (data is List) {
          customers = data;
        } else if (data is Map && data['data'] is List) {
          customers = data['data'] as List<dynamic>;
        } else {
          throw Exception('Unexpected data format received');
        }

        setState(() {
          _customers = customers;
          _viewingCustomers = true;
        });
      } else {
        String errorMsg = 'Failed to fetch customers (${response.statusCode})';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] is String) {
            errorMsg = decoded['message'] as String;
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      _showSnackBar('Failed to load customers: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteCustomer(int id) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _getValidToken();
      if (token == null) {
        _showSnackBar('Authentication required. Please login again.');
        return;
      }

      final url =
          Uri.parse('https://api-kafenio.sltcloud.lk/api/customers/$id');
      final response = await http
          .delete(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar('Customer deleted successfully', isError: false);
        await _fetchCustomers();
      } else {
        String errorMsg = 'Failed to delete customer';
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
                  'Are you sure you want to delete this customer?',
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
                          _deleteCustomer(id);
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

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        // Keep it aligned with primaryColor usage in the app
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        bdayController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _getValidToken();
      if (token == null) {
        _showSnackBar('Authentication required. Please login again.');
        return;
      }

      final response = await http
          .post(
            Uri.parse('https://api-kafenio.sltcloud.lk/api/customers'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'name': nameController.text.trim(),
              'nic': nicController.text.trim(),
              'phone': phoneController.text.trim(),
              'address': addressController.text.trim(),
              'bday': bdayController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        nameController.clear();
        nicController.clear();
        phoneController.clear();
        addressController.clear();
        bdayController.clear();

        _showSuccessDialog();

        // Keep flow consistent: after saving, show customers list
        await _fetchCustomers();
      } else {
        String errorMsg = 'Failed to save customer';
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

  void _showSuccessDialog() {
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
                const Text(
                  'Customer Added',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 8),
                const Text(
                  'Customer has been added successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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

  void _showCustomerDetails(Map<String, dynamic> customer) {
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
                  const Text(
                    'Customer Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Name', (customer['name'] ?? 'N/A').toString()),
                  _buildDetailRow('NIC', (customer['nic'] ?? 'N/A').toString()),
                  _buildDetailRow(
                      'Phone', (customer['phone'] ?? 'N/A').toString()),
                  _buildDetailRow('Birthday',
                      (customer['bday'] ?? 'N/A').toString()),
                  _buildDetailRow(
                      'Address', (customer['address'] ?? 'N/A').toString()),
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
      // Match invoice surfaces: inputs on white (not tinted)
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

  // NEW: Card-based customer list view (similar to supplier screen)
  Widget _buildCustomerCards() {
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

    if (_customers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Text(
            'No customers found',
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
        itemCount: _customers.length,
        separatorBuilder: (_, __) => Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: Colors.grey.shade300,
        ),
        itemBuilder: (context, index) {
          final customer = Map<String, dynamic>.from(_customers[index]);
          final int id = (customer['id'] as num?)?.toInt() ?? 0;

          return InkWell(
            onTap: () => _showCustomerDetails(customer),
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
                        // Customer Name
                        Text(
                          (customer['name'] ?? 'N/A').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),

                        const SizedBox(height: 3),

                        // NIC (label + value inline)
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
                                text: (customer['nic'] ?? 'N/A').toString(),
                                style: const TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 1),

                        // Phone (strong + responsive)
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              size: 13,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                (customer['phone'] ?? 'N/A').toString(),
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

                  // Birthday (if available)
                  if ((customer['bday'] ?? '').toString().isNotEmpty)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (customer['bday'] ?? '').toString(),
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
                          _showCustomerDetails(customer);
                          break;
                        case 'edit':
                          setState(() {
                            _viewingCustomers = false;
                            nameController.text =
                                (customer['name'] ?? '').toString();
                            nicController.text =
                                (customer['nic'] ?? '').toString();
                            phoneController.text =
                                (customer['phone'] ?? '').toString();
                            addressController.text =
                                (customer['address'] ?? '').toString();
                            bdayController.text =
                                (customer['bday'] ?? '').toString();
                          });
                          break;
                        case 'delete':
                          if (id != 0) {
                            _showDeleteConfirmation(id);
                          }
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
        _viewingCustomers ? 'View Customers' : 'Add New Customer';

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
            if (_viewingCustomers) {
              setState(() {
                _viewingCustomers = false;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_viewingCustomers)
            IconButton(
              onPressed: _fetchCustomers,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Refresh',
            )
          else
            IconButton(
              icon: const Icon(Icons.list_rounded, color: Colors.white),
              onPressed: _fetchCustomers,
              tooltip: 'View Customers',
            ),
        ],
      ),
      body: SafeArea(
        child: _viewingCustomers
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _listMaxWidth),
                    child: RefreshIndicator(
                      onRefresh: _fetchCustomers,
                      color: primaryColor,
                      child: ListView(
                        children: [
                          _buildCustomerCards(),
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
                              const Text(
                                'Customer Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              )
                                  .animate()
                                  .fadeIn(duration: 250.ms)
                                  .slideY(begin: 0.08, end: 0),
                              const SizedBox(height: 4),
                              const Text(
                                'Fill in the details below to add a new customer',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textSecondary,
                                ),
                              )
                                  .animate()
                                  .fadeIn(duration: 250.ms)
                                  .slideY(begin: 0.08, end: 0),
                              const SizedBox(height: 20),

                              _buildLabeledField(
                                label: 'Full Name *',
                                child: TextFormField(
                                  controller: nameController,
                                  focusNode: _nameFocus,
                                  style: const TextStyle(
                                      fontSize: 14, color: textPrimary),
                                  decoration: _inputDecoration(
                                    hint: 'Enter customer name',
                                    icon: Icons.person_outline_rounded,
                                    focusNode: _nameFocus,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Name is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              _buildLabeledField(
                                label: 'NIC Number *',
                                child: TextFormField(
                                  controller: nicController,
                                  focusNode: _nicFocus,
                                  style: const TextStyle(
                                      fontSize: 14, color: textPrimary),
                                  decoration: _inputDecoration(
                                    hint: 'Enter NIC number',
                                    icon: Icons.credit_card_rounded,
                                    focusNode: _nicFocus,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'NIC is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              _buildLabeledField(
                                label: 'Phone Number *',
                                child: TextFormField(
                                  controller: phoneController,
                                  focusNode: _phoneFocus,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(15),
                                  ],
                                  style: const TextStyle(
                                      fontSize: 14, color: textPrimary),
                                  decoration: _inputDecoration(
                                    hint: 'Enter phone number',
                                    icon: Icons.phone_rounded,
                                    focusNode: _phoneFocus,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Phone number is required';
                                    }
                                    if (value.trim().length < 8) {
                                      return 'Enter a valid phone number';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              _buildLabeledField(
                                label: 'Address',
                                child: TextFormField(
                                  controller: addressController,
                                  focusNode: _addressFocus,
                                  maxLines: 2,
                                  style: const TextStyle(
                                      fontSize: 14, color: textPrimary),
                                  decoration: _inputDecoration(
                                    hint: 'Enter customer address',
                                    icon: Icons.location_on_outlined,
                                    focusNode: _addressFocus,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              _buildLabeledField(
                                label: 'Birthday',
                                child: GestureDetector(
                                  onTap: () => _selectDate(context),
                                  child: AbsorbPointer(
                                    child: TextFormField(
                                      controller: bdayController,
                                      focusNode: _bdayFocus,
                                      style: const TextStyle(
                                          fontSize: 14, color: textPrimary),
                                      decoration: _inputDecoration(
                                        hint: 'Select birthday (YYYY-MM-DD)',
                                        icon: Icons.cake_outlined,
                                        focusNode: _bdayFocus,
                                        suffixIcon: IconButton(
                                          onPressed: () => _selectDate(context),
                                          icon: const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 18),
                                        ),
                                      ),
                                    ),
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
                                          _isLoading ? null : _saveCustomer,
                                      icon: const Icon(Icons.save_rounded,
                                          size: 18),
                                      label: _isLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'Save Customer',
                                              style: TextStyle(
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
                                          _isLoading ? null : _fetchCustomers,
                                      icon: const Icon(Icons.list_rounded,
                                          size: 18, color: primaryColor),
                                      label: const Text(
                                        'View Customers',
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