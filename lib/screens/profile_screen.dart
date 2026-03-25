import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String baseUrl = "https://navith-25-lankatransit-backend.hf.space";

  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('user_id');
      String? token = prefs.getString('jwt_token');

      if (userId == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _userData = jsonDecode(response.body);
        });
      }
    } catch (e) {
      _showMessage('Failed to load profile data!', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _updateProfile(String name, String email, String phone) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('user_id');
      String? token = prefs.getString('jwt_token');

      if (userId == null || _userData == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'role': _userData!['role'],
        }),
      );

      if (response.statusCode == 200) {
        _showMessage('Profile Updated Successfully!', Colors.green);
        _fetchUserDetails();
        return true;
      } else {
        _showMessage('Failed to update profile!', Colors.red);
        return false;
      }
    } catch (e) {
      _showMessage('Error updating profile!', Colors.red);
      return false;
    }
  }

  Future<void> _deleteAccount() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('user_id');
      String? token = prefs.getString('jwt_token');

      if (userId == null) return;

      final response = await http.delete(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showMessage('Account Deleted Successfully!', Colors.green);
        await prefs.clear();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      } else {
        _showMessage('Failed to delete account!', Colors.red);
      }
    } catch (e) {
      _showMessage('Error deleting account!', Colors.red);
    }
  }

  void _showMessage(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showEditProfileSheet() {
    if (_userData == null) return;

    final TextEditingController nameCtrl = TextEditingController(
      text: _userData!['name'],
    );
    final TextEditingController emailCtrl = TextEditingController(
      text: _userData!['email'],
    );
    final TextEditingController phoneCtrl = TextEditingController(
      text: _userData!['phone'] ?? '',
    );
    bool isUpdating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Edit Profile',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline, color: Colors.green),
                  filled: true,
                  fillColor: Colors.green.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.green),
                  filled: true,
                  fillColor: Colors.green.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined, color: Colors.green),
                  filled: true,
                  fillColor: Colors.green.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 2,
                  ),
                  onPressed: isUpdating
                      ? null
                      : () async {
                          setSheetState(() => isUpdating = true);
                          bool success = await _updateProfile(
                            nameCtrl.text,
                            emailCtrl.text,
                            phoneCtrl.text,
                          );
                          if (success && sheetContext.mounted)
                            Navigator.pop(sheetContext);
                          setSheetState(() => isUpdating = false);
                        },
                  child: isUpdating
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and you will lose all your data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAccount();
            },
            child: const Text(
              'Yes, Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : _userData == null
          ? const Center(child: Text('Failed to load profile data.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.green.withOpacity(0.1),
                          backgroundImage: _userData!['profilePhotoUrl'] != null
                              ? NetworkImage(
                                  '$baseUrl${_userData!['profilePhotoUrl']}',
                                )
                              : null,
                          child: _userData!['profilePhotoUrl'] == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 70,
                                  color: Colors.green,
                                )
                              : null,
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: IconButton(
                          onPressed: _showEditProfileSheet,
                          icon: const Icon(Icons.edit_rounded, color: Colors.green, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Text(
                    _userData!['name'] ?? 'Unknown User',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _userData!['role'] ?? 'USER',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),

                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.email_outlined, color: Colors.green),
                            ),
                            title: const Text('Email Address', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            subtitle: Text(
                              _userData!['email'] ?? 'Not provided',
                              style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500),
                            ),
                          ),
                          const Divider(indent: 70, endIndent: 20),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.phone_outlined, color: Colors.green),
                            ),
                            title: const Text('Phone Number', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            subtitle: Text(
                              _userData!['phone'] ?? 'Not provided',
                              style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500),
                            ),
                          ),
                          const Divider(indent: 70, endIndent: 20),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.verified_user_outlined, color: Colors.green),
                            ),
                            title: const Text('Account Status', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            subtitle: Text(
                              _userData!['status'] ?? 'UNKNOWN',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: const Text(
                        'Delete My Account',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _showDeleteConfirmation,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
