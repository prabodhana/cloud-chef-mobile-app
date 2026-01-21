import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
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

class AddSupplierScreen extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? supplierData;

  const AddSupplierScreen({
    super.key,
    this.isEditing = false,
    this.supplierData,
  });

  @override
  State<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends State<AddSupplierScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController companyController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController contactPersonController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  bool _isLoading = false;
  bool _viewingSuppliers = false;
  List<dynamic> _suppliers = [];

  // Responsive max widths similar to the invoice/customer screens
  static const double _formMaxWidth = 640;
  static const double _listMaxWidth = 980;

  final FocusNode _companyFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _contactFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _descFocus = FocusNode();

  @override
  void initState() {
    super.initState();

    _companyFocus.addListener(_onFocusChange);
    _addressFocus.addListener(_onFocusChange);
    _contactFocus.addListener(_onFocusChange);
    _phoneFocus.addListener(_onFocusChange);
    _emailFocus.addListener(_onFocusChange);
    _descFocus.addListener(_onFocusChange);

    if (widget.isEditing && widget.supplierData != null) {
      // Note: API field uses "commpany" (typo) in your codebase.
      companyController.text =
          (widget.supplierData!['commpany'] ?? '').toString();
      addressController.text =
          (widget.supplierData!['address'] ?? '').toString();
      contactPersonController.text =
          (widget.supplierData!['contactPerson'] ?? '').toString();
      phoneController.text = (widget.supplierData!['phone'] ?? '').toString();
      emailController.text = (widget.supplierData!['email'] ?? '').toString();
      descriptionController.text =
          (widget.supplierData!['description'] ?? '').toString();
    }
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    companyController.dispose();
    addressController.dispose();
    contactPersonController.dispose();
    phoneController.dispose();
    emailController.dispose();
    descriptionController.dispose();

    _companyFocus.dispose();
    _addressFocus.dispose();
    _contactFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _descFocus.dispose();

    super.dispose();
  }

  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Authentication required. Please login again.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
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

  Future<void> _fetchSuppliers() async {
    setState(() {
      _isLoading = true;
      _suppliers = [];
    });

    try {
      final headers = await _getAuthHeaders();
      final response = await http
          .get(
            Uri.parse('https://api-kafenio.sltcloud.lk/api/suppliers'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        List<dynamic> suppliers;
        if (data is List) {
          suppliers = data;
        } else if (data is Map && data['data'] is List) {
          suppliers = data['data'] as List<dynamic>;
        } else {
          throw Exception('Invalid data format received from server');
        }

        setState(() {
          _suppliers = suppliers;
          _viewingSuppliers = true;
        });
      } else {
        String errorMsg = 'Failed to fetch suppliers (${response.statusCode})';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] is String) {
            errorMsg = decoded['message'] as String;
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      _showSnackBar('Failed to load suppliers: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteSupplier(int id) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final headers = await _getAuthHeaders();
      final response = await http
          .delete(
            Uri.parse('https://api-kafenio.sltcloud.lk/api/suppliers/$id'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _showSnackBar('Supplier deleted successfully', isError: false);
        await _fetchSuppliers();
      } else {
        String errorMsg = 'Failed to delete supplier';
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
                  'Are you sure you want to delete this supplier?',
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
                          _deleteSupplier(id);
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

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final headers = await _getAuthHeaders();

      final Uri url = widget.isEditing
          ? Uri.parse(
              'https://api-kafenio.sltcloud.lk/api/suppliers/${widget.supplierData!['id']}')
          : Uri.parse('https://api-kafenio.sltcloud.lk/api/suppliers');

      // Keep request keys exactly as your API expects (including commpany typo).
      final body = jsonEncode({
        'commpany': companyController.text.trim(),
        'address': addressController.text.trim(),
        'contactPerson': contactPersonController.text.trim(),
        'phone': phoneController.text.trim(),
        'email': emailController.text.trim(),
        'description': descriptionController.text.trim(),
      });

      final response = widget.isEditing
          ? await http
              .put(url, headers: headers, body: body)
              .timeout(const Duration(seconds: 10))
          : await http
              .post(url, headers: headers, body: body)
              .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessDialog();

        if (!widget.isEditing) {
          // Clear for next entry
          companyController.clear();
          addressController.clear();
          contactPersonController.clear();
          phoneController.clear();
          emailController.clear();
          descriptionController.clear();

          // Show list after adding, matching the customer screen behavior
          await _fetchSuppliers();
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        String errorMsg = 'Failed to save supplier';
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
                Text(
                  widget.isEditing ? 'Supplier Updated' : 'Supplier Added',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 8),
                Text(
                  widget.isEditing
                      ? 'Supplier has been updated successfully.'
                      : 'Supplier has been added successfully.',
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

  void _showSupplierDetails(Map<String, dynamic> supplier) {
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
                    'Supplier Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                      'Company',
                      (supplier['commpany'] ?? supplier['company'] ?? 'N/A')
                          .toString()),
                  _buildDetailRow('Contact Person',
                      (supplier['contactPerson'] ?? 'N/A').toString()),
                  _buildDetailRow(
                      'Phone', (supplier['phone'] ?? 'N/A').toString()),
                  _buildDetailRow(
                      'Email', (supplier['email'] ?? 'N/A').toString()),
                  _buildDetailRow(
                      'Address', (supplier['address'] ?? 'N/A').toString()),
                  if ((supplier['description'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty)
                    _buildDetailRow(
                        'Description', supplier['description'].toString()),
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

  Widget _buildSupplierTable() {
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

    if (_suppliers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Text(
            'No suppliers found',
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
        itemCount: _suppliers.length,
        separatorBuilder: (_, __) => Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: Colors.grey.shade300,
        ),
        itemBuilder: (context, index) {
          final supplier = Map<String, dynamic>.from(_suppliers[index]);
          final int id = (supplier['id'] as num?)?.toInt() ?? 0;

          return InkWell(
            onTap: () => _showSupplierDetails(supplier),
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
                        // Company
                        Text(
                          (supplier['commpany'] ?? 'N/A').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),

                        const SizedBox(height: 3),

                        // Contact (label + value inline)
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12.5),
                            children: [
                              const TextSpan(
                                text: 'Contact: ',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextSpan(
                                text: (supplier['contactPerson'] ?? 'N/A')
                                    .toString(),
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
                                (supplier['phone'] ?? 'N/A').toString(),
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
                          _showSupplierDetails(supplier);
                          break;
                        case 'edit':
                          setState(() {
                            _viewingSuppliers = false;
                            companyController.text =
                                (supplier['commpany'] ?? '').toString();
                            addressController.text =
                                (supplier['address'] ?? '').toString();
                            contactPersonController.text =
                                (supplier['contactPerson'] ?? '').toString();
                            phoneController.text =
                                (supplier['phone'] ?? '').toString();
                            emailController.text =
                                (supplier['email'] ?? '').toString();
                            descriptionController.text =
                                (supplier['description'] ?? '').toString();
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
    final String title = _viewingSuppliers
        ? 'View Suppliers'
        : widget.isEditing
            ? 'Edit Supplier'
            : 'Add New Supplier';

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
            if (_viewingSuppliers) {
              setState(() {
                _viewingSuppliers = false;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_viewingSuppliers)
            IconButton(
              onPressed: _fetchSuppliers,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Refresh',
            )
          else if (!widget.isEditing)
            IconButton(
              icon: const Icon(Icons.list_rounded, color: Colors.white),
              onPressed: _fetchSuppliers,
              tooltip: 'View Suppliers',
            ),
        ],
      ),
      body: SafeArea(
        child: _viewingSuppliers
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _listMaxWidth),
                    child: RefreshIndicator(
                      onRefresh: _fetchSuppliers,
                      color: primaryColor,
                      child: ListView(
                        children: [
                          _buildSupplierTable(),
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
                                'Supplier Information',
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
                                widget.isEditing
                                    ? 'Update the supplier details below'
                                    : 'Fill in the details below to add a new supplier',
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
                                label: 'Company Name *',
                                child: TextFormField(
                                  controller: companyController,
                                  focusNode: _companyFocus,
                                  style: const TextStyle(
                                      fontSize: 14, color: textPrimary),
                                  decoration: _inputDecoration(
                                    hint: 'Enter company name',
                                    icon: Icons.business_outlined,
                                    focusNode: _companyFocus,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Company name is required';
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
                                    hint: 'Enter company address',
                                    icon: Icons.location_on_outlined,
                                    focusNode: _addressFocus,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildLabeledField(
                                label: 'Contact Person',
                                child: TextFormField(
                                  controller: contactPersonController,
                                  focusNode: _contactFocus,
                                  style: const TextStyle(
                                      fontSize: 14, color: textPrimary),
                                  decoration: _inputDecoration(
                                    hint: 'Enter contact person name',
                                    icon: Icons.person_outline_rounded,
                                    focusNode: _contactFocus,
                                  ),
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
                                label: 'Email',
                                child: TextFormField(
                                  controller: emailController,
                                  focusNode: _emailFocus,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(
                                      fontSize: 14, color: textPrimary),
                                  decoration: _inputDecoration(
                                    hint: 'Enter company email',
                                    icon: Icons.email_outlined,
                                    focusNode: _emailFocus,
                                  ),
                                  validator: (value) {
                                    final v = value?.trim() ?? '';
                                    if (v.isEmpty) return null;

                                    final emailRegex = RegExp(
                                        r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$');
                                    if (!emailRegex.hasMatch(v)) {
                                      return 'Enter a valid email address';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildLabeledField(
                                label: 'Description',
                                child: TextFormField(
                                  controller: descriptionController,
                                  focusNode: _descFocus,
                                  maxLines: 3,
                                  style: const TextStyle(
                                      fontSize: 14, color: textPrimary),
                                  decoration: _inputDecoration(
                                    hint: 'Enter additional details (optional)',
                                    icon: Icons.description_outlined,
                                    focusNode: _descFocus,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final bool isSmall =
                                      constraints.maxWidth < 420;

                                  final saveButton = SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          _isLoading ? null : _saveSupplier,
                                      icon: Icon(
                                        widget.isEditing
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
                                              widget.isEditing
                                                  ? 'Update Supplier'
                                                  : 'Save Supplier',
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
                                          (_isLoading || widget.isEditing)
                                              ? null
                                              : _fetchSuppliers,
                                      icon: const Icon(Icons.list_rounded,
                                          size: 18, color: primaryColor),
                                      label: const Text(
                                        'View Suppliers',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: primaryColor,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                            color: primaryColor),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  );

                                  if (widget.isEditing) {
                                    // In edit mode, only show the save/update button.
                                    return saveButton;
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
                              )
                                  .animate()
                                  .fadeIn(delay: 120.ms)
                                  .slideY(begin: 0.12, end: 0),
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
