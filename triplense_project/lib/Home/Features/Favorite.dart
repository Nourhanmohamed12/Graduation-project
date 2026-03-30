import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  List<dynamic> favoritePlaces = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchFavorites();
  }

  Future<void> fetchFavorites() async {
    final url = Uri.parse('http://192.168.1.10:5000/favorites');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          favoritePlaces = data;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load favorites');
      }
    } catch (e) {
      print('Error: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> toggleFavorite(String name, String imageUrl) async {
    final isFavorited = favoritePlaces.any((place) => place['name'] == name);
    final url = Uri.parse('http://192.168.1.10:5000/favorites');

    try {
      final response =
          isFavorited
              ? await http.delete(
                url,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'name': name}),
              )
              : await http.post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'name': name, 'image_url': imageUrl}),
              );

      if (response.statusCode == 200 || response.statusCode == 409) {
        fetchFavorites(); // Refresh list after change
      } else {
        print('Failed to toggle favorite: ${response.body}');
      }
    } catch (e) {
      print('Toggle error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
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
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : favoritePlaces.isEmpty
              ? const Center(child: Text('No favorites added.'))
              : ListView.builder(
                itemCount: favoritePlaces.length,
                padding: const EdgeInsets.all(12),
                itemBuilder: (context, index) {
                  final place = favoritePlaces[index];
                  final String name = place['name'] ?? 'Unknown Place';
                  final String imageUrl = place['image_url'] ?? '';
                  final bool isFavorited = favoritePlaces.any(
                    (p) => p['name'] == name,
                  ); // Always true here

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child:
                                imageUrl.isNotEmpty
                                    ? Image.network(
                                      imageUrl,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, _) => Container(
                                            width: 100,
                                            height: 100,
                                            color: Colors.grey[300],
                                            child: const Icon(
                                              Icons.broken_image,
                                            ),
                                          ),
                                    )
                                    : Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.image_not_supported,
                                      ),
                                    ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.favorite, color: Colors.red),
                            onPressed: () {
                              toggleFavorite(name, imageUrl);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
