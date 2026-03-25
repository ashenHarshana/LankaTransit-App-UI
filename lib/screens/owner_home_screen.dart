import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen>
    with SingleTickerProviderStateMixin {
  final String baseUrl = "https://navith-25-lankatransit-backend.hf.space";

  late TabController _tabController;

  List<dynamic> _myBuses = [];
  bool _isLoadingBuses = false;

  List<dynamic> _myStaff = [];
  bool _isLoadingStaff = false;

  List<dynamic> _availableRoutes = [];
  String? _selectedRouteId;

  double _totalRevenue = 0.0;
  int _totalTickets = 0;
  int _totalBuses = 0;

  final TextEditingController _busNumberController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();

  File? _registrationPotha;
  File? _insuranceCard;
  File? _revenueLicense;
  File? _routePermit;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _staffNameController = TextEditingController();
  final TextEditingController _staffEmailController = TextEditingController();
  final TextEditingController _staffPhoneController = TextEditingController();
  final TextEditingController _staffPasswordController =
      TextEditingController();

  String _selectedRole = 'DRIVER';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    _fetchRevenue();
    _fetchMyBuses();
    _fetchMyStaff();
    _fetchAvailableRoutes();
  }

  Future<void> _fetchRevenue() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      int? ownerId = prefs.getInt('user_id');
      if (ownerId == null) return;

      final revRes = await http.get(
        Uri.parse('$baseUrl/api/tickets/revenue/owner/$ownerId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (revRes.statusCode == 200) {
        final revData = jsonDecode(revRes.body);
        setState(() {
          _totalRevenue = (revData['totalRevenue'] ?? 0.0).toDouble();
          _totalTickets = revData['totalTickets'] ?? 0;
          _totalBuses = revData['totalBuses'] ?? 0;
        });
      }
    } catch (e) {
      print("Error fetching revenue: $e");
    }
  }

  Future<void> _fetchAvailableRoutes() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/routes'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _availableRoutes = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print("Error fetching routes: $e");
    }
  }

  Future<void> _fetchMyBuses() async {
    setState(() => _isLoadingBuses = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      int? ownerId = prefs.getInt('user_id');

      if (ownerId == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/api/buses/owner/$ownerId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _myBuses = jsonDecode(response.body);
        });
      }
    } catch (e) {
      _showMessage('Failed to load buses!', Colors.red);
    } finally {
      setState(() => _isLoadingBuses = false);
    }
  }

  Future<void> _fetchMyStaff() async {
    setState(() => _isLoadingStaff = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      int? ownerId = prefs.getInt('user_id');

      if (ownerId == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/owner/$ownerId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _myStaff = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print("Staff Load Error: $e");
    } finally {
      setState(() => _isLoadingStaff = false);
    }
  }

  Future<bool> _assignCrew(int busId, int? driverId, int? conductorId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.put(
        Uri.parse('$baseUrl/api/buses/$busId/assign-crew'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'driverId': driverId, 'conductorId': conductorId}),
      );

      if (response.statusCode == 200) {
        _showMessage('Crew Assigned Successfully!', Colors.green);
        _fetchMyBuses();
        return true;
      } else {
        _showMessage('Failed to assign crew.', Colors.red);
        return false;
      }
    } catch (e) {
      _showMessage('Error assigning crew.', Colors.red);
      return false;
    }
  }

  Future<void> _deleteStaff(int id) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.delete(
        Uri.parse('$baseUrl/api/users/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showMessage('Staff member removed!', Colors.green);
        _fetchMyStaff();
      } else {
        _showMessage('Failed to remove staff!', Colors.red);
      }
    } catch (e) {
      _showMessage('Error removing staff!', Colors.red);
    }
  }

  Future<bool> _updateStaff(
    int staffId,
    String name,
    String email,
    String phone,
    String role,
  ) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');

      final response = await http.put(
        Uri.parse('$baseUrl/api/users/$staffId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'role': role,
        }),
      );

      if (response.statusCode == 200) {
        _showMessage('Staff Details Updated!', Colors.green);
        _fetchMyStaff();
        return true;
      } else {
        _showMessage('Failed to update staff!', Colors.red);
        return false;
      }
    } catch (e) {
      _showMessage('Error updating staff!', Colors.red);
      return false;
    }
  }

  Future<void> _pickImage(String docType, StateSetter setSheetState) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setSheetState(() {
        if (docType == 'registration') _registrationPotha = File(image.path);
        if (docType == 'insurance') _insuranceCard = File(image.path);
        if (docType == 'revenue') _revenueLicense = File(image.path);
        if (docType == 'permit') _routePermit = File(image.path);
      });
    }
  }

  Future<void> _uploadBusDocument(File file, int busId, String endpoint) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/buses/$busId/$endpoint'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    var response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('Failed to upload $endpoint');
    }
  }

  Future<bool> _addBus() async {
    if (_busNumberController.text.isEmpty || _capacityController.text.isEmpty) {
      _showMessage('Please enter Bus Number and Capacity', Colors.red);
      return false;
    }

    if (_selectedRouteId == null) {
      _showMessage('Please select a Route for this Bus!', Colors.red);
      return false;
    }

    if (_registrationPotha == null ||
        _insuranceCard == null ||
        _revenueLicense == null ||
        _routePermit == null) {
      _showMessage(
        'Please select all 4 Bus Documents (including Route Permit)!',
        Colors.red,
      );
      return false;
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      int? ownerId = prefs.getInt('user_id');

      final response = await http.post(
        Uri.parse('$baseUrl/api/buses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'busNumber': _busNumberController.text,
          'capacity': int.tryParse(_capacityController.text) ?? 54,
          'ownerId': ownerId,
          'routeId': int.parse(_selectedRouteId!),
          'status': 'PENDING',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        int newBusId = responseData['id'];

        await _uploadBusDocument(
          _registrationPotha!,
          newBusId,
          'upload-registration',
        );
        await _uploadBusDocument(_insuranceCard!, newBusId, 'upload-insurance');
        await _uploadBusDocument(
          _revenueLicense!,
          newBusId,
          'upload-revenue-license',
        );
        await _uploadBusDocument(
          _routePermit!,
          newBusId,
          'upload-route-permit',
        );

        _showMessage('Bus & Documents Added Successfully!', Colors.green);

        _busNumberController.clear();
        _capacityController.clear();
        _selectedRouteId = null;
        _registrationPotha = null;
        _insuranceCard = null;
        _revenueLicense = null;
        _routePermit = null;

        _fetchMyBuses();
        return true;
      } else {
        _showMessage('Failed to add Bus!', Colors.red);
        return false;
      }
    } catch (e) {
      _showMessage('Error adding bus: $e', Colors.red);
      return false;
    }
  }

  Future<bool> _resubmitBusDocs(int busId) async {
    if (_registrationPotha == null &&
        _insuranceCard == null &&
        _revenueLicense == null &&
        _routePermit == null) {
      _showMessage(
        'Please select at least one document to update!',
        Colors.red,
      );
      return false;
    }

    try {
      if (_registrationPotha != null)
        await _uploadBusDocument(
          _registrationPotha!,
          busId,
          'upload-registration',
        );
      if (_insuranceCard != null)
        await _uploadBusDocument(_insuranceCard!, busId, 'upload-insurance');
      if (_revenueLicense != null)
        await _uploadBusDocument(
          _revenueLicense!,
          busId,
          'upload-revenue-license',
        );
      if (_routePermit != null)
        await _uploadBusDocument(_routePermit!, busId, 'upload-route-permit');

      _showMessage('Documents Resubmitted Successfully!', Colors.green);

      _registrationPotha = null;
      _insuranceCard = null;
      _revenueLicense = null;
      _routePermit = null;

      _fetchMyBuses();
      return true;
    } catch (e) {
      _showMessage('Error updating documents: $e', Colors.red);
      return false;
    }
  }

  Future<bool> _addStaff() async {
    if (_staffNameController.text.isEmpty ||
        _staffEmailController.text.isEmpty ||
        _staffPasswordController.text.isEmpty) {
      _showMessage('Please fill name, email and password', Colors.red);
      return false;
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('jwt_token');
      int? ownerId = prefs.getInt('user_id');

      final response = await http.post(
        Uri.parse('$baseUrl/api/users/add-staff'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': _staffNameController.text,
          'email': _staffEmailController.text,
          'phone': _staffPhoneController.text,
          'passwordHash': _staffPasswordController.text,
          'role': _selectedRole,
          'ownerId': ownerId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage('Staff Account Created Successfully!', Colors.green);
        _staffNameController.clear();
        _staffEmailController.clear();
        _staffPhoneController.clear();
        _staffPasswordController.clear();

        _fetchMyStaff();
        return true;
      } else {
        _showMessage('Failed to add staff!', Colors.red);
        return false;
      }
    } catch (e) {
      _showMessage('Error adding staff: $e', Colors.red);
      return false;
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

  Widget _buildDocUploadButton(
    String title,
    String docType,
    File? file,
    StateSetter setSheetState,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton.icon(
        icon: Icon(
          file == null ? Icons.upload_file_rounded : Icons.check_circle_rounded,
          color: file == null ? Colors.grey[700] : Colors.green,
        ),
        label: Text(
          file == null ? 'Upload $title' : '$title Selected',
          style: TextStyle(color: file == null ? Colors.grey[800] : Colors.green, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          backgroundColor: file == null ? Colors.grey[100] : Colors.green.withOpacity(0.1),
          side: BorderSide(color: file == null ? Colors.grey[300]! : Colors.green, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _pickImage(docType, setSheetState),
      ),
    );
  }

  void _showAddBusSheet() {
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
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Register New Bus',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),

                DropdownButtonFormField<String>(
                  value: _selectedRouteId,
                  decoration: InputDecoration(
                    labelText: 'Assign Route',
                    filled: true,
                    fillColor: Colors.green.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.alt_route_rounded, color: Colors.green),
                  ),
                  items: _availableRoutes.map((route) {
                    return DropdownMenuItem<String>(
                      value: route['id'].toString(),
                      child: Text(
                        'Route ${route['routeNumber']} (${route['startLocation']} - ${route['endLocation']})',
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setSheetState(() => _selectedRouteId = val);
                  },
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: _busNumberController,
                  decoration: InputDecoration(
                    labelText: 'Bus Plate Number',
                    hintText: 'e.g. WP ND-1234',
                    filled: true,
                    fillColor: Colors.green.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.numbers_rounded, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Passenger Capacity',
                    hintText: 'e.g. 54',
                    filled: true,
                    fillColor: Colors.green.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.airline_seat_recline_normal_rounded, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 25),
                const Text('Required Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 15),

                _buildDocUploadButton('Registration Potha (CR)', 'registration', _registrationPotha, setSheetState),
                _buildDocUploadButton('Insurance Card', 'insurance', _insuranceCard, setSheetState),
                _buildDocUploadButton('Revenue License', 'revenue', _revenueLicense, setSheetState),
                _buildDocUploadButton('Route Permit', 'permit', _routePermit, setSheetState),

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
                    onPressed: _isLoading
                        ? null
                        : () async {
                            setSheetState(() => _isLoading = true);
                            bool success = await _addBus();
                            if (success) {
                              if (sheetContext.mounted)
                                Navigator.pop(sheetContext);
                            }
                            setSheetState(() => _isLoading = false);
                          },
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Submit Registration',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResubmitBusSheet(Map<String, dynamic> bus) {
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
              Text(
                'Resubmit Docs: ${bus['busNumber']}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Please upload the rejected documents again.',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),

              _buildDocUploadButton('Registration Potha (CR)', 'registration', _registrationPotha, setSheetState),
              _buildDocUploadButton('Insurance Card', 'insurance', _insuranceCard, setSheetState),
              _buildDocUploadButton('Revenue License', 'revenue', _revenueLicense, setSheetState),
              _buildDocUploadButton('Route Permit', 'permit', _routePermit, setSheetState),

              const SizedBox(height: 25),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: isUpdating
                      ? null
                      : () async {
                          setSheetState(() => isUpdating = true);
                          bool success = await _resubmitBusDocs(bus['id']);
                          if (success && sheetContext.mounted)
                            Navigator.pop(sheetContext);
                          setSheetState(() => isUpdating = false);
                        },
                  child: isUpdating
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Resubmit Documents',
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

  void _showAssignCrewSheet(Map<String, dynamic> bus) {
    List<dynamic> drivers = _myStaff
        .where((s) => s['role'] == 'DRIVER' && s['status'] == 'APPROVED')
        .toList();
    List<dynamic> conductors = _myStaff
        .where((s) => s['role'] == 'CONDUCTOR' && s['status'] == 'APPROVED')
        .toList();

    String? selectedDriverId = bus['driverId']?.toString();
    String? selectedConductorId = bus['conductorId']?.toString();

    if (selectedDriverId != null &&
        !drivers.any((d) => d['id'].toString() == selectedDriverId))
      selectedDriverId = null;
    if (selectedConductorId != null &&
        !conductors.any((c) => c['id'].toString() == selectedConductorId))
      selectedConductorId = null;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Assign Crew: ${bus['busNumber']}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              DropdownButtonFormField<String>(
                value: selectedDriverId,
                decoration: InputDecoration(
                  labelText: 'Select Driver',
                  filled: true,
                  fillColor: Colors.green.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.sports_motorsports_rounded, color: Colors.green),
                ),
                items: drivers.map((driver) {
                  return DropdownMenuItem<String>(
                    value: driver['id'].toString(),
                    child: Text('${driver['name']} (${driver['phone'] ?? 'N/A'})'),
                  );
                }).toList(),
                onChanged: (val) => setSheetState(() => selectedDriverId = val),
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                value: selectedConductorId,
                decoration: InputDecoration(
                  labelText: 'Select Conductor',
                  filled: true,
                  fillColor: Colors.green.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.badge_rounded, color: Colors.green),
                ),
                items: conductors.map((cond) {
                  return DropdownMenuItem<String>(
                    value: cond['id'].toString(),
                    child: Text('${cond['name']} (${cond['phone'] ?? 'N/A'})'),
                  );
                }).toList(),
                onChanged: (val) => setSheetState(() => selectedConductorId = val),
              ),

              const SizedBox(height: 30),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setSheetState(() => isSubmitting = true);
                          int? dId = selectedDriverId != null ? int.parse(selectedDriverId!) : null;
                          int? cId = selectedConductorId != null ? int.parse(selectedConductorId!) : null;

                          bool success = await _assignCrew(bus['id'], dId, cId);
                          if (success && sheetContext.mounted) Navigator.pop(sheetContext);
                          setSheetState(() => isSubmitting = false);
                        },
                  child: isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Assignments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddStaffSheet() {
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
                const Text(
                  'Add New Staff Member',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _staffNameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    filled: true,
                    fillColor: Colors.green.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _staffEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    filled: true,
                    fillColor: Colors.green.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _staffPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    filled: true,
                    fillColor: Colors.green.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.phone_outlined, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _staffPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Temporary Password',
                    filled: true,
                    fillColor: Colors.green.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    filled: true,
                    fillColor: Colors.green.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.work_outline_rounded, color: Colors.green),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'DRIVER', child: Text('Driver')),
                    DropdownMenuItem(value: 'CONDUCTOR', child: Text('Conductor')),
                  ],
                  onChanged: (val) {
                    if (val != null) setSheetState(() => _selectedRole = val);
                  },
                ),
                const SizedBox(height: 30),
                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () async {
                            setSheetState(() => _isLoading = true);
                            bool success = await _addStaff();
                            if (success && sheetContext.mounted) Navigator.pop(sheetContext);
                            setSheetState(() => _isLoading = false);
                          },
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Register Staff Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  void _showEditStaffSheet(Map<String, dynamic> staff) {
    final TextEditingController editNameCtrl = TextEditingController(text: staff['name']);
    final TextEditingController editEmailCtrl = TextEditingController(text: staff['email']);
    final TextEditingController editPhoneCtrl = TextEditingController(text: staff['phone'] ?? '');
    String editRole = staff['role'] ?? 'DRIVER';
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
              const Text('Edit Staff Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green), textAlign: TextAlign.center),
              const SizedBox(height: 30),
              TextField(
                controller: editNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  filled: true,
                  fillColor: Colors.green.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.green),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: editEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  filled: true,
                  fillColor: Colors.green.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.green),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: editPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  filled: true,
                  fillColor: Colors.green.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.phone_outlined, color: Colors.green),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: editRole,
                decoration: InputDecoration(
                  labelText: 'Role',
                  filled: true,
                  fillColor: Colors.green.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.work_outline_rounded, color: Colors.green),
                ),
                items: const [
                  DropdownMenuItem(value: 'DRIVER', child: Text('Driver')),
                  DropdownMenuItem(value: 'CONDUCTOR', child: Text('Conductor')),
                ],
                onChanged: (val) {
                  if (val != null) setSheetState(() => editRole = val);
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: isUpdating
                      ? null
                      : () async {
                          setSheetState(() => isUpdating = true);
                          bool success = await _updateStaff(staff['id'], editNameCtrl.text, editEmailCtrl.text, editPhoneCtrl.text, editRole);
                          if (success && sheetContext.mounted) Navigator.pop(sheetContext);
                          setSheetState(() => isUpdating = false);
                        },
                  child: isUpdating
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Changes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 15),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Overview',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.green, Color(0xFF43A047)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Column(
              children: [
                const Text('Total Revenue', style: TextStyle(color: Colors.whiteCC, fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                Text(
                  'Rs. ${_totalRevenue.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                const Text('Lifetime Earnings', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 25),

          Row(
            children: [
              Expanded(child: _buildStatCard('Tickets', _totalTickets.toString(), Icons.confirmation_number_rounded, Colors.orange)),
              const SizedBox(width: 15),
              Expanded(child: _buildStatCard('Active Buses', _totalBuses.toString(), Icons.directions_bus_rounded, Colors.green)),
            ],
          ),
          const SizedBox(height: 35),
          const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton('Register Bus', Icons.add_bus_rounded, Colors.green, _showAddBusSheet),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildQuickActionButton('Add Staff', Icons.person_add_rounded, Colors.green, _showAddStaffSheet),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildMyFleetTab() {
    if (_isLoadingBuses) return const Center(child: CircularProgressIndicator(color: Colors.green));
    if (_myBuses.isEmpty) return const Center(child: Text('No buses registered yet.', style: TextStyle(color: Colors.grey)));

    return RefreshIndicator(
      onRefresh: _fetchMyBuses,
      color: Colors.green,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _myBuses.length,
        itemBuilder: (context, index) {
          var bus = _myBuses[index];
          String status = bus['status'] ?? 'PENDING';
          Color statusColor = status == 'APPROVED' ? Colors.green : (status == 'REJECTED' ? Colors.red : Colors.orange);

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withOpacity(0.2))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                        child: const Icon(Icons.directions_bus_rounded, color: Colors.green, size: 28),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bus['busNumber'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 4),
                            Text('Route ID: ${bus['routeId'] ?? 'Not Assigned'}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current Crew', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 5),
                          Text(
                            bus['driverId'] != null ? 'Driver Assigned' : 'No Driver',
                            style: TextStyle(color: bus['driverId'] != null ? Colors.black87 : Colors.red[300], fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      if (status == 'APPROVED')
                        ElevatedButton.icon(
                          onPressed: () => _showAssignCrewSheet(bus),
                          icon: const Icon(Icons.people_outline_rounded, size: 16),
                          label: const Text('Assign'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      else if (status == 'RESUBMIT' || status == 'REJECTED')
                        TextButton(
                          onPressed: () => _showResubmitBusSheet(bus),
                          child: const Text('Update Docs', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMyStaffTab() {
    if (_isLoadingStaff) return const Center(child: CircularProgressIndicator(color: Colors.green));
    if (_myStaff.isEmpty) return const Center(child: Text('Add your first driver or conductor.', style: TextStyle(color: Colors.grey)));

    return RefreshIndicator(
      onRefresh: _fetchMyStaff,
      color: Colors.green,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _myStaff.length,
        itemBuilder: (context, index) {
          var staff = _myStaff[index];
          String role = staff['role'] ?? 'USER';
          String status = staff['status'] ?? 'PENDING';
          Color statusColor = status == 'APPROVED' ? Colors.green : Colors.orange;

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withOpacity(0.2))),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: CircleAvatar(
                backgroundColor: Colors.green.withOpacity(0.1),
                child: Icon(role == 'DRIVER' ? Icons.sports_motorsports_rounded : Icons.confirmation_num_rounded, color: Colors.green),
              ),
              title: Text(staff['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text('$role | ${staff['phone'] ?? 'No Phone'}\nStatus: $status', style: const TextStyle(fontSize: 13)),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'edit') _showEditStaffSheet(staff);
                  if (val == 'delete') _deleteStaff(staff['id']);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Remove', style: TextStyle(color: Colors.red))),
                ],
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Fleet Management', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.person_outline_rounded), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()))),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!context.mounted) return;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Home'),
            Tab(text: 'My Fleet'),
            Tab(text: 'My Staff'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildMyFleetTab(),
          _buildMyStaffTab(),
        ],
      ),
    );
  }
}
