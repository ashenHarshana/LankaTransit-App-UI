import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'ticket_screen.dart';

class RouteDetailsScreen extends StatefulWidget {
  final dynamic routeData;
  const RouteDetailsScreen({super.key, required this.routeData});

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  final String baseUrl = "https://navith-25-lankatransit-backend.hf.space";
  List<dynamic> _halts = [];
  bool _isLoading = true;
  bool _isBooking = false;

  dynamic _selectedStartHalt;
  dynamic _selectedEndHalt;
  double _ticketPrice = 0.0;

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    fetchHalts();
  }

  Future<void> fetchHalts() async {
    final routeId = widget.routeData['id'];
    final url = Uri.parse('$baseUrl/api/routes/$routeId/halts');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _halts = jsonDecode(response.body);
          _isLoading = false;
          _updateMarkers();
        });
      }
    } catch (e) {
      _showSnackBar('Server error loading halts.', Colors.red);
    }
  }

  void _updateMarkers() {
    Set<Marker> tempMarkers = {};
    for (var halt in _halts) {
      if (halt['latitude'] != null && halt['longitude'] != null) {
        tempMarkers.add(
          Marker(
            markerId: MarkerId('halt_${halt['id']}'),
            position: LatLng(halt['latitude'], halt['longitude']),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: halt['haltName']),
            onTap: () {
              _onHaltTapped(halt);
            },
          ),
        );
      }
    }
    setState(() {
      _markers = tempMarkers;
    });
  }

  void _onHaltTapped(dynamic halt) {
    if (_selectedStartHalt == null) {
      setState(() {
        _selectedStartHalt = halt;
      });
    } else if (_selectedEndHalt == null && halt != _selectedStartHalt) {
      setState(() {
        _selectedEndHalt = halt;
      });
    } else {
      setState(() {
        _selectedStartHalt = halt;
        _selectedEndHalt = null;
      });
    }
    _calculateFare();
  }

  void _calculateFare() {
    if (_selectedStartHalt != null && _selectedEndHalt != null) {
      double startDist = (_selectedStartHalt['distanceFromStart'] as num).toDouble();
      double endDist = (_selectedEndHalt['distanceFromStart'] as num).toDouble();
      double baseFare = (widget.routeData['baseFarePerKm'] as num).toDouble();
      double distance = (endDist - startDist).abs();
      setState(() {
        _ticketPrice = distance * baseFare;
        if (_ticketPrice < 20) _ticketPrice = 20.0; // Minimum fare
      });
    } else {
      setState(() {
        _ticketPrice = 0.0;
      });
    }
  }

  Future<void> _handleBooking() async {
    if (_selectedStartHalt == null || _selectedEndHalt == null) return;

    setState(() => _isBooking = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      String? email = prefs.getString('userEmail');

      final response = await http.post(
        Uri.parse('$baseUrl/api/routes/book'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'userEmail': email,
          'routeId': widget.routeData['id'],
          'startLocation': _selectedStartHalt['haltName'],
          'endLocation': _selectedEndHalt['haltName'],
          'fare': _ticketPrice,
          'status': 'VALID'
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final booking = jsonDecode(response.body);
        if (!mounted) return;
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TicketScreen(
              ticketId: booking['id'],
              routeData: widget.routeData,
              startHalt: _selectedStartHalt,
              endHalt: _selectedEndHalt,
              ticketPrice: _ticketPrice,
            ),
          ),
        );
      } else {
        _showSnackBar('Booking failed. Please try again.', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Connection error.', Colors.red);
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Route ${widget.routeData['routeNumber']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Column(
        children: [
          // --- MAP SECTION ---
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _halts.isNotEmpty && _halts[0]['latitude'] != null
                        ? LatLng(_halts[0]['latitude'], _halts[0]['longitude'])
                        : const LatLng(6.9271, 79.8612),
                    zoom: 12,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  markers: _markers,
                  myLocationEnabled: true,
                  zoomControlsEnabled: false,
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    child: const Text(
                      "Select your Start and End halts from the list below or tap on the map markers.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- SELECTION SECTION ---
          Expanded(
            flex: 4,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
              ),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text("Journey Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  const SizedBox(height: 20),
                  
                  // Start Halt Dropdown
                  DropdownButtonFormField<dynamic>(
                    decoration: InputDecoration(
                      labelText: 'Starting From',
                      prefixIcon: const Icon(Icons.location_on, color: Colors.green),
                      filled: true,
                      fillColor: Colors.green.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                    value: _selectedStartHalt,
                    hint: const Text("Select Entry Point"),
                    items: _halts.map((h) => DropdownMenuItem(value: h, child: Text(h['haltName']))).toList(),
                    onChanged: (val) {
                      setState(() { _selectedStartHalt = val; });
                      _calculateFare();
                    },
                  ),
                  const SizedBox(height: 15),
                  
                  // End Halt Dropdown
                  DropdownButtonFormField<dynamic>(
                    decoration: InputDecoration(
                      labelText: 'Going To',
                      prefixIcon: const Icon(Icons.flag, color: Colors.redAccent),
                      filled: true,
                      fillColor: Colors.green.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                    value: _selectedEndHalt,
                    hint: const Text("Select Destination"),
                    items: _halts.map((h) => DropdownMenuItem(value: h, child: Text(h['haltName']))).toList(),
                    onChanged: (val) {
                      setState(() { _selectedEndHalt = val; });
                      _calculateFare();
                    },
                  ),
                  const SizedBox(height: 30),

                  // Fare Summary Card
                  if (_ticketPrice > 0)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Estimated Fare", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                              Text("Rs. ${_ticketPrice.toStringAsFixed(2)}", 
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                          const Divider(height: 20),
                          const Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.grey),
                              SizedBox(width: 8),
                              Text("Final fare will be confirmed on booking.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          )
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom Booking Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                onPressed: (_ticketPrice > 0 && !_isBooking) ? _handleBooking : null,
                child: _isBooking
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Book & Confirm Ticket', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
    );
  }
}
