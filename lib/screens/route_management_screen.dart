import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_halt_map_screen.dart';

class RouteManagementScreen extends StatefulWidget {
  const RouteManagementScreen({super.key});
  @override
  State<RouteManagementScreen> createState() => _RouteManagementScreenState();
}

class _RouteManagementScreenState extends State<RouteManagementScreen> {
  final String baseUrl = "https://navith-25-lankatransit-backend.hf.space";
  List<dynamic> _routes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
  }

  Future<void> _fetchRoutes() async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      final response = await http.get(Uri.parse('$baseUrl/api/routes'), headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        setState(() => _routes = jsonDecode(response.body));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error fetching routes"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Route & Halt Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.green)) 
          : _routes.isEmpty 
            ? const Center(child: Text("No routes found"))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _routes.length,
                itemBuilder: (ctx, i) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.alt_route_rounded, color: Colors.white),
                    ),
                    title: Text(
                      'Route ${_routes[i]['routeNumber']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Text('${_routes[i]['startLocation']} ➔ ${_routes[i]['endLocation']}'),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddHaltMapScreen(routeData: _routes[i]),
                          ),
                        ).then((_) => _fetchRoutes()); // Refresh when coming back
                      },
                      icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                      label: const Text('Add Halts'),
                    ),
                  ),
                ),
              ),
    );
  }
}
