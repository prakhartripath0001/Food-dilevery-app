import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../services/address_service.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../widgets/address_picker_sheet.dart';
import '../widgets/auth_dialog.dart';
import '../widgets/location_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _geocoding = Geocoding();

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _restaurants = [];
  Map<String, dynamic>? _deliveryAddress;
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  final _authService = AuthService();
  final _addressService = AddressService();

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadSavedAddress();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categoriesRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/categories'),
      );
      final restaurantsRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/restaurants'),
      );

      final categoriesData =
          jsonDecode(categoriesRes.body) as Map<String, dynamic>;
      final restaurantsData =
          jsonDecode(restaurantsRes.body) as Map<String, dynamic>;

      setState(() {
        _categories = List<Map<String, dynamic>>.from(
          categoriesData['data'] ?? [],
        );
        _restaurants = List<Map<String, dynamic>>.from(
          restaurantsData['data'] ?? [],
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _searchRestaurants(String query) async {
    setState(() => _isLoading = true);
    try {
      final uri = query.isNotEmpty
          ? Uri.parse('${ApiConfig.baseUrl}/api/restaurants?search=$query')
          : Uri.parse('${ApiConfig.baseUrl}/api/restaurants');
      final response = await http.get(uri);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _restaurants = List<Map<String, dynamic>>.from(data['data'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSavedAddress() async {
    try {
      final token = await _authService.readToken();
      if (token == null) return;
      final addresses = await _addressService.getAddresses(token);
      if (!mounted || addresses.isEmpty) return;
      setState(() {
        _deliveryAddress = addresses.firstWhere(
          (address) =>
              address['isDefault'] == true || address['isDefault'] == 1,
          orElse: () => addresses.first,
        );
      });
    } catch (error) {
      if (mounted) _showMessage('Could not load your saved address: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAddressPicker() async {
    String? token = await _authService.readToken();
    if (token == null) {
      if (!mounted) return;
      final user = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => const AuthDialog(),
      );
      if (user == null || !mounted) return;
      token = await _authService.readToken();
    }
    if (token == null || !mounted) return;

    final authToken = token;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (sheetContext) => AddressPickerSheet(
        token: authToken,
        onUseCurrentLocation: () {
          Navigator.of(sheetContext).pop();
          _useCurrentLocation(authToken);
        },
        onSearch: (query) {
          Navigator.of(sheetContext).pop();
          _searchLocation(query, authToken);
        },
        onAddAddress: () {
          Navigator.of(sheetContext).pop();
          _showAddressForm(authToken);
        },
        onSelectAddress: (address) async {
          final id = int.tryParse(address['id'].toString());
          if (id == null) {
            throw Exception('This saved address has an invalid ID');
          }
          final selected = await _addressService.setDefault(authToken, id);
          if (!sheetContext.mounted || !mounted) return;
          setState(() => _deliveryAddress = selected);
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  Future<void> _useCurrentLocation(String token) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Please enable location services');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission was not granted');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final placemarks = await _geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final place = placemarks.isEmpty ? null : placemarks.first;
      await _showAddressForm(
        token,
        latitude: position.latitude,
        longitude: position.longitude,
        initialValues: _placeToAddress(place),
      );
    } catch (error) {
      if (mounted) _showMessage('Could not get your current location: $error');
    }
  }

  Future<void> _searchLocation(String query, String token) async {
    if (query.trim().isEmpty) return;
    try {
      final locations = await _geocoding.locationFromAddress(query.trim());
      if (locations.isEmpty) throw Exception('No matching location was found');
      final location = locations.first;
      final placemarks = await _geocoding.placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      await _showAddressForm(
        token,
        latitude: location.latitude,
        longitude: location.longitude,
        initialValues: _placeToAddress(
          placemarks.isEmpty ? null : placemarks.first,
        ),
      );
    } catch (error) {
      if (mounted) _showMessage('Could not find that location: $error');
    }
  }

  Map<String, String> _placeToAddress(Placemark? place) {
    if (place == null) return {};
    final line = <String>{
      if ((place.name ?? '').trim().isNotEmpty) place.name!.trim(),
      if ((place.street ?? '').trim().isNotEmpty) place.street!.trim(),
      if ((place.subLocality ?? '').trim().isNotEmpty)
        place.subLocality!.trim(),
    }.join(', ');
    return {
      'addressLine': line,
      'city': place.locality ?? place.subAdministrativeArea ?? '',
      'state': place.administrativeArea ?? '',
      'pincode': place.postalCode ?? '',
    };
  }

  Future<void> _showAddressForm(
    String token, {
    double? latitude,
    double? longitude,
    Map<String, String> initialValues = const {},
  }) async {
    final formKey = GlobalKey<FormState>();
    final controllers = {
      'recipientName': TextEditingController(),
      'phone': TextEditingController(),
      'addressLine': TextEditingController(
        text: initialValues['addressLine'] ?? '',
      ),
      'landmark': TextEditingController(),
      'city': TextEditingController(text: initialValues['city'] ?? ''),
      'state': TextEditingController(text: initialValues['state'] ?? ''),
      'pincode': TextEditingController(text: initialValues['pincode'] ?? ''),
    };
    var addressType = 'HOME';
    var isSaving = false;
    String? saveError;

    try {
      final savedAddress = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Confirm delivery address'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: addressType,
                        decoration: const InputDecoration(
                          labelText: 'Address type',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'HOME', child: Text('Home')),
                          DropdownMenuItem(value: 'WORK', child: Text('Work')),
                          DropdownMenuItem(
                            value: 'OTHER',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(() => addressType = value);
                                }
                              },
                      ),
                      _addressField(
                        controllers['recipientName']!,
                        'Recipient name',
                      ),
                      _addressField(
                        controllers['phone']!,
                        'Contact number',
                        keyboardType: TextInputType.phone,
                      ),
                      _addressField(
                        controllers['addressLine']!,
                        'House, apartment, street',
                      ),
                      _addressField(
                        controllers['landmark']!,
                        'Landmark',
                        required: false,
                      ),
                      _addressField(controllers['city']!, 'City'),
                      _addressField(
                        controllers['state']!,
                        'State',
                        required: false,
                      ),
                      _addressField(
                        controllers['pincode']!,
                        'Pincode',
                        required: false,
                        keyboardType: TextInputType.number,
                      ),
                      if (saveError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            saveError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isSaving = true;
                          saveError = null;
                        });
                        try {
                          final address = await _addressService.createAddress(
                            token,
                            {
                              'addressType': addressType,
                              for (final entry in controllers.entries)
                                entry.key: entry.value.text.trim(),
                              if (latitude != null && longitude != null) ...{
                                'latitude': latitude,
                                'longitude': longitude,
                              },
                            },
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(address);
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              saveError = error.toString().replaceFirst(
                                'Exception: ',
                                '',
                              );
                              isSaving = false;
                            });
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save address'),
              ),
            ],
          ),
        ),
      );
      if (savedAddress != null && mounted) {
        setState(() => _deliveryAddress = savedAddress);
        _showMessage('Address saved successfully');
      }
    } finally {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }
  }

  Widget _addressField(
    TextEditingController controller,
    String label, {
    bool required = true,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
          : null,
    );
  }

  String get _addressLabel {
    final type = _deliveryAddress?['addressType'] as String?;
    if (type == 'HOME') return 'Home';
    if (type == 'WORK') return 'Work';
    if (type == 'OTHER') return 'Other';
    return 'Delivery location';
  }

  String get _addressDetails {
    final address = _deliveryAddress;
    if (address == null) return 'Tap to select your delivery address';
    return [
      address['addressLine'],
      address['city'],
      address['state'],
    ].whereType<String>().where((part) => part.isNotEmpty).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorView()
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  children: [
                    LocationHeader(
                      addressLabel: _addressLabel,
                      addressDetails: _addressDetails,
                      onTap: _openAddressPicker,
                    ),
                    _buildSearchBar(),
                    _buildCategorySection(),
                    _buildRestaurantSection(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Could not connect to server',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        onSubmitted: _searchRestaurants,
        decoration: InputDecoration(
          hintText: 'Search restaurants...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _searchRestaurants('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    if (_categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Categories',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              return _buildCategoryCard(_categories[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    return GestureDetector(
      onTap: () => _searchRestaurants(category['name'] ?? ''),
      child: Container(
        width: 85,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: category['image_url'] != null
                    ? Image.network(
                        category['image_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.fastfood,
                          size: 32,
                          color: Colors.deepOrange,
                        ),
                      )
                    : const Icon(
                        Icons.fastfood,
                        size: 32,
                        color: Colors.deepOrange,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category['name'] ?? '',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            _searchController.text.isNotEmpty
                ? 'Results (${_restaurants.length})'
                : 'Popular Restaurants',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        if (_restaurants.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                'No restaurants found',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _restaurants.length,
            itemBuilder: (context, index) {
              return _buildRestaurantCard(_restaurants[index]);
            },
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRestaurantCard(Map<String, dynamic> restaurant) {
    final rating = double.tryParse(restaurant['rating'].toString()) ?? 0.0;
    final isOpen = restaurant['is_open'] == 1 || restaurant['is_open'] == true;

    return GestureDetector(
      onTap: () {
        // TODO: Navigate to restaurant detail screen
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: restaurant['image_url'] != null
                    ? Image.network(
                        restaurant['image_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.deepOrange[50],
                          child: const Icon(
                            Icons.restaurant,
                            size: 48,
                            color: Colors.deepOrange,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.deepOrange[50],
                        child: const Icon(
                          Icons.restaurant,
                          size: 48,
                          color: Colors.deepOrange,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          restaurant['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[700],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurant['description'] ?? '',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          restaurant['address'] ?? '',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isOpen ? Colors.green[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isOpen ? 'Open' : 'Closed',
                          style: TextStyle(
                            color: isOpen ? Colors.green[700] : Colors.red[700],
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
