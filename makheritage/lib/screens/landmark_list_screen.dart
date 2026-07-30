import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/landmark.dart';
import '../services/landmark_service.dart';
import '../widgets/landmark_card.dart';
import 'edit_landmark_screen.dart';
import '../main.dart'; // To access globalIsAdminMode

class LandmarkListScreen extends StatefulWidget {
  const LandmarkListScreen({super.key});

  @override
  State<LandmarkListScreen> createState() => _LandmarkListScreenState();
}

class _LandmarkListScreenState extends State<LandmarkListScreen> {
  final LandmarkService _service = LandmarkService();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Landmark>> _future;
  String _searchQuery = '';

  late final VoidCallback _refreshListener;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchLandmarks();
    
    _refreshListener = () {
      if (mounted) _retry();
    };
    globalLandmarksRefreshNotifier.addListener(_refreshListener);
  }

  @override
  void dispose() {
    globalLandmarksRefreshNotifier.removeListener(_refreshListener);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (!mounted) return;
    setState(() {
      _future = _service.fetchLandmarks();
    });
    await _future.catchError((_) => <Landmark>[]);
  }

  void _showDetailsModal(BuildContext context, Landmark landmark, bool isAdmin) {
    String displayDescription = landmark.description?.isNotEmpty == true
        ? landmark.description!
        : landmark.category;

    if (landmark.name.toLowerCase().contains('ivory tower') ||
        landmark.name.toLowerCase().contains('main admin') ||
        landmark.name.toLowerCase().contains('main building')) {
      displayDescription =
          "Completed in 1941, the Makerere University Main Administration Building, affectionately known as the Ivory Tower, stands as the most iconic architectural landmark of higher education in East Africa. Featuring a distinctive white-walled tower, bell clock, and blue-tiled roof, it served as the nerve centre for East African academic governance throughout the 20th century. Following a midnight fire in September 2020, a comprehensive restoration preserved its iconic 1941 colonial exterior while modernising its interior.";
    }

    final imagePath = landmark.imageAssetPath;
    bool isPlaying = false;
    final FlutterTts flutterTts = FlutterTts();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            flutterTts.setCompletionHandler(() {
              setModalState(() {
                isPlaying = false;
              });
            });

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  if (imagePath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imagePath.startsWith('http://') || imagePath.startsWith('https://')
                          ? Image.network(imagePath, height: 180, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())
                          : imagePath.startsWith('/') || imagePath.startsWith('file://')
                              ? Image.file(File(imagePath.replaceFirst('file://', '')), height: 180, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())
                              : Image.asset(imagePath, height: 180, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          landmark.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.volume_up : Icons.volume_off,
                          color: const Color(0xFFE5A93C),
                          size: 28,
                        ),
                        onPressed: () async {
                          if (isPlaying) {
                            await flutterTts.stop();
                            setModalState(() {
                              isPlaying = false;
                            });
                          } else {
                            await flutterTts.speak(displayDescription);
                            setModalState(() {
                              isPlaying = true;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    landmark.category,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayDescription,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  if (isAdmin) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Landmark'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          flutterTts.stop();
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => EditLandmarkScreen(landmark: landmark)),
                          ).then((_) => _retry());
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      flutterTts.stop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: globalIsAdminMode,
      builder: (context, isAdmin, child) {
        return FutureBuilder<List<Landmark>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _retry,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final allLandmarks = snapshot.data ?? [];
            
            final landmarks = allLandmarks.where((l) => 
              l.name.toLowerCase().contains(_searchQuery.toLowerCase())
            ).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search Landmarks',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                
                Expanded(
                  child: landmarks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('No landmarks found.'),
                              if (_searchQuery.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                  child: const Text('Clear search'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _retry,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: landmarks.length,
                            itemBuilder: (context, index) {
                              final landmark = landmarks[index];
                              
                              if (isAdmin) {
                                return LandmarkCard(
                                  landmark: landmark,
                                  onTap: () => _showDetailsModal(context, landmark, true),
                                  onDelete: () async {
                                    bool confirm = await showDialog(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text('Confirm Delete'),
                                        content: Text('Are you sure you want to delete ${landmark.name}?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                        ],
                                      ),
                                    ) ?? false;
                                    if (confirm) {
                                      bool success = await _service.deleteLandmark(landmark.id);
                                      if (success) {
                                        setState(() {
                                          _searchController.clear();
                                          _searchQuery = '';
                                        });
                                        _retry();
                                      }
                                    }
                                  },
                                );
                              }
                              
                              return LandmarkCard(
                                landmark: landmark,
                                onTap: () => _showDetailsModal(context, landmark, false),
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        );
      }
    );
  }
}
