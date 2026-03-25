import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';
import 'route_details_screen.dart';
import 'my_tickets_screen.dart';
import 'profile_screen.dart';
import 'live_map_screen.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _routes = [];
  List<dynamic> _filteredRoutes = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchRoutes();
  }

  Future<void> fetchRoutes() async {
    final url = Uri.parse(
      'https://navith-25-lankatransit-backend.hf.space/api/routes',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _routes = jsonDecode(response.body);
          _filteredRoutes = _routes;
          _isLoading = false;
        });
      } else {
        showError('Failed to load routes');
      }
    } catch (e) {
      showError('Server error.');
    }
  }

  void _filterRoutes(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredRoutes = _routes;
      });
    } else {
      setState(() {
        _filteredRoutes = _routes.where((route) {
          final routeNum = route['routeNumber']?.toString().toLowerCase() ?? '';
          final startLoc =
              route['startLocation']?.toString().toLowerCase() ?? '';
          final endLoc = route['endLocation']?.toString().toLowerCase() ?? '';
          final searchLower = query.toLowerCase();

          return routeNum.contains(searchLower) ||
              startLoc.contains(searchLower) ||
              endLoc.contains(searchLower);
        }).toList();
      });
    }
  }

  void showError(String message) {
    setState(() {
      _isLoading = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'LankaTransit',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.confirmation_num_outlined),
            tooltip: 'My Tickets',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyTicketsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Where are you going today?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _filterRoutes,
                          decoration: const InputDecoration(
                            hintText: 'Search Route No, Start or End...',
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Colors.green,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _filteredRoutes.isEmpty
                      ? const Center(
                          child: Text(
                            'No routes found matching your search.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredRoutes.length,
                          itemBuilder: (context, index) {
                            final route = _filteredRoutes[index];
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  radius: 25,
                                  backgroundColor: Colors.green.withOpacity(0.1),
                                  child: const Icon(
                                    Icons.directions_bus_rounded,
                                    color: Colors.green,
                                    size: 30,
                                  ),
                                ),
                                title: Text(
                                  'Route ${route['routeNumber']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 16, color: Colors.green),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${route['startLocation']} ➔ ${route['endLocation']}',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                ),

                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          RouteDetailsScreen(routeData: route),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LiveMapScreen()),
          );
        },
        icon: const Icon(Icons.map_rounded, size: 24),
        label: const Text(
          'Live Radar',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 6,
      ),
    );
  }
}
