import 'package:flutter/material.dart';

class LocationHeader extends StatelessWidget {
  const LocationHeader({
    required this.addressLabel,
    required this.addressDetails,
    required this.onTap,
    super.key,
  });

  final String addressLabel;
  final String addressDetails;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.red, size: 30),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        addressLabel,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down),
                    ],
                  ),
                  Text(
                    addressDetails,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

            IconButton(
              onPressed: onTap,
              icon: const Icon(Icons.keyboard_arrow_down, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}
