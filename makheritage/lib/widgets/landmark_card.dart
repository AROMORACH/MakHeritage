import 'package:flutter/material.dart';
import '../models/landmark.dart';

class LandmarkCard extends StatelessWidget {
  final Landmark landmark;
  final VoidCallback? onTap;

  const LandmarkCard({super.key, required this.landmark, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF006633),
          child: Text(
            landmark.name.isNotEmpty ? landmark.name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(landmark.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(landmark.description?.isNotEmpty == true
            ? landmark.description!
            : landmark.category),
        trailing: Icon(
          landmark.hasCoordinates ? Icons.location_on : Icons.location_off,
          color: landmark.hasCoordinates ? const Color(0xFFE5A93C) : Colors.grey,
        ),
      ),
    );
  }
}
