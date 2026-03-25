import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'register_screen.dart';
import 'home_screen.dart';
import 'driver_home_screen.dart';
import 'owner_home_screen.dart';
import 'admin_home_screen.dart';
import 'document_upload_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> loginUser() async {
    setState(() {
      _isLoading = true;
    });

    final String email = _emailController.text;
    final String password = _passwordController.text;

    final url = Uri.parse(
      'https://navith-25-lankatransit-backend.hf.space/api/users/login',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        String token = responseData['token'];
        String role = responseData['role'];
        String userEmail = responseData['email'];
        String userName = responseData['name'] ?? "User";
        String status = responseData['status'] ?? 'APPROVED';
        int? userId = responseData['id'];

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userEmail', userEmail);
        await prefs.setString('user_name', userName);
        await prefs.setString('jwt_token', token);
        await prefs.setString('user_role', role);
        await prefs.setString('user_status', status);

        if (userId != null) {
          await prefs.setInt('user_id', userId);
        }

        if (!mounted) return;

        if (status == 'PENDING' && role == 'OWNER') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const DocumentUploadScreen(),
            ),
          );
        } else {
          if (role == 'ADMIN') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
            );
          } else if (role == 'DRIVER' || role == 'CONDUCTOR') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
            );
          } else if (role == 'OWNER') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const OwnerHomeScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        }
      } else if (response.statusCode == 403) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account is pending admin verification!'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid Email or Password!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server Error.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.directions_bus_filled_rounded,
                  size: 100,
                  color: Colors.green,
                ),
                const SizedBox(height: 20),
                const Text(
                  'LankaTransit',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    letterSpacing: 1.2,
                  ),
                ),
                const Text(
                  'Travel with Comfort',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 50),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'example@gmail.com',
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.green),
                    filled: true,
                    fillColor: Colors.green.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Colors.green, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: '********',
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.green),
                    filled: true,
                    fillColor: Colors.green.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Colors.green, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Forgot Password?', style: TextStyle(color: Colors.green)),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: _isLoading ? null : loginUser,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Don\'t have an account? '),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Create Account',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
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
    );
  }
}
