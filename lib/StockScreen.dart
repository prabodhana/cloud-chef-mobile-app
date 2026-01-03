import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({Key? key}) : super(key: key);

  @override
  _StockScreenState createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<StockItem> stockItems = [];
  List<StockItem> filteredItems = [];
  bool isLoading = true;
  String searchQuery = '';
  String baseUrl = 'https://api-kafenio.sltcloud.lk/api';
  int _rowsPerPage = 10;
  int _currentPage = 0;
  String? _sortColumn;
  bool _sortAscending = true;
  
  // Filter states
  String? _selectedStockFilter;
  String? _selectedSupplierFilter;
  String? _selectedCategoryFilter;
  
  // For dropdown data
  List<DropdownOption> stockOptions = [];
  List<DropdownOption> makeOptions = [];
  List<DropdownOption> typeOptions = [];
  List<DropdownOption> categoryOptions = [];
  List<DropdownOption> locationOptions = [];
  List<DropdownOption> supplierOptions = [];

  @override
  void initState() {
    super.initState();
    _loadStockData();
    _loadCreateData();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _loadCreateData() async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/stock/create-data'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        setState(() {
          stockOptions = _parseDropdownData(data['stock']);
          makeOptions = _parseDropdownData(data['make']);
          typeOptions = _parseDropdownData(data['type']);
          categoryOptions = _parseDropdownData(data['category']);
          locationOptions = _parseDropdownData(data['location']);
          supplierOptions = _parseDropdownData(data['supplier']);
        });
      } else {
        print('Failed to load create data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error loading create data: $e');
    }
  }

  List<DropdownOption> _parseDropdownData(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((item) => DropdownOption.fromJson(item)).toList();
    }
    return [];
  }

  Future<void> _loadStockData() async {
    try {
      setState(() => isLoading = true);
      final token = await _getToken();
      if (token == null) {
        _showErrorSnackbar('No authentication token found');
        setState(() => isLoading = false);
        return;
      }

      String url = '$baseUrl/stock-master';
      if (searchQuery.isNotEmpty) {
        url = '$baseUrl/stock-master/search?q=$searchQuery';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        dynamic stockData;
        
        if (data is Map && data.containsKey('data')) {
          stockData = data['data'];
        } else if (data is List) {
          stockData = data;
        } else {
          stockData = [];
        }

        if (stockData is Map && stockData.containsKey('data')) {
          stockData = stockData['data'];
        }

        if (stockData is! List) {
          stockData = [];
        }

        final items = (stockData as List)
            .map((item) => StockItem.fromJson(item as Map<String, dynamic>))
            .toList();

        setState(() {
          stockItems = items;
          filteredItems = _applyFilters(items);
          isLoading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          stockItems = [];
          filteredItems = [];
          isLoading = false;
        });
        _showErrorSnackbar('API endpoint not found (404)');
      } else {
        throw Exception('Failed to load stock data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading stock data: $e');
      setState(() => isLoading = false);
      _showErrorSnackbar('Failed to load stock data: $e');
    }
  }

  List<StockItem> _applyFilters(List<StockItem> items) {
    List<StockItem> filtered = items;

    if (_selectedStockFilter != null) {
      filtered = filtered.where((item) => item.stock?.name == _selectedStockFilter).toList();
    }

    if (_selectedSupplierFilter != null) {
      filtered = filtered.where((item) => item.supplier?.name == _selectedSupplierFilter).toList();
    }

    if (_selectedCategoryFilter != null) {
      filtered = filtered.where((item) => item.category?.name == _selectedCategoryFilter).toList();
    }

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((item) =>
        item.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
        (item.barCode?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
        (item.id.toString().contains(searchQuery))).toList();
    }

    // Apply sorting
    if (_sortColumn != null) {
      filtered.sort((a, b) {
        int compare;
        switch (_sortColumn) {
          case 'id':
            compare = a.id.compareTo(b.id);
            break;
          case 'name':
            compare = a.name.compareTo(b.name);
            break;
          case 'stock':
            compare = (a.stock?.name ?? '').compareTo(b.stock?.name ?? '');
            break;
          case 'supplier':
            compare = (a.supplier?.name ?? '').compareTo(b.supplier?.name ?? '');
            break;
          default:
            compare = 0;
        }
        return _sortAscending ? compare : -compare;
      });
    }

    return filtered;
  }

  void _performSearch() {
    setState(() {
      _currentPage = 0;
      filteredItems = _applyFilters(stockItems);
    });
  }

  void _clearSearch() {
    setState(() {
      searchQuery = '';
      _selectedStockFilter = null;
      _selectedSupplierFilter = null;
      _selectedCategoryFilter = null;
      _currentPage = 0;
      filteredItems = _applyFilters(stockItems);
    });
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showDeleteConfirmation(int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete',
            style: TextStyle(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete "$name"?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.blueGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteStockItem(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStockItem(int id) async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final response = await http.delete(
        Uri.parse('$baseUrl/stock-master/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _showSuccessSnackbar('Stock item deleted successfully');
        _loadStockData();
      } else if (response.statusCode == 404) {
        _showErrorSnackbar('Stock item not found');
      } else {
        throw Exception('Failed to delete stock item');
      }
    } catch (e) {
      print('Error deleting stock item: $e');
      _showErrorSnackbar('Failed to delete stock item');
    }
  }

  void _showAnalyse(StockItem item) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Stock Analysis',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[600]),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (item.productImage != null)
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(item.productImage!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              _buildAnalysisRow('Item Name:', item.name),
              _buildAnalysisRow('Item Code:', item.id.toString().padLeft(4, '0')),
              if (item.barCode != null) _buildAnalysisRow('Barcode:', item.barCode!),
              _buildAnalysisRow('Unit:', item.unit),
              if (item.stock != null) _buildAnalysisRow('Stock:', item.stock!.name),
              if (item.location != null) _buildAnalysisRow('Location:', item.location!.name),
              if (item.make != null) _buildAnalysisRow('Make:', item.make!.name),
              if (item.type != null) _buildAnalysisRow('Type:', item.type!.name),
              if (item.category != null) _buildAnalysisRow('Category:', item.category!.name),
              if (item.supplier != null) _buildAnalysisRow('Supplier:', item.supplier!.name),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Stock Movement',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildStatCard('In Stock', '25', Color(0xFF10B981))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard('Reserved', '3', Color(0xFFF59E0B))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard('Low Stock', '2', Color(0xFFEF4444))),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Close',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String? value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF3B82F6)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('All $label',
              style: TextStyle(color: Colors.grey[500])),
        ),
        ...options.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }).toList(),
      ],
      onChanged: onChanged,
      style: TextStyle(fontSize: 14, color: Colors.grey[800]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.of(context).size.width >= 768;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Stock Management',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.grey[800],
        actions: [
          if (isTablet)
            Container(
              width: 300,
              margin: const EdgeInsets.only(right: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFF3B82F6)),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[500]),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 18, color: Colors.grey[500]),
                          onPressed: _clearSearch,
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() => searchQuery = value);
                  _performSearch();
                },
              ),
            ),
       
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.grey[700]),
            onPressed: _loadStockData,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showStockFormDialog(null),
              icon: Icon(Icons.add, size: 20),
              label: Text('Add New',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Mobile Search Bar
          if (!isTablet)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search stock items...',
                        prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey[500]),
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Color(0xFF3B82F6)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() => searchQuery = value);
                      },
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.add, color: Colors.white),
                      onPressed: () => _showStockFormDialog(null),
                    ),
                  ),
                ],
              ),
            ),

          // Filter Chips
          if (_selectedStockFilter != null || _selectedSupplierFilter != null || _selectedCategoryFilter != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_selectedStockFilter != null)
                    _buildFilterChip('Stock: $_selectedStockFilter', () {
                      setState(() => _selectedStockFilter = null);
                      _performSearch();
                    }),
                  if (_selectedSupplierFilter != null)
                    _buildFilterChip('Supplier: $_selectedSupplierFilter', () {
                      setState(() => _selectedSupplierFilter = null);
                      _performSearch();
                    }),
                  if (_selectedCategoryFilter != null)
                    _buildFilterChip('Category: $_selectedCategoryFilter', () {
                      setState(() => _selectedCategoryFilter = null);
                      _performSearch();
                    }),
                ],
              ),
            ),

          // Summary Cards
          if (isTablet && filteredItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildSummaryCard('Total Items', filteredItems.length.toString(), Icons.inventory),
                  const SizedBox(width: 12),
                  _buildSummaryCard('Unique Suppliers', 
                    supplierOptions.where((s) => filteredItems.any((item) => item.supplier?.id == s.id)).length.toString(), 
                    Icons.business
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard('Low Stock', 
                    filteredItems.length > 10 ? '2' : '0', 
                    Icons.warning,
                    color: Color(0xFFEF4444)
                  ),
                ],
              ),
            ),

          // Stock Table/Cards
          Expanded(
            child: isLoading
                ? _buildLoadingState()
                : filteredItems.isEmpty
                    ? _buildEmptyState()
                    : isTablet
                        ? _buildModernStockTable()
                        : _buildStockCards(),
          ),

          // Pagination
          if (isTablet && filteredItems.isNotEmpty)
            _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF3B82F6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close, size: 16, color: Color(0xFF3B82F6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, 
    {Color color = const Color.fromARGB(255, 68, 130, 230)}) {
  // Your widget implementation

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF3B82F6)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading stock data...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(60),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 56,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              searchQuery.isNotEmpty ? 'No items found' : 'No stock items',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              searchQuery.isNotEmpty
                  ? 'Try different search terms'
                  : 'Add your first stock item to get started',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (searchQuery.isNotEmpty)
              ElevatedButton(
                onPressed: _clearSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.grey[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Clear Search'),
              )
            else
              ElevatedButton.icon(
                onPressed: () => _showStockFormDialog(null),
                icon: Icon(Icons.add, size: 20),
                label: const Text('Add New Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernStockTable() {
    final start = _currentPage * _rowsPerPage;
    final end = start + _rowsPerPage;
    final paginatedItems = filteredItems.sublist(
      start,
      end > filteredItems.length ? filteredItems.length : end,
    );

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _buildSortableColumn('ID', 'id'),
                ),
                Expanded(
                  flex: 2,
                  child: _buildSortableColumn('ITEM', 'name'),
                ),
                Expanded(
                  flex: 1,
                  child: _buildSortableColumn('STOCK', 'stock'),
                ),
                Expanded(
                  flex: 1,
                  child: const Text('UNIT',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                          letterSpacing: 0.5)),
                ),
                Expanded(
                  flex: 2,
                  child: _buildSortableColumn('SUPPLIER', 'supplier'),
                ),
                Expanded(
                  flex: 2,
                  child: const Text('ACTIONS',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: paginatedItems.length,
              itemBuilder: (context, index) {
                final item = paginatedItems[index];
                return Container(
                  decoration: BoxDecoration(
                    border: index < paginatedItems.length - 1
                        ? Border(bottom: BorderSide(color: Colors.grey[100]!))
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Text(
                              item.id.toString().padLeft(4, '0'),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              if (item.barCode != null)
                                Text(
                                  item.barCode!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: item.stock != null
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF10B981).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Color(0xFF10B981).withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    item.stock!.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                )
                              : Text('-',
                                  style: TextStyle(color: Colors.grey[400])),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: Text(
                            item.unit,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: item.supplier != null
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey[50],
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.blueGrey[100]!),
                                  ),
                                  child: Text(
                                    item.supplier!.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blueGrey[700],
                                    ),
                                  ),
                                )
                              : Text('-',
                                  style: TextStyle(color: Colors.grey[400])),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              _buildActionButton(
                                Icons.edit_outlined,
                                Color(0xFF3B82F6),
                                'Edit',
                                () => _showAddEditStockDialog(item),
                              ),
                              const SizedBox(width: 8),
                              _buildActionButton(
                                Icons.delete_outline,
                                Color(0xFFEF4444),
                                'Delete',
                                () => _showDeleteConfirmation(item.id, item.name),
                              ),
                              const SizedBox(width: 8),
                              _buildActionButton(
                                Icons.analytics_outlined,
                                Color(0xFF8B5CF6),
                                'Analyse',
                                () => _showAnalyse(item),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildSortableColumn(String label, String columnId) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_sortColumn == columnId) {
            _sortAscending = !_sortAscending;
          } else {
            _sortColumn = columnId;
            _sortAscending = true;
          }
          filteredItems = _applyFilters(stockItems);
        });
      },
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 4),
          if (_sortColumn == columnId)
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: Color(0xFF3B82F6),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: IconButton(
          icon: Icon(icon, size: 18, color: color),
          onPressed: onPressed,
          splashRadius: 20,
        ),
      ),
    );
  }

  Widget _buildStockCards() {
    final start = _currentPage * _rowsPerPage;
    final end = start + _rowsPerPage;
    final paginatedItems = filteredItems.sublist(
      start,
      end > filteredItems.length ? filteredItems.length : end,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: paginatedItems.length,
        itemBuilder: (context, index) {
          final item = paginatedItems[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Text(
                          'ID: ${item.id.toString().padLeft(4, '0')}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (item.barCode != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Barcode: ${item.barCode}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (item.stock != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Color(0xFF10B981).withOpacity(0.2)),
                          ),
                          child: Text(
                            'Stock: ${item.stock!.name}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Color(0xFF3B82F6).withOpacity(0.2)),
                        ),
                        child: Text(
                          'Unit: ${item.unit}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                      if (item.supplier != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFF8B5CF6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Color(0xFF8B5CF6).withOpacity(0.2)),
                          ),
                          child: Text(
                            'Supplier: ${item.supplier!.name}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildActionButton(
                        Icons.edit_outlined,
                        Color(0xFF3B82F6),
                        'Edit',
                        () => _showAddEditStockDialog(item),
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        Icons.delete_outline,
                        Color(0xFFEF4444),
                        'Delete',
                        () => _showDeleteConfirmation(item.id, item.name),
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        Icons.analytics_outlined,
                        Color(0xFF8B5CF6),
                        'Analyse',
                        () => _showAnalyse(item),
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

  Widget _buildPagination() {
    final totalPages = (filteredItems.length / _rowsPerPage).ceil();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Rows per page:',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DropdownButton<int>(
                  value: _rowsPerPage,
                  items: [5, 10, 20, 50].map((value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value',
                          style: TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _rowsPerPage = value;
                        _currentPage = 0;
                      });
                    }
                  },
                  underline: const SizedBox(),
                  style: TextStyle(color: Colors.grey[800]),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '${_currentPage * _rowsPerPage + 1}-${(_currentPage + 1) * _rowsPerPage > filteredItems.length ? filteredItems.length : (_currentPage + 1) * _rowsPerPage} of ${filteredItems.length}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.chevron_left, color: _currentPage > 0 ? Colors.grey[800] : Colors.grey[400]),
                onPressed: _currentPage > 0
                    ? () {
                        setState(() => _currentPage--);
                      }
                    : null,
              ),
              ...List.generate(
                totalPages > 5 ? 5 : totalPages,
                (index) {
                  final page = index;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    child: TextButton(
                      onPressed: () => setState(() => _currentPage = page),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        backgroundColor: _currentPage == page
                            ? Color(0xFF3B82F6)
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        '${page + 1}',
                        style: TextStyle(
                          color: _currentPage == page
                              ? Colors.white
                              : Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (totalPages > 5) const Text('...'),
              IconButton(
                icon: Icon(Icons.chevron_right, color: _currentPage < totalPages - 1 ? Colors.grey[800] : Colors.grey[400]),
                onPressed: _currentPage < totalPages - 1
                    ? () {
                        setState(() => _currentPage++);
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
   void _showStockFormDialog(StockItem? item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: StockFormDialog(
          item: item,
          stockOptions: stockOptions,
          categoryOptions: categoryOptions,
          supplierOptions: supplierOptions,
          makeOptions: makeOptions,
          typeOptions: typeOptions,
          locationOptions: locationOptions,
          baseUrl: baseUrl,
          getToken: _getToken,
          onSaved: () {
            _loadStockData();
            _showSuccessSnackbar(
              item == null
                  ? 'Stock added successfully'
                  : 'Stock updated successfully',
            );
          },
          onCancel: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  void _showAddEditStockDialog(StockItem? item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: AddEditStockDialog(
          item: item,
          stockOptions: stockOptions,
          makeOptions: makeOptions,
          typeOptions: typeOptions,
          categoryOptions: categoryOptions,
          locationOptions: locationOptions,
          supplierOptions: supplierOptions,
          baseUrl: baseUrl,
          getToken: _getToken,
          onSaved: () {
            _loadStockData();
            _showSuccessSnackbar(
              item == null
                  ? 'Stock added successfully'
                  : 'Stock updated successfully',
            );
          },
          onCancel: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }
}

class StockFormDialog extends StatefulWidget {
  final StockItem? item;
  final List<DropdownOption> stockOptions;
  final List<DropdownOption> makeOptions;
  final List<DropdownOption> typeOptions;
  final List<DropdownOption> categoryOptions;
  final List<DropdownOption> locationOptions;
  final List<DropdownOption> supplierOptions;
  final String baseUrl;
  final Future<String?> Function() getToken;
  final VoidCallback onSaved;
  final VoidCallback onCancel;
  
  const StockFormDialog({
    Key? key,
    this.item,
    required this.stockOptions,
    required this.categoryOptions,
    required this.supplierOptions,
    required this.baseUrl,
    required this.getToken,
    required this.onSaved,
    required this.onCancel,
    required this.makeOptions,
    required this.typeOptions,
    required this.locationOptions,
  }) : super(key: key);

  @override
  _StockFormDialogState createState() => _StockFormDialogState();
}

class _StockFormDialogState extends State<StockFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _barCodeController;
  late TextEditingController _nameController;
  late TextEditingController _sinhalaNameController;
  late TextEditingController _costController;
  late TextEditingController _retailPriceController;
  late TextEditingController _wsPriceController;
  late TextEditingController _criticalLevelController;
  late TextEditingController _reorderLevelController;
  late TextEditingController _expiryDateController;
  late TextEditingController _quantityController;
  late TextEditingController _lotNumberController;
  late TextEditingController _costLetterController;
  late TextEditingController _percentageController;
  
  DropdownOption? _selectedStock;
  DropdownOption? _selectedCategory;
  DropdownOption? _selectedSupplier;
  DropdownOption? _selectedMake;
  DropdownOption? _selectedType;
  DropdownOption? _selectedLocation;
  
  String _selectedUnit = 'Pcs';
  bool _exStatus = false;
  
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  
  final List<String> _unitOptions = ['Pcs', 'KG', 'L', 'M', 'CM', 'BOX', 'SET'];
  
  @override
  void initState() {
    super.initState();
    _barCodeController = TextEditingController(text: widget.item?.barCode ?? '');
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _sinhalaNameController = TextEditingController(text: widget.item?.sinhalaName ?? '');
    _costController = TextEditingController(text: widget.item?.cost?.toStringAsFixed(2) ?? '0.00');
    _retailPriceController = TextEditingController(text: widget.item?.retailPrice?.toStringAsFixed(2) ?? '0.00');
    _wsPriceController = TextEditingController(text: '0.00');
    _criticalLevelController = TextEditingController(text: widget.item?.criticalLevel?.toString() ?? '5');
    _reorderLevelController = TextEditingController(text: widget.item?.reorderLevel?.toString() ?? '10');
    _expiryDateController = TextEditingController(text: widget.item?.expiryDate ?? '');
    _quantityController = TextEditingController(text: widget.item?.availableQty?.toString() ?? '5');
    _lotNumberController = TextEditingController(text: '1');
    _costLetterController = TextEditingController(text: '');
    _percentageController = TextEditingController(text: '');
    
    _selectedUnit = widget.item?.unit ?? 'Pcs';
    
    // Set initial dropdown values
    if (widget.item != null) {
      if (widget.item?.stock != null) {
        _selectedStock = DropdownOption(id: widget.item!.stock!.id, name: widget.item!.stock!.name);
      }
      if (widget.item?.category != null) {
        _selectedCategory = DropdownOption(id: widget.item!.category!.id, name: widget.item!.category!.name);
      }
      if (widget.item?.supplier != null) {
        _selectedSupplier = DropdownOption(id: widget.item!.supplier!.id, name: widget.item!.supplier!.name);
      }
      if (widget.item?.make != null) {
        _selectedMake = DropdownOption(id: widget.item!.make!.id, name: widget.item!.make!.name);
      }
      if (widget.item?.type != null) {
        _selectedType = DropdownOption(id: widget.item!.type!.id, name: widget.item!.type!.name);
      }
      if (widget.item?.location != null) {
        _selectedLocation = DropdownOption(id: widget.item!.location!.id, name: widget.item!.location!.name);
      }
    }
  }
  
  @override
  void dispose() {
    _barCodeController.dispose();
    _nameController.dispose();
    _sinhalaNameController.dispose();
    _costController.dispose();
    _retailPriceController.dispose();
    _wsPriceController.dispose();
    _criticalLevelController.dispose();
    _reorderLevelController.dispose();
    _expiryDateController.dispose();
    _quantityController.dispose();
    _lotNumberController.dispose();
    _costLetterController.dispose();
    _percentageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _selectExpiryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _expiryDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _saveStock() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedStock == null) {
      _showError('Stock is required');
      return;
    }
    if (_selectedCategory == null) {
      _showError('Category is required');
      return;
    }
    if (_selectedSupplier == null) {
      _showError('Supplier is required');
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final token = await widget.getToken();
      if (token == null) {
        _showError('No authentication token found');
        setState(() => _isLoading = false);
        return;
      }
      
      // Prepare the request body according to backend expectations
      final Map<String, dynamic> requestBody = {
        'bar_code': _barCodeController.text.isNotEmpty ? _barCodeController.text : null,
        'name': _nameController.text.trim(),
        's_name': _sinhalaNameController.text.trim(),
        'tbl_stock_id': _selectedStock!.name, // Send as string, backend will handle
        'tbl_category_id': _selectedCategory!.name, // Send as string
        'tbl_supplier_id': {'id': _selectedSupplier!.id, 'commpany': _selectedSupplier!.name},
        'unit': _selectedUnit,
        'c_level': _criticalLevelController.text,
        're_level': _reorderLevelController.text,
        'lots': {
          'lot_number': _lotNumberController.text.isNotEmpty ? _lotNumberController.text : '1',
          'cost': _costController.text,
          'cost_letter': _costLetterController.text,
          'retail_price': _retailPriceController.text,
          'ws_price': _wsPriceController.text,
          'qty': _quantityController.text,
          'ex_status': _exStatus,
          'ex_date': _exStatus ? _expiryDateController.text : null,
          'precentage': _percentageController.text,
          'dining_price': null,
        }
      };
      
      // Add optional fields if they have values
      if (_selectedMake != null) {
        requestBody['tbl_make_id'] = _selectedMake!.name;
      }
      if (_selectedType != null) {
        requestBody['tbl_type_id'] = _selectedType!.name;
      }
      if (_selectedLocation != null) {
        requestBody['tbl_location_id'] = _selectedLocation!.name;
      }
      
      print('Saving stock with body: $requestBody');
      
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/stock-master'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Stock saved successfully');
        if (!mounted) return;
        Navigator.of(context).pop();
        widget.onSaved();
      } else {
        final errorData = jsonDecode(response.body);
        print('Failed to save stock: ${response.statusCode} - ${response.body}');
        _showError('Failed to save stock: ${errorData['message'] ?? response.statusCode}');
      }
    } catch (e) {
      print('Error saving stock: $e');
      _showError('Failed to save stock: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 500,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.item == null ? 'Add New Stock' : 'Edit Stock Item',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: widget.onCancel,
                ),
              ],
            ),
          ),
          
          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // First Row: Item Code and Name
                    Row(
                      children: [
                        // Item Code
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Item Code',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: TextFormField(
                                  controller: _barCodeController,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Enter item code',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Name',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Enter item name',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Name is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Sinhala Name
                    // Column(
                    //   crossAxisAlignment: CrossAxisAlignment.start,
                    //   children: [
                    //     const Text(
                    //       'Sinhala Name',
                    //       style: TextStyle(
                    //         fontWeight: FontWeight.bold,
                    //         fontSize: 14,
                    //         color: Colors.blueGrey,
                    //       ),
                    //     ),
                    //     const SizedBox(height: 4),
                    //     Container(
                    //       padding: const EdgeInsets.symmetric(horizontal: 12),
                    //       decoration: BoxDecoration(
                    //         border: Border.all(color: Colors.grey[300]!),
                    //         borderRadius: BorderRadius.circular(4),
                    //       ),
                    //       child: TextFormField(
                    //         controller: _sinhalaNameController,
                    //         decoration: const InputDecoration(
                    //           border: InputBorder.none,
                    //           hintText: 'Enter Sinhala name',
                    //         ),
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    
                    // const SizedBox(height: 16),
                    
                    // Second Row: Stock and Category
                    Row(
                      children: [
                        // Stock
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Stock',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<DropdownOption>(
                                    value: _selectedStock,
                                    isExpanded: true,
                                    hint: const Text('Select Stock', style: TextStyle(color: Colors.grey)),
                                    items: widget.stockOptions.map((option) {
                                      return DropdownMenuItem<DropdownOption>(
                                        value: option,
                                        child: Text(option.name),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedStock = value;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Category
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Category',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<DropdownOption>(
                                    value: _selectedCategory,
                                    isExpanded: true,
                                    hint: const Text('Select Category', style: TextStyle(color: Colors.grey)),
                                    items: widget.categoryOptions.map((option) {
                                      return DropdownMenuItem<DropdownOption>(
                                        value: option,
                                        child: Text(option.name),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedCategory = value;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Third Row: Make and Type
                    Row(
                      children: [
                        // Make
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Make',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<DropdownOption>(
                                    value: _selectedMake,
                                    isExpanded: true,
                                    hint: const Text('Select Make', style: TextStyle(color: Colors.grey)),
                                    items: widget.makeOptions.map((option) {
                                      return DropdownMenuItem<DropdownOption>(
                                        value: option,
                                        child: Text(option.name),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedMake = value;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Type
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Type',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<DropdownOption>(
                                    value: _selectedType,
                                    isExpanded: true,
                                    hint: const Text('Select Type', style: TextStyle(color: Colors.grey)),
                                    items: widget.typeOptions.map((option) {
                                      return DropdownMenuItem<DropdownOption>(
                                        value: option,
                                        child: Text(option.name),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedType = value;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Fourth Row: Location and Supplier
                    Row(
                      children: [
                        // Location
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Location',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<DropdownOption>(
                                    value: _selectedLocation,
                                    isExpanded: true,
                                    hint: const Text('Select Location', style: TextStyle(color: Colors.grey)),
                                    items: widget.locationOptions.map((option) {
                                      return DropdownMenuItem<DropdownOption>(
                                        value: option,
                                        child: Text(option.name),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedLocation = value;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Supplier
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Supplier',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<DropdownOption>(
                                    value: _selectedSupplier,
                                    isExpanded: true,
                                    hint: const Text('Select Supplier', style: TextStyle(color: Colors.grey)),
                                    items: widget.supplierOptions.map((option) {
                                      return DropdownMenuItem<DropdownOption>(
                                        value: option,
                                        child: Text(option.name),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedSupplier = value;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Fifth Row: Unit and Quantity
                    Row(
                      children: [
                        // Unit
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Unit',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedUnit,
                                    isExpanded: true,
                                    items: _unitOptions.map((unit) {
                                      return DropdownMenuItem<String>(
                                        value: unit,
                                        child: Text(unit),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() => _selectedUnit = value);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Quantity
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quantity',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: TextFormField(
                                  controller: _quantityController,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Enter quantity',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Sixth Row: Cost and Retail Price
                    Row(
                      children: [
                        // Cost
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cost',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: TextFormField(
                                  controller: _costController,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: '0.00',
                                    prefixText: '\$ ',
                                  ),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Cost is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Retail Price
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Retail Price',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: TextFormField(
                                  controller: _retailPriceController,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: '0.00',
                                    prefixText: '\$ ',
                                  ),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Retail price is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Seventh Row: WS Price and Lot Number
                    Row(
                      children: [
                        // WS Price
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'WS Price',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: TextFormField(
                                  controller: _wsPriceController,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: '0.00',
                                    prefixText: '\$ ',
                                  ),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'WS price is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Lot Number
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Lot Number',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: TextFormField(
                                  controller: _lotNumberController,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: '1',
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Lot number is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Eighth Row: Critical Level and Reorder Level
                    Row(
                      children: [
                        // Critical Level
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Critical Level',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: TextFormField(
                                  controller: _criticalLevelController,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Enter critical level',
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Critical level is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Reorder Level
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reorder Level',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: TextFormField(
                                  controller: _reorderLevelController,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Enter reorder level',
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Reorder level is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Ninth Row: Expiry Date and Expiry Status
                    Row(
                      children: [
                        // Expiry Date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Expiry Date',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: TextFormField(
                                  controller: _expiryDateController,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'yyyy-mm-dd',
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.calendar_today, size: 20),
                                      onPressed: _selectExpiryDate,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Expiry Status
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Expiry Status',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _exStatus,
                                      onChanged: (value) {
                                        setState(() {
                                          _exStatus = value ?? false;
                                        });
                                      },
                                    ),
                                    const Text('Has expiry date'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Tenth Row: Cost Letter and Percentage
                    // Row(
                    //   children: [
                    //     // Cost Letter
                    //     Expanded(
                    //       child: Column(
                    //         crossAxisAlignment: CrossAxisAlignment.start,
                    //         children: [
                    //           const Text(
                    //             'Cost Letter',
                    //             style: TextStyle(
                    //               fontWeight: FontWeight.bold,
                    //               fontSize: 14,
                    //               color: Colors.blueGrey,
                    //             ),
                    //           ),
                    //           const SizedBox(height: 4),
                    //           Container(
                    //             padding: const EdgeInsets.symmetric(horizontal: 12),
                    //             decoration: BoxDecoration(
                    //               border: Border.all(color: Colors.grey[300]!),
                    //               borderRadius: BorderRadius.circular(4),
                    //             ),
                    //             child: TextFormField(
                    //               controller: _costLetterController,
                    //               decoration: const InputDecoration(
                    //                 border: InputBorder.none,
                    //                 hintText: 'Enter cost letter',
                    //               ),
                    //             ),
                    //           ),
                    //         ],
                    //       ),
                    //     ),
                    //     const SizedBox(width: 16),
                    //     // Percentage
                    //     Expanded(
                    //       child: Column(
                    //         crossAxisAlignment: CrossAxisAlignment.start,
                    //         children: [
                    //           const Text(
                    //             'Percentage',
                    //             style: TextStyle(
                    //               fontWeight: FontWeight.bold,
                    //               fontSize: 14,
                    //               color: Colors.blueGrey,
                    //             ),
                    //           ),
                    //           const SizedBox(height: 4),
                    //           Container(
                    //             padding: const EdgeInsets.symmetric(horizontal: 12),
                    //             decoration: BoxDecoration(
                    //               border: Border.all(color: Colors.grey[300]!),
                    //               borderRadius: BorderRadius.circular(4),
                    //             ),
                    //             child: TextFormField(
                    //               controller: _percentageController,
                    //               decoration: const InputDecoration(
                    //                 border: InputBorder.none,
                    //                 hintText: 'Enter percentage',
                    //               ),
                    //               keyboardType: TextInputType.number,
                    //             ),
                    //           ),
                    //         ],
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    
                    // const SizedBox(height: 24),
                    
                    // Product Image
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SELECT PRODUCT IMAGE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[50],
                            ),
                            child: _selectedImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _selectedImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : widget.item?.productImage != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          widget.item!.productImage!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.broken_image,
                                                  size: 40,
                                                  color: Colors.grey[400],
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Image not available',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate,
                                            size: 40,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Click to upload image',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
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
          
          // Footer with CREATE button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: const Border(top: BorderSide(color: Colors.grey, width: 0.5)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveStock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'CREATE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddEditStockDialog extends StatefulWidget {
  final StockItem? item;
  final List<DropdownOption> stockOptions;
  final List<DropdownOption> makeOptions;
  final List<DropdownOption> typeOptions;
  final List<DropdownOption> categoryOptions;
  final List<DropdownOption> locationOptions;
  final List<DropdownOption> supplierOptions;
  final String baseUrl;
  final Future<String?> Function() getToken;
  final VoidCallback onSaved;
  final VoidCallback onCancel;
  const AddEditStockDialog({
    Key? key,
    this.item,
    required this.stockOptions,
    required this.makeOptions,
    required this.typeOptions,
    required this.categoryOptions,
    required this.locationOptions,
    required this.supplierOptions,
    required this.baseUrl,
    required this.getToken,
    required this.onSaved,
    required this.onCancel,
  }) : super(key: key);

  @override
  _AddEditStockDialogState createState() => _AddEditStockDialogState();
}

class _AddEditStockDialogState extends State<AddEditStockDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _itemCodeController;
  late TextEditingController _nameController;
  late TextEditingController _costController;
  late TextEditingController _retailPriceController;
  late TextEditingController _availableQtyController;
  late TextEditingController _criticalLevelController;
  late TextEditingController _reorderLevelController;
  late TextEditingController _expiryDateController;
  
  int? _selectedStockId;
  int? _selectedCategoryId;
  int? _selectedSupplierId;
  int? _selectedMakeId;
  int? _selectedTypeId;
  int? _selectedLocationId;
  
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  
  // For unit dropdown
  final List<String> _unitOptions = ['Pcs', 'KG', 'L', 'M', 'CM', 'BOX', 'SET'];
  String _selectedUnit = 'Pcs';
  
  @override
  void initState() {
    super.initState();
    _itemCodeController = TextEditingController(text: widget.item?.barCode ?? '');
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _costController = TextEditingController(text: widget.item != null ? (widget.item!.cost?.toStringAsFixed(2) ?? '0.00') : '0.00');
    _retailPriceController = TextEditingController(text: widget.item != null ? (widget.item!.retailPrice?.toStringAsFixed(2) ?? '0.00') : '0.00');
    _availableQtyController = TextEditingController(text: widget.item?.availableQty?.toString() ?? '0');
    _criticalLevelController = TextEditingController(text: widget.item?.criticalLevel?.toString() ?? '5');
    _reorderLevelController = TextEditingController(text: widget.item?.reorderLevel?.toString() ?? '10');
    _expiryDateController = TextEditingController(text: widget.item?.expiryDate ?? '');
    
    // Initialize _selectedUnit properly
    if (widget.item?.unit != null && widget.item!.unit.isNotEmpty) {
      // Check if the unit from API is in our list (case-insensitive)
      final unitFromApi = widget.item!.unit;
      final matchedUnit = _unitOptions.firstWhere(
        (unit) => unit.toLowerCase() == unitFromApi.toLowerCase(),
        orElse: () => 'Pcs'
      );
      _selectedUnit = matchedUnit;
    } else {
      _selectedUnit = 'Pcs';
    }
    
    _selectedStockId = widget.item?.stock?.id;
    _selectedCategoryId = widget.item?.category?.id;
    _selectedSupplierId = widget.item?.supplier?.id;
    _selectedMakeId = widget.item?.make?.id;
    _selectedTypeId = widget.item?.type?.id;
    _selectedLocationId = widget.item?.location?.id;
  }
  
  @override
  void dispose() {
    _itemCodeController.dispose();
    _nameController.dispose();
    _costController.dispose();
    _retailPriceController.dispose();
    _availableQtyController.dispose();
    _criticalLevelController.dispose();
    _reorderLevelController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _selectExpiryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _expiryDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _saveStock() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final token = await widget.getToken();
      if (token == null) {
        _showError('No authentication token found');
        setState(() => _isLoading = false);
        return;
      }
      
      var request = http.MultipartRequest(
        widget.item == null ? 'POST' : 'PUT',
        Uri.parse(widget.item == null 
            ? '${widget.baseUrl}/stock-master'
            : '${widget.baseUrl}/stock-master/${widget.item!.id}'),
      );
      
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      
      request.fields['name'] = _nameController.text.trim();
      request.fields['bar_code'] = _itemCodeController.text.trim();
      request.fields['unit'] = _selectedUnit;
      
      if (_selectedStockId != null) request.fields['tbl_stock_id'] = _selectedStockId.toString();
      if (_selectedCategoryId != null) request.fields['tbl_category_id'] = _selectedCategoryId.toString();
      if (_selectedSupplierId != null) request.fields['tbl_supplier_id'] = _selectedSupplierId.toString();
      if (_selectedMakeId != null) request.fields['tbl_make_id'] = _selectedMakeId.toString();
      if (_selectedTypeId != null) request.fields['tbl_type_id'] = _selectedTypeId.toString();
      if (_selectedLocationId != null) request.fields['tbl_location_id'] = _selectedLocationId.toString();
      
      if (_costController.text.isNotEmpty && _costController.text != '0.00') {
        request.fields['cost'] = _costController.text;
      }
      if (_retailPriceController.text.isNotEmpty && _retailPriceController.text != '0.00') {
        request.fields['retail_price'] = _retailPriceController.text;
      }
      if (_availableQtyController.text.isNotEmpty && _availableQtyController.text != '0') {
        request.fields['available_qty'] = _availableQtyController.text;
      }
      if (_criticalLevelController.text.isNotEmpty) {
        request.fields['critical_level'] = _criticalLevelController.text;
      }
      if (_reorderLevelController.text.isNotEmpty) {
        request.fields['reorder_level'] = _reorderLevelController.text;
      }
      if (_expiryDateController.text.isNotEmpty) {
        request.fields['expiry_date'] = _expiryDateController.text;
      }
      
      if (_selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'product_image',
            _selectedImage!.path,
          ),
        );
      }
      
      print('Sending request with fields: ${request.fields}');
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Stock saved successfully');
        if (!mounted) return;
        Navigator.of(context).pop();
        widget.onSaved();
      } else {
        print('Failed to save stock: ${response.statusCode} - ${response.body}');
        _showError('Failed to save stock: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error saving stock: $e');
      _showError('Failed to save stock: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 600,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.item == null ? 'Add New Stock' : 'Edit Stock Item',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: widget.onCancel,
                ),
              ],
            ),
          ),
          
          // Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // First Row: Item Code and Stock
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Item Code',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _itemCodeController,
                                decoration: InputDecoration(
                                  hintText: 'Enter item code',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Stock',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: _selectedStockId,
                                decoration: InputDecoration(
                                  hintText: 'Select Stock',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<int>(
                                    value: null,
                                    child: Text('Select Stock', style: TextStyle(color: Colors.grey)),
                                  ),
                                  ...widget.stockOptions.map((option) {
                                    return DropdownMenuItem<int>(
                                      value: option.id,
                                      child: Text(option.name),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedStockId = value);
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Please select a stock';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Category
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Category',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: _selectedCategoryId,
                          decoration: InputDecoration(
                            hintText: 'Select Category',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('Select Category', style: TextStyle(color: Colors.grey)),
                            ),
                            ...widget.categoryOptions.map((option) {
                              return DropdownMenuItem<int>(
                                value: option.id,
                                child: Text(option.name),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedCategoryId = value);
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a category';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Name
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Name',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Enter item name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Name is required';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Cost and Retail Price
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cost',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _costController,
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  prefixText: '\$ ',
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Cost is required';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Retail Price',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _retailPriceController,
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  prefixText: '\$ ',
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Retail price is required';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Unit and Available Qty
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Unit',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _selectedUnit,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                items: _unitOptions.map((unit) {
                                  return DropdownMenuItem<String>(
                                    value: unit,
                                    child: Text(unit),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedUnit = value);
                                  }
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Unit is required';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Available Qty',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _availableQtyController,
                                decoration: InputDecoration(
                                  hintText: '0',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Available quantity is required';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Critical Level and Reorder Level
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Critical Level',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _criticalLevelController,
                                decoration: InputDecoration(
                                  hintText: '5',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Critical level is required';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reorder Level',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _reorderLevelController,
                                decoration: InputDecoration(
                                  hintText: '10',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Reorder level is required';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Supplier and Expiry Date
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Supplier',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: _selectedSupplierId,
                                decoration: InputDecoration(
                                  hintText: 'Select Supplier',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<int>(
                                    value: null,
                                    child: Text('Select Supplier', style: TextStyle(color: Colors.grey)),
                                  ),
                                  ...widget.supplierOptions.map((option) {
                                    return DropdownMenuItem<int>(
                                      value: option.id,
                                      child: Text(option.name),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedSupplierId = value);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Expiry Date',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _expiryDateController,
                                readOnly: true,
                                decoration: InputDecoration(
                                  hintText: 'yyyy-mm-dd',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.calendar_today),
                                    onPressed: _selectExpiryDate,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Additional fields: Make, Type, Location
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Make',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: _selectedMakeId,
                                decoration: InputDecoration(
                                  hintText: 'Select Make',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<int>(
                                    value: null,
                                    child: Text('Select Make', style: TextStyle(color: Colors.grey)),
                                  ),
                                  ...widget.makeOptions.map((option) {
                                    return DropdownMenuItem<int>(
                                      value: option.id,
                                      child: Text(option.name),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedMakeId = value);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Type',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: _selectedTypeId,
                                decoration: InputDecoration(
                                  hintText: 'Select Type',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<int>(
                                    value: null,
                                    child: Text('Select Type', style: TextStyle(color: Colors.grey)),
                                  ),
                                  ...widget.typeOptions.map((option) {
                                    return DropdownMenuItem<int>(
                                      value: option.id,
                                      child: Text(option.name),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedTypeId = value);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Location',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                value: _selectedLocationId,
                                decoration: InputDecoration(
                                  hintText: 'Select Location',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<int>(
                                    value: null,
                                    child: Text('Select Location', style: TextStyle(color: Colors.grey)),
                                  ),
                                  ...widget.locationOptions.map((option) {
                                    return DropdownMenuItem<int>(
                                      value: option.id,
                                      child: Text(option.name),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedLocationId = value);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Product Image
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SELECT PRODUCT IMAGE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[50],
                            ),
                            child: _selectedImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _selectedImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : widget.item?.productImage != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          widget.item!.productImage!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.broken_image,
                                                  size: 40,
                                                  color: Colors.grey[400],
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Image not available',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate,
                                            size: 40,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Click to upload image',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
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
          
          // Footer with buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: const Border(top: BorderSide(color: Colors.grey, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveStock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add, size: 18),
                            const SizedBox(width: 8),
                            Text(widget.item == null ? 'CREATE' : 'UPDATE'),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Updated StockItem model with additional fields
class StockItem {
  final int id;
  final String? barCode;
  final String name;
  final String? sinhalaName;
  final String unit;
  final double? cost;
  final double? retailPrice;
  final int? availableQty;
  final int? criticalLevel;
  final int? reorderLevel;
  final String? expiryDate;
  final StockInfo? stock;
  final LocationInfo? location;
  final MakeInfo? make;
  final TypeInfo? type;
  final CategoryInfo? category;
  final SupplierInfo? supplier;
  final String? productImage;
  
  StockItem({
    required this.id,
    this.barCode,
    required this.name,
    this.sinhalaName,
    required this.unit,
    this.cost,
    this.retailPrice,
    this.availableQty,
    this.criticalLevel,
    this.reorderLevel,
    this.expiryDate,
    this.stock,
    this.location,
    this.make,
    this.type,
    this.category,
    this.supplier,
    this.productImage,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      id: json['id'] ?? 0,
      barCode: json['bar_code'],
      name: json['name'] ?? '',
      sinhalaName: json['s_name'],
      unit: json['unit'] ?? 'PCS',
      cost: json['cost'] != null ? double.tryParse(json['cost'].toString()) : null,
      retailPrice: json['retail_price'] != null ? double.tryParse(json['retail_price'].toString()) : null,
      availableQty: json['available_qty'] != null ? int.tryParse(json['available_qty'].toString()) : null,
      criticalLevel: json['critical_level'] != null ? int.tryParse(json['critical_level'].toString()) : null,
      reorderLevel: json['reorder_level'] != null ? int.tryParse(json['reorder_level'].toString()) : null,
      expiryDate: json['expiry_date'],
      stock: json['stock'] != null ? StockInfo.fromJson(json['stock']) : null,
      location: json['location'] != null ? LocationInfo.fromJson(json['location']) : null,
      make: json['make'] != null ? MakeInfo.fromJson(json['make']) : null,
      type: json['type'] != null ? TypeInfo.fromJson(json['type']) : null,
      category: json['category'] != null ? CategoryInfo.fromJson(json['category']) : null,
      supplier: json['supplier'] != null ? SupplierInfo.fromJson(json['supplier']) : null,
      productImage: json['product_image'] != null
          ? 'https://api-kafenio.sltcloud.lk/storage/${json['product_image']}'
          : null,
    );
  }
}

class StockInfo {
  final int id;
  final String name;
  StockInfo({required this.id, required this.name});
  
  factory StockInfo.fromJson(Map<String, dynamic> json) {
    return StockInfo(
      id: json['id'] ?? 0,
      name: json['stock_name'] ?? json['name'] ?? '',
    );
  }
}

class LocationInfo {
  final int id;
  final String name;
  LocationInfo({required this.id, required this.name});
  
  factory LocationInfo.fromJson(Map<String, dynamic> json) {
    return LocationInfo(
      id: json['id'] ?? 0,
      name: json['location'] ?? json['name'] ?? '',
    );
  }
}

class MakeInfo {
  final int id;
  final String name;
  MakeInfo({required this.id, required this.name});
  
  factory MakeInfo.fromJson(Map<String, dynamic> json) {
    return MakeInfo(
      id: json['id'] ?? 0,
      name: json['make_name'] ?? json['name'] ?? '',
    );
  }
}

class TypeInfo {
  final int id;
  final String name;
  TypeInfo({required this.id, required this.name});
  
  factory TypeInfo.fromJson(Map<String, dynamic> json) {
    return TypeInfo(
      id: json['id'] ?? 0,
      name: json['type_name'] ?? json['name'] ?? '',
    );
  }
}

class CategoryInfo {
  final int id;
  final String name;
  CategoryInfo({required this.id, required this.name});
  
  factory CategoryInfo.fromJson(Map<String, dynamic> json) {
    return CategoryInfo(
      id: json['id'] ?? 0,
      name: json['category_name'] ?? json['name'] ?? '',
    );
  }
}

class SupplierInfo {
  final int id;
  final String name;
  SupplierInfo({required this.id, required this.name});
  
  factory SupplierInfo.fromJson(Map<String, dynamic> json) {
    return SupplierInfo(
      id: json['id'] ?? 0,
      name: json['commpany'] ?? json['name'] ?? '',
    );
  }
}

class DropdownOption {
  final int id;
  final String name;
  DropdownOption({required this.id, required this.name});
  
  factory DropdownOption.fromJson(Map<String, dynamic> json) {
    return DropdownOption(
      id: json['id'] ?? 0,
      name: json['name'] ??
           json['stock_name'] ??
           json['make_name'] ??
           json['type_name'] ??
           json['category_name'] ??
           json['location'] ??
           json['commpany'] ?? '',
    );
  }
}