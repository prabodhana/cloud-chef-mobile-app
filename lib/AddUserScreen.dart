import 'dart:convert';

import 'package:flutter/material.dart';
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

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController accessListController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _activeUser = true;

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();
  final FocusNode _typeFocus = FocusNode();
  final FocusNode _accessListFocus = FocusNode();

  String? _selectedUserType;

  // Map user types to their integer values expected by the backend
  final Map<String, int> _userTypes = const {
    'Admin': 1,
    'Manager': 2,
    'Staff': 3,
    'Viewer': 4,
  };

  final List<String> _selectedAccessList = [];
  String? _authToken;

  static const double _formMaxWidth = 640;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_onFocusChange);
    _passwordFocus.addListener(_onFocusChange);
    _confirmPasswordFocus.addListener(_onFocusChange);
    _typeFocus.addListener(_onFocusChange);
    _accessListFocus.addListener(_onFocusChange);

    _loadToken();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _authToken = prefs.getString('auth_token');
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    accessListController.dispose();

    _nameFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _typeFocus.dispose();
    _accessListFocus.dispose();

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

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (_authToken == null) {
      _showSnackBar('Authentication required. Please login again.');
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      _showSnackBar('Passwords do not match');
      return;
    }

    if (_selectedUserType == null) {
      _showSnackBar('Please select a user type');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse('https://api-kafenio.sltcloud.lk/api/users'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $_authToken',
            },
            body: jsonEncode({
              'name': nameController.text.trim(),
              'password': passwordController.text,
              'password_confirmation': confirmPasswordController.text,
              'type': _userTypes[_selectedUserType],
              'accessList': _selectedAccessList,
              'active': _activeUser,
            }),
          )
          .timeout(const Duration(seconds: 10));

      dynamic responseData;
      try {
        responseData =
            response.body.isNotEmpty ? jsonDecode(response.body) : null;
      } catch (_) {
        responseData = null;
      }

      if (response.statusCode == 201) {
        _showSuccessDialog();
      } else if (response.statusCode == 401) {
        _showSnackBar('Session expired. Please login again.');
      } else {
        String errorMessage = 'Failed to save user (${response.statusCode})';
        if (responseData is Map) {
          errorMessage =
              (responseData['message'] ?? responseData['error'] ?? errorMessage)
                  .toString();
        }
        throw Exception(errorMessage);
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
                  'User Added',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 8),
                const Text(
                  'User has been added successfully.',
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
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context, true);
                    },
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

  void _showAccessListDialog() {
    const List<String> allAccessOptions = [
      'Dashboard',
      'Customers',
      'Suppliers',
      'Inventory',
      'Reports',
      'Settings',
    ];

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
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
                    const Text(
                      'Select Access Permissions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Choose what this user can access.',
                      style: TextStyle(
                        fontSize: 14,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...allAccessOptions.map(
                      (option) => CheckboxListTile(
                        title: Text(
                          option,
                          style:
                              const TextStyle(fontSize: 14, color: textPrimary),
                        ),
                        value: _selectedAccessList.contains(option),
                        onChanged: (bool? value) {
                          setLocalState(() {
                            if (value == true) {
                              _selectedAccessList.add(option);
                            } else {
                              _selectedAccessList.remove(option);
                            }
                          });
                        },
                        activeColor: primaryColor,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey.shade300),
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
                              setState(() {
                                accessListController.text =
                                    _selectedAccessList.join(', ');
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Confirm',
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
      },
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
    Widget? suffixIcon,
  }) {
    final focused = focusNode.hasFocus;

    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(color: textSecondary.withOpacity(0.65), fontSize: 14),
      prefixIcon:
          Icon(icon, color: focused ? primaryColor : textSecondary, size: 20),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: secondaryColor,
      appBar: AppBar(
        title: const Text(
          'Add New User',
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _formMaxWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
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
                              'User Information',
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
                              'Fill in the details below to add a new user',
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
                                  hint: 'Enter full name',
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
                              label: 'Password *',
                              child: TextFormField(
                                controller: passwordController,
                                focusNode: _passwordFocus,
                                obscureText: _obscurePassword,
                                style: const TextStyle(
                                    fontSize: 14, color: textPrimary),
                                decoration: _inputDecoration(
                                  hint: 'Enter password',
                                  icon: Icons.lock_outline_rounded,
                                  focusNode: _passwordFocus,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      size: 20,
                                      color: textSecondary,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  final v = value ?? '';
                                  if (v.isEmpty) return 'Password is required';
                                  if (v.length < 6)
                                    return 'Password must be at least 6 characters';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildLabeledField(
                              label: 'Confirm Password *',
                              child: TextFormField(
                                controller: confirmPasswordController,
                                focusNode: _confirmPasswordFocus,
                                obscureText: _obscureConfirmPassword,
                                style: const TextStyle(
                                    fontSize: 14, color: textPrimary),
                                decoration: _inputDecoration(
                                  hint: 'Re-enter password',
                                  icon: Icons.lock_outline_rounded,
                                  focusNode: _confirmPasswordFocus,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      size: 20,
                                      color: textSecondary,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  final v = value ?? '';
                                  if (v.isEmpty)
                                    return 'Please confirm your password';
                                  if (v != passwordController.text)
                                    return 'Passwords do not match';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildLabeledField(
                              label: 'User Type *',
                              child: DropdownButtonFormField<String>(
                                value: _selectedUserType,
                                focusNode: _typeFocus,
                                decoration: _inputDecoration(
                                  hint: 'Select user type',
                                  icon: Icons.group_outlined,
                                  focusNode: _typeFocus,
                                ),
                                items: _userTypes.keys.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(
                                      type,
                                      style: const TextStyle(
                                          fontSize: 14, color: textPrimary),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  setState(() {
                                    _selectedUserType = newValue;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'User type is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildLabeledField(
                              label: 'Access Permissions *',
                              child: GestureDetector(
                                onTap: _showAccessListDialog,
                                child: AbsorbPointer(
                                  child: TextFormField(
                                    controller: accessListController,
                                    focusNode: _accessListFocus,
                                    style: const TextStyle(
                                        fontSize: 14, color: textPrimary),
                                    decoration: _inputDecoration(
                                      hint: 'Select permissions',
                                      icon: Icons.security_outlined,
                                      focusNode: _accessListFocus,
                                      suffixIcon: const Icon(
                                          Icons.chevron_right_rounded,
                                          color: textSecondary),
                                    ),
                                    validator: (_) {
                                      if (_selectedAccessList.isEmpty) {
                                        return 'At least one permission is required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: secondaryColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.toggle_on_outlined,
                                      color: textSecondary, size: 20),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Active User',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: _activeUser,
                                    onChanged: (value) {
                                      setState(() {
                                        _activeUser = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveUser,
                        icon: const Icon(Icons.save_rounded, size: 18),
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
                                'Save User',
                                style: TextStyle(
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
    );
  }
}
