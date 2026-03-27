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

  final TextEditingController _routeNumberController = TextEditingController();
  final TextEditingController _startLocationController = TextEditingController();
  final TextEditingController _endLocationController = TextEditingController();
  final TextEditingController _baseFareController = TextEditingController();

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
      _showError("Error fetching routes");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addRoute() async {
    if (_routeNumberController.text.isEmpty || 
        _startLocationController.text.isEmpty || 
        _endLocationController.text.isEmpty || 
        _baseFareController.text.isEmpty) {
      _showError("Please fill all fields");
      return;
    }

    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('$baseUrl/api/routes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'routeNumber': _routeNumberController.text,
          'startLocation': _startLocationController.text,
          'endLocation': _endLocationController.text,
          'baseFarePerKm': double.parse(_baseFareController.text),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _routeNumberController.clear();
        _startLocationController.clear();
        _endLocationController.clear();
        _baseFareController.clear();
        _fetchRoutes();
        if (mounted) Navigator.pop(context);
        _showSuccess("Route Added Successfully!");
      } else {
        _showError("Failed to add route");
      }
    } catch (e) {
      _showError("Error adding route");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddRouteSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24, right: 24, top: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add New Route', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              _buildTextField(_routeNumberController, 'Route Number', Icons.numbers),
              const SizedBox(height: 12),
              _buildTextField(_startLocationController, 'Start Location', Icons.location_on),
              const SizedBox(height: 12),
              _buildTextField(_endLocationController, 'End Location', Icons.flag),
              const SizedBox(height: 12),
              _buildTextField(_baseFareController, 'Base Fare per KM', Icons.money, keyboardType: TextInputType.number),
              const SizedBox(height: 24),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: _addRoute,
                  child: const Text('Save Route', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green),
        filled: true,
        fillColor: Colors.green.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }

  void _showError(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Route Management', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.green)) 
          : _routes.isEmpty 
            ? const Center(child: Text("No routes found. Click + to add."))
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
                        ).then((_) => _fetchRoutes());
                      },
                      icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                      label: const Text('Halts'),
                    ),
                  ),
                ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRouteSheet,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
