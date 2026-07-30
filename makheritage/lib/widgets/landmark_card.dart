import 'package:flutter/material.dart';
import '../models/landmark.dart';

class LandmarkCard extends StatelessWidget {
  final Landmark landmark;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const LandmarkCard({
    super.key,
    required this.landmark,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    String displayDesc = landmark.description?.isNotEmpty == true
        ? landmark.description!
        : landmark.category;

    if (landmark.name.toLowerCase().contains('ivory tower') ||
        landmark.name.toLowerCase().contains('main admin') ||
        landmark.name.toLowerCase().contains('main building')) {
      displayDesc =
          "Completed in 1941, the Makerere University Main Administration Building, affectionately known as the Ivory Tower, stands as the most iconic architectural landmark of higher education in East Africa. Featuring a distinctive white-walled tower, bell clock, and blue-tiled roof, it served as the nerve centre for East African academic governance throughout the 20th century. Following a midnight fire in September 2020, a comprehensive restoration preserved its iconic 1941 colonial exterior while modernising its interior.";
    }

    final imagePath = landmark.imageAssetPath;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(12),
        leading: imagePath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  imagePath,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => CircleAvatar(
                    backgroundColor: const Color(0xFF006633),
                    child: Text(
                      landmark.name.isNotEmpty ? landmark.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              )
            : CircleAvatar(
                backgroundColor: const Color(0xFF006633),
                child: Text(
                  landmark.name.isNotEmpty ? landmark.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
        title: Text(landmark.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          displayDesc,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
                tooltip: 'Delete Landmark',
              )
            : Icon(
                landmark.hasCoordinates ? Icons.location_on : Icons.location_off,
                color: landmark.hasCoordinates ? const Color(0xFFE5A93C) : Colors.grey,
              ),
      ),
    );
  }
}