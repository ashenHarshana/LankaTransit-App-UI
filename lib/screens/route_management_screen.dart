import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_route_map_screen.dart';
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
      final response = await http.get(
        Uri.parse('$baseUrl/api/routes'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() => _routes = jsonDecode(response.body));
      }
    } catch (e) {
      _showMessage("Error fetching routes", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openMapRouteCreator() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddRouteMapScreen()),
    );

    if (result == true) {
      _fetchRoutes();
    }
  }

  Future<void> _deleteRoute(int routeId) async {
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.delete(
        Uri.parse('$baseUrl/api/routes/$routeId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showMessage('Route Deleted Successfully!', Colors.green);
        _fetchRoutes();
      } else {
        _showMessage('Failed to delete route.', Colors.red);
      }
    } catch (e) {
      _showMessage('Error deleting route.', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _updateRoute(int routeId, String routeNo, String startLoc, String endLoc, double fare) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.put(
        Uri.parse('$baseUrl/api/routes/$routeId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'routeNumber': routeNo,
          'startLocation': startLoc,
          'endLocation': endLoc,
          'baseFarePerKm': fare,
        }),
      );

      if (response.statusCode == 200) {
        _showMessage('Route Updated Successfully!', Colors.green);
        _fetchRoutes();
        return true;
      } else {
        _showMessage('Failed to update route.', Colors.red);
        return false;
      }
    } catch (e) {
      _showMessage('Error updating route.', Colors.red);
      return false;
    }
  }

  Future<List<dynamic>> _getHaltsForRoute(int routeId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/routes/$routeId/halts'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  void _showEditRouteSheet(dynamic route) {
    final TextEditingController routeNoCtrl = TextEditingController(text: route['routeNumber']);
    final TextEditingController startLocCtrl = TextEditingController(text: route['startLocation']);
    final TextEditingController endLocCtrl = TextEditingController(text: route['endLocation']);
    final TextEditingController fareCtrl = TextEditingController(text: route['baseFarePerKm'].toString());
    bool isSubmitting = false;

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Edit Route Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                _buildTextField(routeNoCtrl, 'Route Number', Icons.numbers),
                const SizedBox(height: 12),
                _buildTextField(startLocCtrl, 'Start Location', Icons.location_on),
                const SizedBox(height: 12),
                _buildTextField(endLocCtrl, 'End Location', Icons.flag),
                const SizedBox(height: 12),
                _buildTextField(fareCtrl, 'Base Fare per KM', Icons.money, keyboardType: TextInputType.number),
                const SizedBox(height: 24),
                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: isSubmitting ? null : () async {
                      if (routeNoCtrl.text.isEmpty || fareCtrl.text.isEmpty) return;
                      setSheetState(() => isSubmitting = true);
                      bool success = await _updateRoute(
                        route['id'],
                        routeNoCtrl.text,
                        startLocCtrl.text,
                        endLocCtrl.text,
                        double.parse(fareCtrl.text),
                      );
                      if (success && sheetContext.mounted) Navigator.pop(sheetContext);
                      setSheetState(() => isSubmitting = false);
                    },
                    child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Update Route', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHaltsDialog(dynamic route) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Halts: Route ${route['routeNumber']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        content: FutureBuilder<List<dynamic>>(
          future: _getHaltsForRoute(route['id']),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: Colors.green)));
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Text('Failed to load halts.');
            }

            List<dynamic> halts = snapshot.data!;
            if (halts.isEmpty) return const Text('No halts added yet.');

            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: halts.length,
                itemBuilder: (context, index) {
                  var halt = halts[index];
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.green.withOpacity(0.1), child: Text('${halt['sequenceOrder']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                    title: Text(halt['haltName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${halt['distanceFromStart']} KM from start'),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Colors.grey))),
        ],
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

  void _showMessage(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
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
              ? const Center(child: Text("No routes found. Click + to create on Map."))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _routes.length,
                  itemBuilder: (ctx, i) {
                    var route = _routes[i];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Route: ${route['routeNumber']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                                Row(
                                  children: [
                                    IconButton(icon: const Icon(Icons.edit_rounded, color: Colors.orange), onPressed: () => _showEditRouteSheet(route)),
                                    IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.red), onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Route?'),
                                          content: Text('Are you sure you want to delete Route ${route['routeNumber']}? This will remove all its halts.'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () { Navigator.pop(ctx); _deleteRoute(route['id']); }, child: const Text('Delete')),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ],
                            ),
                            Text('Fare/KM: Rs.${route['baseFarePerKm']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
                            const SizedBox(height: 8),
                            Text('${route['startLocation']} ➔ ${route['endLocation']}', style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500)),
                            const Divider(height: 30),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                OutlinedButton.icon(onPressed: () => _showHaltsDialog(route), icon: const Icon(Icons.list_rounded), label: const Text('View Halts'), style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green))),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => AddHaltMapScreen(routeData: route))).then((_) => _fetchRoutes());
                                  },
                                  icon: const Icon(Icons.add_location_alt_rounded),
                                  label: const Text('Halts'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openMapRouteCreator,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
      ),
    );
  }
}
