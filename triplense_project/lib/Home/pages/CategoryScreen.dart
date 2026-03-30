import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'PlaceScreen.dart';

class CategoryScreen extends StatefulWidget {
  final String categoryName;

  const CategoryScreen({super.key, required this.categoryName});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<dynamic> places = [];
  List<dynamic> filteredPlaces = [];
  bool isLoading = true;

  Set<String> favoritePlaceNames = {};

  @override
  void initState() {
    super.initState();
    fetchFavorites().then((_) => fetchPlacesByCategory());
  }

  Future<void> fetchFavorites() async {
    final url = Uri.parse('http://192.168.1.10:5000/favorites');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final names =
            data.map<String>((place) => place['name'] as String).toSet();
        setState(() {
          favoritePlaceNames = names;
        });
      }
    } catch (e) {
      print("Error fetching favorites: $e");
    }
  }

  Future<void> fetchPlacesByCategory() async {
    final url = Uri.parse(
      'http://192.168.1.10:5000/places/${widget.categoryName}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            places = data;
            filteredPlaces = data;
            isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load places');
      }
    } catch (e) {
      print('Error fetching places: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void filterPlaces(String query) {
    final lowerQuery = query.toLowerCase();

    final result =
        places.where((place) {
          final name = (place['name'] ?? '').toLowerCase();
          final description = (place['description'] ?? '').toLowerCase();
          final location = (place['locationString'] ?? '').toLowerCase();

          return name.contains(lowerQuery) ||
              description.contains(lowerQuery) ||
              location.contains(lowerQuery);
        }).toList();

    setState(() {
      filteredPlaces = result;
    });
  }

  Future<void> _addToFavorites(Map<String, dynamic> place) async {
    final response = await http.post(
      Uri.parse('http://192.168.1.10:5000/favorites'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': place['name'],
        'image_url': place['image_url'],
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        favoritePlaceNames.add(place['name']);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added to favorites')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add to favorites')),
      );
    }
  }

  Future<void> _removeFromFavorites(Map<String, dynamic> place) async {
    final response = await http.delete(
      Uri.parse('http://192.168.1.10:5000/favorites'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': place['name']}),
    );

    if (response.statusCode == 200) {
      setState(() {
        favoritePlaceNames.remove(place['name']);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Removed from favorites')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove from favorites')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
        ),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          fontFamily: 'Times New Roman',
        ),
      ),
      body: SafeArea(
        child:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: TextField(
                        onChanged: filterPlaces,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[100],
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Search by name, location, or description',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child:
                          filteredPlaces.isEmpty
                              ? const Center(child: Text("No places found."))
                              : ListView.builder(
                                itemCount: filteredPlaces.length,
                                padding: const EdgeInsets.all(12),
                                itemBuilder: (context, index) {
                                  final place = filteredPlaces[index];
                                  final String landmarkId =
                                      place['Landmark_ID']?.toString() ?? '';
                                  final String name =
                                      place['name'] ?? 'Unknown Place';
                                  final String imageUrl =
                                      place['image_url'] ?? '';
                                  final String longDescription =
                                      place['description'] ?? 'No details.';
                                  final String location =
                                      place['locationString'] ??
                                      'Unknown Location';
                                  final double rating =
                                      double.tryParse(
                                        place['rating']?.toString() ?? '0.0',
                                      ) ??
                                      0.0;
                                  final String linkLocation =
                                      place['link_location'] ?? '';

                                  final bool isFavorited = favoritePlaceNames
                                      .contains(name);

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => PlaceScreen(
                                                place: {
                                                  'Landmark_ID': landmarkId,
                                                  'name': name,
                                                  'image_url': imageUrl,
                                                  'description':
                                                      longDescription,
                                                  'locationString': location,
                                                  'rating': rating,
                                                  'link_location': linkLocation,
                                                },
                                              ),
                                        ),
                                      );
                                    },
                                    child: Card(
                                      elevation: 4,
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child:
                                                  imageUrl.isNotEmpty
                                                      ? Image.network(
                                                        imageUrl,
                                                        width: 120,
                                                        height: 120,
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (
                                                              context,
                                                              error,
                                                              stackTrace,
                                                            ) => Container(
                                                              width: 120,
                                                              height: 120,
                                                              color:
                                                                  Colors
                                                                      .grey[300],
                                                              child: const Icon(
                                                                Icons
                                                                    .broken_image,
                                                                size: 40,
                                                              ),
                                                            ),
                                                      )
                                                      : Container(
                                                        width: 120,
                                                        height: 120,
                                                        color: Colors.grey[300],
                                                        child: const Icon(
                                                          Icons
                                                              .image_not_supported,
                                                          size: 40,
                                                        ),
                                                      ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontFamily: 'Roboto',
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    location,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                isFavorited
                                                    ? Icons.favorite
                                                    : Icons.favorite_border,
                                                color:
                                                    isFavorited
                                                        ? Colors.red
                                                        : Colors.grey,
                                              ),
                                              onPressed: () {
                                                if (isFavorited) {
                                                  _removeFromFavorites(place);
                                                } else {
                                                  _addToFavorites(place);
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
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
