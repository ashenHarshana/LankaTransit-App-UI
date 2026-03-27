import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'route_management_screen.dart';
import 'owner_management_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _pendingUsers = [];
  List<dynamic> _pendingBuses = [];
  bool _isLoading = true;

  final String baseUrl = "https://navith-25-lankatransit-backend.hf.space";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchPendingData();
  }

  Future<void> _fetchPendingData() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final userResponse = await http.get(
        Uri.parse('$baseUrl/api/users/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (userResponse.statusCode == 200) {
        setState(() {
          _pendingUsers = jsonDecode(userResponse.body);
        });
      }

      final busResponse = await http.get(
        Uri.parse('$baseUrl/api/buses/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (busResponse.statusCode == 200) {
        setState(() {
          _pendingBuses = jsonDecode(busResponse.body);
        });
      }
    } catch (e) {
      _showMessage('Error fetching data!', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout Confirmation', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        content: const Text('Are you sure you want to log out of LankaTransit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
            child: const Text('Yes, Logout'),
          ),
        ],
      ),
    );
  }

  void _showUserDocumentDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Documents: ${user['name']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDocImage('Profile Photo', user['profilePhotoUrl']),
                _buildDocImage('NIC Front', user['nicFrontUrl']),
                _buildDocImage('NIC Back', user['nicBackUrl']),
                _buildDocImage('License', user['licensePhotoUrl']),
              ],
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _approveUser(user['id']);
                  },
                  child: const Text('Approve'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _resubmitUser(user['id']);
                  },
                  child: const Text('Resubmit Docs'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _rejectUser(user['id']);
                  },
                  child: const Text('Reject'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBusDocumentDialog(Map<String, dynamic> bus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Bus Docs: ${bus['busNumber']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDocImage(
                  'Registration Potha (CR)',
                  bus['registrationPothaUrl'],
                ),
                _buildDocImage('Insurance Card', bus['insuranceCardUrl']),
                _buildDocImage('Revenue License', bus['revenueLicenseUrl']),
                _buildDocImage('Route Permit', bus['routePermitUrl']),
              ],
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _approveBus(bus['id']);
                  },
                  child: const Text('Approve Bus'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _resubmitBus(bus['id']);
                  },
                  child: const Text('Resubmit Docs'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _rejectBus(bus['id']);
                  },
                  child: const Text('Reject Bus'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocImage(String title, String? url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        url != null && url.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  '$baseUrl$url',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Text(
                        'Image not found',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ),
              )
            : const Text(
                'No document uploaded',
                style: TextStyle(color: Colors.grey),
              ),
        const Divider(),
      ],
    );
  }

  Future<void> _approveUser(int id) async =>
      _updateStatus('users/approve', id, 'User Approved! ✅', Colors.green);
  Future<void> _rejectUser(int id) async =>
      _updateStatus('users/reject', id, 'User Rejected! ❌', Colors.red);
  Future<void> _resubmitUser(int id) async => _updateStatus(
    'users/resubmit',
    id,
    'Requested to Resubmit Docs! 🔄',
    Colors.orange,
  );

  Future<void> _approveBus(int id) async =>
      _updateStatus('buses/approve', id, 'Bus Approved! 🚌✅', Colors.green);
  Future<void> _rejectBus(int id) async =>
      _updateStatus('buses/reject', id, 'Bus Rejected! 🚌❌', Colors.red);
  Future<void> _resubmitBus(int id) async => _updateStatus(
    'buses/resubmit',
    id,
    'Requested to Resubmit Bus Docs! 🔄',
    Colors.orange,
  );

  Future<void> _updateStatus(
    String endpoint,
    int id,
    String successMsg,
    Color color,
  ) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.put(
        Uri.parse('$baseUrl/api/$endpoint/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showMessage(successMsg, color);
        _fetchPendingData();
      }
    } catch (e) {
      _showMessage('Action Failed!', Colors.red);
    }
  }

  void _showMessage(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'Users'),
            Tab(icon: Icon(Icons.directions_bus_rounded), text: 'Buses'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.business_center_rounded),
            tooltip: 'Manage Owners',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OwnerManagementScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.map_rounded),
            tooltip: 'Manage Routes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RouteManagementScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[50],
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.green))
            : TabBarView(
                controller: _tabController,
                children: [
                  _pendingUsers.isEmpty
                      ? const Center(child: Text('No pending users! 🎉', style: TextStyle(fontSize: 16, color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _pendingUsers.length,
                          itemBuilder: (context, index) {
                            var user = _pendingUsers[index];
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.withOpacity(0.1),
                                  child: const Icon(Icons.person, color: Colors.green),
                                ),
                                title: Text(
                                  user['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  '${user['role']} | ${user['email']}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _showUserDocumentDialog(user),
                                  child: const Text('View'),
                                ),
                              ),
                            );
                          },
                        ),
                  _pendingBuses.isEmpty
                      ? const Center(child: Text('No pending buses! 🎉', style: TextStyle(fontSize: 16, color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _pendingBuses.length,
                          itemBuilder: (context, index) {
                            var bus = _pendingBuses[index];
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green.withOpacity(0.1),
                                  child: const Icon(Icons.directions_bus, color: Colors.green),
                                ),
                                title: Text(
                                  bus['busNumber'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  'Capacity: ${bus['capacity']} | Route ID: ${bus['routeId']}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _showBusDocumentDialog(bus),
                                  child: const Text('View'),
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
      ),
    );
  }
}
