
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resturant/CashBookScreen.dart';

import 'package:resturant/DashboardScreen.dart';
import 'package:resturant/InvoiceManagementScreen.dart';
import 'package:resturant/ProfileScreen.dart';
import 'package:resturant/StockScreen.dart';
import 'package:resturant/TellerCashBook.dart';

import 'package:shared_preferences/shared_preferences.dart';

class MainDashboardScreen extends StatelessWidget {
  const MainDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POS Masters Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      home: WelcomeScreen(), 
    );
  }
}

// ==================== WELCOME SCREEN WITH SIDE NAV ONLY ====================
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? _userData;
  Map<String, bool> _userPermissions = {};
  int _userType = 1; // Default to user (1 = regular user, 0 = admin)
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndPermissions();
  }
 Map<String, bool> _parsePhpSerializedAccessList(String serialized) {
    final permissions = <String, bool>{};
    
    // Simple parsing for the PHP serialized format
    final regex = RegExp(r's:(\d+):"([^"]+)";b:(\d)');
    final matches = regex.allMatches(serialized);
    
    for (final match in matches) {
      final key = match.group(2);
      final value = match.group(3);
      if (key != null && value != null) {
        permissions[key] = value == '1';
      }
    }
    
    // Also check for other common permission formats
    if (permissions.isEmpty) {
      // Alternative regex pattern
      final altRegex = RegExp(r'"([^"]+)";b:(\d)');
      final altMatches = altRegex.allMatches(serialized);
      
      for (final match in altMatches) {
        final key = match.group(1);
        final value = match.group(2);
        if (key != null && value != null) {
          permissions[key] = value == '1';
        }
      }
    }
    
    return permissions;
  }
  Future<void> _loadUserDataAndPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      
      if (userDataString != null) {
        final userData = json.decode(userDataString);
        setState(() {
          _userData = userData;
          _userType = userData['type'] ?? 1;
          
        
          if (userData['access_list'] != null) {
            if (userData['access_list'] is String) {
            
              try {
                final accessString = userData['access_list'];
               
                final Map<String, dynamic> accessMap = {};
                
                if (accessString.startsWith('a:')) {
                
                  _userPermissions = {
                    'inv': accessString.contains('"inv";b:1'),
                    'cusMana': accessString.contains('"cusMana";b:1'),
                    'stockMana': accessString.contains('"stockMana";b:1'),
                    'itemReturn': accessString.contains('"itemReturn";b:1'),
                    'invMana': accessString.contains('"invMana";b:1'),
                    'mainCashbook': accessString.contains('"mainCashbook";b:1'),
                    'stockReports': accessString.contains('"stockReports";b:1'),
                    'saleReport': accessString.contains('"saleReport";b:1'),
                    'userPro': accessString.contains('"userPro";b:1'),
                    'grn': accessString.contains('"grn";b:1'),
                    'invCancel': accessString.contains('"invCancel";b:1'),
                    'a_cr_m': accessString.contains('"a_cr_m";b:1'),
                    'a_de_m': accessString.contains('"a_de_m";b:1'),
                    'a_le': accessString.contains('"a_le";b:1'),
                    'a_bb': accessString.contains('"a_bb";b:1'),
                    'a_cph': accessString.contains('"a_cph";b:1'),
                  };
                }
              } catch (e) {
                print('Error parsing access_list string: $e');
                _setDefaultPermissions();
              }
            } else if (userData['access_list'] is Map) {
         
              final accessMap = Map<String, dynamic>.from(userData['access_list']);
              _userPermissions = accessMap.map((key, value) => 
                MapEntry(key, value == true || value == 1 || value == '1'));
            } else {
              _setDefaultPermissions();
            }
          } else {
            _setDefaultPermissions();
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
        _setDefaultPermissions();
      });
    }
  }

  void _setDefaultPermissions() {

    _userPermissions = {
      'inv': true, 
      'cusMana': _userType == 0, 
      'stockMana': _userType == 0, 
      'itemReturn': _userType == 0,
      'invMana': _userType == 0,
      'mainCashbook': _userType == 0,
      'stockReports': _userType == 0,
      'saleReport': _userType == 0,
      'userPro': _userType == 0,
      'grn': _userType == 0,
      'invCancel': _userType == 0,
      'a_cr_m': _userType == 0,
      'a_de_m': _userType == 0,
      'a_le': _userType == 0,
      'a_bb': _userType == 0,
      'a_cph': _userType == 0,
    };
  }


  bool _hasPermission(String permissionKey) {
    return _userPermissions[permissionKey] ?? false;
  }


  bool get _isAdmin => _userType == 0;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.indigo,
              ),
              SizedBox(height: 20),
              Text(
                'Loading user permissions...',
                style: TextStyle(
                  color: Colors.indigo,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildSideNavigationDrawer(),
      appBar: AppBar(
        title: Text('Welcome ${_userData?['name'] ?? 'User'}'),
        backgroundColor: Colors.indigo,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          
          Container(
            margin: EdgeInsets.only(right: 16),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _isAdmin ? Colors.amber[700] : Colors.blue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isAdmin ? 'ADMIN' : 'USER',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
             
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isAdmin ? Colors.amber[100] : Colors.blue[100],
                  border: Border.all(
                    color: _isAdmin ? Colors.amber : Colors.blue,
                    width: 3,
                  ),
                ),
                child: Icon(
                  _isAdmin ? Icons.admin_panel_settings : Icons.person,
                  size: 50,
                  color: _isAdmin ? Colors.amber[700] : Colors.blue[700],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome ${_userData?['name'] ?? 'User'}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isAdmin ? 'Administrator Dashboard' : 'User Dashboard',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DashboardScreen()),
                  );
                },
                icon: const Icon(Icons.dashboard_outlined),
                label: const Text('Go to Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

 
  Widget _buildSideNavigationDrawer() {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade50,
              Colors.white,
            ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
           
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.transparent),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isAdmin ? Colors.amber[100] : Colors.blue[100],
                      border: Border.all(
                        color: _isAdmin ? Colors.amber : Colors.blue,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      _isAdmin ? Icons.admin_panel_settings : Icons.person,
                      size: 40,
                      color: _isAdmin ? Colors.amber[700] : Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _userData?['name'] ?? 'User',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isAdmin ? 'Administrator' : 'User',
                    style: TextStyle(
                      color: _isAdmin ? Colors.amber[700] : Colors.blue[700],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            
            _buildDrawerItem(
              Icons.dashboard_outlined, 
              "Dashboard", 
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                );
              },
              showAlways: true,
            ),
            
           
            if (_hasPermission('stockMana') || _isAdmin)
              _buildDrawerItem(
                Icons.inventory_2_outlined, 
                "New Stock", 
                () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StockScreen()),
                  );
                },
              ),
            
          
            if (_hasPermission('invMana') || _isAdmin)
              _buildDrawerItem(
                Icons.inventory_2_outlined, 
                "Invoice Management", 
                () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => InvoiceManagementScreen()),
                  );
                },
              ),
            
           
            if (_hasPermission('mainCashbook') || _isAdmin)
              _buildDrawerItem(
                Icons.inventory_2_outlined, 
                "Teller CashBook", 
                () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TellerCashBook()),
                  );
                },
              ),
            
          
            if (_hasPermission('mainCashbook') || _isAdmin)
              _buildDrawerItem(
                Icons.payments_outlined, 
                "Cash Book", 
                () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CashBookScreen()),
                  );
                },
              ),
            
          
            _buildDrawerItem(
              Icons.account_balance_outlined, 
              "Profile", 
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              showAlways: true,
            ),
            
        
            if (_isAdmin || 
                _hasPermission('stockMana') || 
                _hasPermission('invMana') || 
                _hasPermission('mainCashbook'))
              const Divider(indent: 20, endIndent: 20, thickness: 0.5),
       
            if (_isAdmin || _hasPermission('userPro'))
              _buildDrawerItem(
                Icons.settings_outlined, 
                "Settings", 
                () {
                  Navigator.pop(context);
                 
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Settings screen coming soon')),
                  );
                },
              ),
            
     
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () => _confirmLogout(),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text("Logout", style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
    
            if (!_isAdmin && 
                !_hasPermission('stockMana') && 
                !_hasPermission('invMana') && 
                !_hasPermission('mainCashbook'))
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color.fromARGB(255, 243, 213, 123)),
                  ),
                  child: Text(
                    'Limited access - Contact administrator for more permissions',
                    style: TextStyle(
                      color: Colors.amber[800],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, 
      {bool showAlways = false}) {
    return ListTile(
      leading: Icon(icon, color: Colors.indigo, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  void _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (shouldLogout == true) _logout();
  }

  void _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

