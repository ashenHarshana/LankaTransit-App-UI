import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'ticket_scanner_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final String baseUrl = "https://navith-25-lankatransit-backend.hf.space";

  File? _profilePhoto;
  File? _nicFront;
  File? _nicBack;
  File? _license;

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String _userName = "User";
  String _userRole = "DRIVER";
  String _userStatus = "PENDING";
  int? _userId;

  bool _hasSubmittedDocs = false;

  Map<String, dynamic>? _assignedBus;
  Map<String, dynamic>? _assignedRoute;
  Map<String, dynamic>? _activeTrip;
  Map<String, dynamic>? _partnerInfo;
  bool _isLoadingData = false;

  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getInt('user_id');
      _userName = prefs.getString('user_name') ?? "User";
      _userRole = prefs.getString('user_role') ?? "DRIVER";
      _userStatus = prefs.getString('user_status') ?? "CREATED";
      _hasSubmittedDocs = prefs.getBool('has_submitted_docs') ?? false;

      if (_userStatus == 'REJECTED' || _userStatus == 'RESUBMIT') {
        _hasSubmittedDocs = false;
      }
    });

    if (_userStatus == 'APPROVED') {
      _fetchAssignmentAndTripData();
    }
  }

  Future<void> _fetchAssignmentAndTripData() async {
    setState(() => _isLoadingData = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      if (_userId == null) return;

      final busRes = await http.get(
        Uri.parse('$baseUrl/api/buses'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (busRes.statusCode == 200) {
        List<dynamic> buses = jsonDecode(busRes.body);
        try {
          _assignedBus = buses.firstWhere(
            (b) => _userRole == 'DRIVER'
                ? b['driverId'] == _userId
                : b['conductorId'] == _userId,
          );
        } catch (e) {
          _assignedBus = null;
        }
      }

      if (_assignedBus != null) {
        if (_assignedBus!['routeId'] != null) {
          final routeRes = await http.get(
            Uri.parse('$baseUrl/api/routes'),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (routeRes.statusCode == 200) {
            List<dynamic> routes = jsonDecode(routeRes.body);
            try {
              _assignedRoute = routes.firstWhere(
                (r) => r['id'] == _assignedBus!['routeId'],
              );
            } catch (e) {
              _assignedRoute = null;
            }
          }
        }

        if (_assignedBus!['ownerId'] != null) {
          final staffRes = await http.get(
            Uri.parse('$baseUrl/api/users/owner/${_assignedBus!['ownerId']}'),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (staffRes.statusCode == 200) {
            List<dynamic> staffList = jsonDecode(staffRes.body);
            int? partnerId = _userRole == 'DRIVER'
                ? _assignedBus!['conductorId']
                : _assignedBus!['driverId'];
            if (partnerId != null) {
              try {
                _partnerInfo = staffList.firstWhere(
                  (s) => s['id'] == partnerId,
                );
              } catch (e) {
                _partnerInfo = null;
              }
            }
          }
        }
      }

      if (_userRole == 'DRIVER') {
        final tripRes = await http.get(
          Uri.parse('$baseUrl/api/trips/active/driver/$_userId'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (tripRes.statusCode == 200 && tripRes.body.isNotEmpty) {
          _activeTrip = jsonDecode(tripRes.body);
          _startLocationTracking();
        } else {
          _activeTrip = null;
        }
      }
    } catch (e) {
      print("Data fetch error: $e");
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage(
        'Location services are disabled. Please enable GPS.',
        Colors.red,
      );
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showMessage('Location permissions are denied', Colors.red);
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showMessage(
        'Location permissions are permanently denied, we cannot request permissions.',
        Colors.red,
      );
      return false;
    }
    return true;
  }

  void _startLocationTracking() {
    if (_locationTimer != null && _locationTimer!.isActive) return;

    print("Started Live GPS Tracking...");

    _sendLocationToBackend();

    _locationTimer = Timer.periodic(
      const Duration(seconds: 10),
      (Timer t) => _sendLocationToBackend(),
    );
  }

  Future<void> _sendLocationToBackend() async {
    if (_activeTrip == null) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.put(
        Uri.parse('$baseUrl/api/trips/${_activeTrip!['id']}/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      );

      if (response.statusCode == 200) {
        print("Location sent: ${position.latitude}, ${position.longitude}");
      }
    } catch (e) {
      print("Error sending location: $e");
    }
  }

  Future<void> _startTrip() async {
    if (_assignedBus == null || _assignedRoute == null) return;

    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    setState(() => _isLoadingData = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('$baseUrl/api/trips/start'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'busId': _assignedBus!['id'],
          'routeId': _assignedRoute!['id'],
          'driverId': _userId,
          'conductorId': _assignedBus!['conductorId'],
        }),
      );

      if (response.statusCode == 200) {
        _showMessage(
          'Trip Started Successfully! GPS Tracking is ON.',
          Colors.green,
        );
        await _fetchAssignmentAndTripData();
      } else {
        _showMessage('Failed to start trip.', Colors.red);
      }
    } catch (e) {
      _showMessage('Error starting trip.', Colors.red);
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _endTrip() async {
    if (_activeTrip == null) return;

    setState(() => _isLoadingData = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.put(
        Uri.parse('$baseUrl/api/trips/${_activeTrip!['id']}/end'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showMessage(
          'Trip Ended Successfully! GPS Tracking Stopped.',
          Colors.blue,
        );
        _locationTimer?.cancel();
        _fetchAssignmentAndTripData();
      } else {
        _showMessage('Failed to end trip.', Colors.red);
      }
    } catch (e) {
      _showMessage('Error ending trip.', Colors.red);
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _pickImage(String docType) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (docType == 'profile') _profilePhoto = File(image.path);
        if (docType == 'nic_front') _nicFront = File(image.path);
        if (docType == 'nic_back') _nicBack = File(image.path);
        if (docType == 'license') _license = File(image.path);
      });
    }
  }

  Future<void> _uploadSingleDocument(
    File file,
    int userId,
    String endpoint,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/users/$userId/$endpoint'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    var response = await request.send();
    if (response.statusCode != 200)
      throw Exception('Failed to upload $endpoint');
  }

  Future<void> _submitAllDocuments() async {
    if (_profilePhoto == null || _nicFront == null || _nicBack == null) {
      _showMessage(
        'Please select at least Profile Photo and NIC (Front & Back)!',
        Colors.red,
      );
      return;
    }
    if (_userRole == 'DRIVER' && _license == null) {
      _showMessage('Drivers must upload their Driving License!', Colors.red);
      return;
    }
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('user_id');
      String? token = prefs.getString('jwt_token');

      if (userId == null) throw Exception("User ID not found!");

      await _uploadSingleDocument(
        _profilePhoto!,
        userId,
        'upload-profile-photo',
      );
      await _uploadSingleDocument(_nicFront!, userId, 'upload-nic-front');
      await _uploadSingleDocument(_nicBack!, userId, 'upload-nic-back');
      if (_license != null)
        await _uploadSingleDocument(_license!, userId, 'upload-license');

      final statusResponse = await http.put(
        Uri.parse('$baseUrl/api/users/submit-docs/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (statusResponse.statusCode == 200) {
        _showMessage('Documents Uploaded Successfully!', Colors.green);
        await prefs.setBool('has_submitted_docs', true);
        await prefs.setString('user_status', 'PENDING');
        setState(() {
          _hasSubmittedDocs = true;
          _userStatus = 'PENDING';
          _profilePhoto = null;
          _nicFront = null;
          _nicBack = null;
          _license = null;
        });
      } else {
        _showMessage('Failed to notify admin! Please try again.', Colors.red);
      }
    } catch (e) {
      _showMessage('Upload Failed! Please try again.', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildUploadForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.green.withOpacity(0.1)),
          ),
          child: Text(
            _userStatus == 'RESUBMIT' || _userStatus == 'REJECTED'
                ? 'Your documents were $_userStatus.\nPlease upload clear documents again.'
                : 'Account Status: $_userStatus\nPlease upload your documents below for Admin approval.',
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'Upload Verification Documents',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 15),
        _buildDocUploadCard(
          'Profile Photo',
          'profile',
          _profilePhoto,
          Icons.person_outline_rounded,
        ),
        _buildDocUploadCard('NIC (Front)', 'nic_front', _nicFront, Icons.badge_outlined),
        _buildDocUploadCard(
          'NIC (Back)',
          'nic_back',
          _nicBack,
          Icons.picture_in_picture_rounded,
        ),
        if (_userRole == 'DRIVER')
          _buildDocUploadCard(
            'Driving License',
            'license',
            _license,
            Icons.drive_eta_rounded,
          ),
        const SizedBox(height: 30),
        SizedBox(
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 2,
            ),
            onPressed: _isLoading ? null : _submitAllDocuments,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Submit for Verification',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocUploadCard(
    String title,
    String docType,
    File? file,
    IconData icon,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (file == null ? Colors.green : Colors.green).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            file == null ? icon : Icons.check_circle_rounded,
            color: Colors.green,
            size: 30,
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(
          file == null ? 'Not uploaded' : 'Ready to submit',
          style: TextStyle(color: file == null ? Colors.grey : Colors.green, fontWeight: FontWeight.w500),
        ),
        trailing: TextButton(
          onPressed: () => _pickImage(docType),
          child: Text(
            file == null ? 'Upload' : 'Edit',
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 80),
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.hourglass_empty_rounded, size: 80, color: Colors.green),
        ),
        const SizedBox(height: 30),
        const Text(
          'Verification in Progress',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 15),
        const Text(
          'Your documents are being reviewed by the admin.\nPlease check back in a few hours.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 50),
        SizedBox(
          width: 250,
          height: 50,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Check Status', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildApprovedDashboard() {
    if (_isLoadingData) {
      return const Padding(
        padding: EdgeInsets.only(top: 80.0),
        child: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    if (_assignedBus == null) {
      return Column(
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.bus_alert_rounded, size: 80, color: Colors.grey[400]),
          ),
          const SizedBox(height: 25),
          const Text(
            'No Bus Assigned',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          const Text(
            'You haven\'t been assigned to a bus yet.\nPlease contact your bus owner.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: _fetchAssignmentAndTripData,
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Refresh Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.green.withOpacity(0.2)),
          ),
          color: Colors.green.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Icon(
                  Icons.directions_bus_rounded,
                  size: 50,
                  color: Colors.green,
                ),
                const SizedBox(height: 15),
                Text(
                  _assignedBus!['busNumber'],
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _assignedRoute != null
                        ? 'Route ${_assignedRoute!['routeNumber']} : ${_assignedRoute!['startLocation']} ➔ ${_assignedRoute!['endLocation']}'
                        : 'Route Info Unavailable',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _userRole == 'DRIVER'
                          ? Icons.badge_rounded
                          : Icons.sports_motorsports_rounded,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _userRole == 'DRIVER' ? 'Conductor: ' : 'Driver: ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _partnerInfo != null
                          ? _partnerInfo!['name']
                          : 'Not Assigned',
                      style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),

        if (_userRole == 'DRIVER') ...[
          if (_activeTrip == null)
            SizedBox(
              height: 70,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 4,
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 36),
                label: const Text(
                  'START TRIP',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                onPressed: _startTrip,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: const Column(
                    children: [
                      CircularProgressIndicator(color: Colors.green, strokeWidth: 3),
                      SizedBox(height: 20),
                      Text(
                        'TRIP IN PROGRESS',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'GPS tracking is active for passengers',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  height: 60,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 28),
                    label: const Text(
                      'END TRIP',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text('End Current Trip?'),
                          content: const Text(
                            'GPS tracking will stop immediately once you end the trip.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _endTrip();
                              },
                              child: const Text('Yes, End Trip'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
        ] else ...[
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.green.withOpacity(0.2)),
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TicketScannerScreen(busId: _assignedBus!['id']),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, size: 80, color: Colors.green),
                    SizedBox(height: 15),
                    Text(
                      'Scan Passenger Tickets',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Tap to open camera',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          '$_userRole Panel',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Hello, $_userName!',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(
              'Bus Management Portal',
              style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            if (_userStatus == 'APPROVED')
              _buildApprovedDashboard()
            else if (_hasSubmittedDocs || _userStatus == 'PENDING')
              _buildWaitingScreen()
            else
              _buildUploadForm(),
          ],
        ),
      ),
    );
  }
}
