
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resturant/DashboardScreen.dart';
import 'package:resturant/InvoiceManagementScreen.dart';
import 'package:resturant/StockScreen.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildSideNavigationDrawer(),
      appBar: AppBar(
        title: const Text('Welcome to POS Masters'),
        backgroundColor: Colors.indigo,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
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
              // Your welcome content here
              const Icon(
                Icons.dashboard,
                size: 80,
                color: Colors.indigo,
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome to POS Masters',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Select an option from the side menu',
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

  // Side Navigation Drawer
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
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.indigo.shade100,
                    child: ClipOval(
                      child: Image.asset(
                        'images/slt.png',
                        fit: BoxFit.cover,
                        width: 90,
                        height: 90,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SLT Dashboard',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ),
            ),
            // Drawer Items
            _buildDrawerItem(Icons.dashboard_outlined, "Dashboard", () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              );
            }),
            _buildDrawerItem(Icons.inventory_2_outlined, "New Stock", () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StockScreen()),
              );
            }),
            _buildDrawerItem(Icons.inventory_2_outlined, "Invoice Management", () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => InvoiceManagementScreen()),
              );
            }),
            // _buildDrawerItem(Icons.inventory_2_outlined, "Job History", () {
            //   Navigator.pop(context);
            //   Navigator.push(
            //     context,
            //     MaterialPageRoute(builder: (_) => JobHistoryScreen()),
            //   );
            // }),
            // _buildDrawerItem(Icons.payments_outlined, "Cash Book", () {
            //   Navigator.pop(context);
            //   Navigator.push(
            //     context,
            //     MaterialPageRoute(builder: (_) => CashBookScreen()),
            //   );
            // }),
            // _buildDrawerItem(Icons.account_balance_outlined, "Teller Cash Book", () {
            //   Navigator.pop(context);
            //   Navigator.push(
            //     context,
            //     MaterialPageRoute(builder: (_) => const TellerCashBookScreen()),
            //   );
            // }),
            // _buildDrawerItem(Icons.account_balance_outlined, "Invoice Management", () {
            //   Navigator.pop(context);
            //   Navigator.push(
            //     context,
            //     MaterialPageRoute(builder: (_) => const InvoiceManagementScreen()),
            //   );
            // }),
            // _buildDrawerItem(Icons.inventory_2_outlined, "Payment & Receipt", () {
            //   Navigator.pop(context);
            //   Navigator.push(
            //     context,
            //     MaterialPageRoute(builder: (_) => const PaymentReceiptScreen()),
            //   );
            // }),
            // _buildDrawerItem(Icons.inventory_2_outlined, "Stocks", () {
            //   Navigator.pop(context);
            //   Navigator.push(
            //     context,
            //     MaterialPageRoute(builder: (_) => const StockDashboardScreen()),
            //   );
            // }),
            // _buildDrawerItem(Icons.inventory_2_outlined, "Accounts", () {
            //   Navigator.pop(context);
            //   Navigator.push(
            //     context,
            //     MaterialPageRoute(builder: (_) => const AccountsScreen()),
            //   );
            // }),
            // _buildDrawerItem(Icons.assessment_outlined, "Reports", () {
            //   Navigator.pop(context);
            //   Navigator.push(
            //     context,
            //     MaterialPageRoute(builder: (_) => ReportsScreen()),
            //   );
            // }),
            const Divider(indent: 20, endIndent: 20, thickness: 0.5),
            _buildDrawerItem(Icons.settings_outlined, "Settings", () {
              Navigator.pop(context);
              // Add settings screen navigation
            }),
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
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
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

