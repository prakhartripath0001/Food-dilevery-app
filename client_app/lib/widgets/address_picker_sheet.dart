import 'package:flutter/material.dart';

import '../services/address_service.dart';

class AddressPickerSheet extends StatefulWidget {
  const AddressPickerSheet({
    required this.token,
    required this.onUseCurrentLocation,
    required this.onSearch,
    required this.onAddAddress,
    required this.onSelectAddress,
    super.key,
  });

  final String token;
  final VoidCallback onUseCurrentLocation;
  final ValueChanged<String> onSearch;
  final VoidCallback onAddAddress;
  final Future<void> Function(Map<String, dynamic>) onSelectAddress;

  @override
  State<AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends State<AddressPickerSheet> {
  final _searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _addresses;
  bool _isSelecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _addresses = AddressService().getAddresses(widget.token);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectAddress(Map<String, dynamic> address) async {
    setState(() {
      _isSelecting = true;
      _error = null;
    });
    try {
      await widget.onSelectAddress(address);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _isSelecting = false;
        });
      }
    }
  }

  String _addressSummary(Map<String, dynamic> address) {
    return [
      address['addressLine'],
      address['landmark'],
      address['city'],
    ].whereType<String>().where((part) => part.isNotEmpty).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Select delivery location',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: widget.onSearch,
              decoration: InputDecoration(
                hintText: 'Search for area, street or building',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () => widget.onSearch(_searchController.text),
                  icon: const Icon(Icons.arrow_forward),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.my_location, color: Colors.deepOrange),
              title: const Text('Use current location'),
              onTap: widget.onUseCurrentLocation,
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saved addresses',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: widget.onAddAddress,
                  icon: const Icon(Icons.add),
                  label: const Text('Add new'),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _addresses,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Could not load saved addresses: ${snapshot.error}',
                      ),
                    );
                  }
                  final addresses = snapshot.data ?? const [];
                  if (addresses.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No saved addresses yet.'),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: addresses.length,
                    itemBuilder: (context, index) {
                      final address = addresses[index];
                      final type =
                          (address['addressType'] as String? ?? 'OTHER')
                              .toLowerCase();
                      final isDefault =
                          address['isDefault'] == true ||
                          address['isDefault'] == 1;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        enabled: !_isSelecting,
                        leading: Icon(
                          type == 'home'
                              ? Icons.home_outlined
                              : Icons.work_outline,
                        ),
                        title: Text(
                          '${address['addressType'] ?? 'Address'}${isDefault ? ' · Default' : ''}',
                        ),
                        subtitle: Text(_addressSummary(address), maxLines: 2),
                        onTap: () => _selectAddress(address),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
