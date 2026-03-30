import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:triplense_project/service/auth.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class PlaceScreen extends StatefulWidget {
  final Map<String, dynamic> place;

  const PlaceScreen({super.key, required this.place});

  @override
  State<PlaceScreen> createState() => _PlaceScreenState();
}

class _PlaceScreenState extends State<PlaceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _zoomed = false;
  bool isFavorite = false; // State to track if the place is a favorite
  List<Map<String, dynamic>> _recommendations = [];
  bool _isLoading = true;
  late DateTime _viewStartTime;
  double _userRating = 0; // Added to store the user's selected rating
  Set<String> favoritePlaceNames = {};
  bool isLoadingFavorite = true;

  Future<void> fetchFavoritesForPlace() async {
    final url = Uri.parse('http://192.168.1.10:5000/favorites');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final favoriteNames =
            data.map<String>((place) => place['name'] as String).toSet();
        final placeName = widget.place['name'];

        setState(() {
          isFavorite = favoriteNames.contains(placeName);
          isLoadingFavorite = false;
        });
      }
    } catch (e) {
      print("Error fetching favorites: $e");
      setState(() => isLoadingFavorite = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _viewStartTime = DateTime.now();
    print('Passed place data: ${widget.place}');
    // Initialize _userRating from place data if available, otherwise 0
    _userRating = (widget.place['user_rating'] ?? 0).toDouble();
    _fetchRecommendations();
    fetchFavorites();
    fetchFavoritesForPlace();
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

  @override
  void dispose() {
    _controller.dispose();
    final viewEndTime = DateTime.now();
    final viewDuration =
        viewEndTime.difference(_viewStartTime).inSeconds.toDouble();
    _sendInteraction(action: 'view', timeSpent: viewDuration);
    super.dispose();
  }

  Future<void> _fetchRecommendations() async {
    final currentUser = await AuthMethods().getCurrentUser();
    if (currentUser == null) {
      print('User not logged in');
      setState(() => _isLoading = false); // Ensure loading is false if no user
      return;
    }

    final userId = currentUser.uid;
    final currentLandmarkId = widget.place['Landmark_ID'];
    if (currentLandmarkId == null) {
      print('Landmark ID not found in place data');
      setState(
        () => _isLoading = false,
      ); // Ensure loading is false if no Landmark ID
      return;
    }
    print('rec input data: $userId , $currentLandmarkId');
    try {
      final response = await http.get(
        Uri.parse(
          'http://192.168.1.10:6000/recommend?user_id=$userId&landmark_id=$currentLandmarkId',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _recommendations = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        print("Failed to fetch recommendations: ${response.statusCode}");
        print("Response body: ${response.body}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error fetching recommendations: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendInteraction({
    required String action,
    double? timeSpent,
    double? rating,
  }) async {
    final currentUser = await AuthMethods().getCurrentUser();
    if (currentUser == null) return;

    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');

    final data = {
      'user_id': currentUser.uid,
      'Landmark_ID': widget.place['Landmark_ID'],
      'action': action,
      'timestamp': formatter.format(now),
      'time_spent': timeSpent,
      'rating': rating,
    };

    print("Sending interaction: $data");

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.10:6000/interact'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        print("Interaction sent successfully");
      } else {
        print("Failed to send interaction: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    } catch (e) {
      print("Error sending interaction: $e");
    }
  }

  Future<void> _submitRating(double rating) async {
    setState(() {
      _userRating = rating; // Update the local state with the new rating
    });
    await _sendInteraction(action: 'rate', rating: rating);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Thank you for your rating!')));
  }

  void _openMapLink(BuildContext context, String url) async {
    final Uri mapUri = Uri.parse(url);
    if (await canLaunchUrl(mapUri)) {
      await launchUrl(mapUri);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open map link')));
    }
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
        isFavorite = true;
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
        isFavorite = false;
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

  Widget _buildLoadingAnimation() {
    return Padding(
      padding: const EdgeInsets.only(top: 60.0), // Adjust this value as needed
      child: Center(
        child: LoadingAnimationWidget.newtonCradle(
          color: const Color.fromARGB(213, 255, 153, 0),
          size: 80.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.place['name'] ?? 'Unknown Place';
    final String imageUrl = widget.place['image_url'] ?? '';
    final String location =
        widget.place['locationString'] ?? 'Unknown Location';
    final String description = widget.place['description'] ?? 'No description.';
    final String linkLocation = widget.place['link_location'] ?? '';

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  child: AnimatedScale(
                    scale: _zoomed ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 250,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.8),
                      child: const Icon(Icons.arrow_back),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _zoomed = !_zoomed;
                      });
                    },
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.8),
                      child: const Icon(Icons.zoom_in),
                    ),
                  ),
                ),
                if (_zoomed)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _zoomed = false;
                        });
                      },
                      child: Container(
                        color: Colors.black.withOpacity(0.8),
                        child: Center(
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 10,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            if (linkLocation.isNotEmpty) {
                              _openMapLink(context, linkLocation);
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                linkLocation.isNotEmpty
                                    ? "Location of Place"
                                    : location,
                                style: const TextStyle(
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Description",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),

            // Rating & Favorite + Best Recommended
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User rating input and Favorite Icon
                  Row(
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          return IconButton(
                            icon: Icon(
                              index < _userRating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.orange,
                              size: 28, // Slightly larger for user interaction
                            ),
                            onPressed: () {
                              _submitRating(index + 1.0);
                            },
                          );
                        }),
                      ),
                      const Spacer(),
                      isLoadingFavorite
                          ? const CircularProgressIndicator()
                          : IconButton(
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite ? Colors.red : Colors.grey,
                            ),
                            onPressed: () async {
                              if (isFavorite) {
                                await _removeFromFavorites(widget.place);
                              } else {
                                await _addToFavorites(widget.place);
                                await _sendInteraction(action: 'love');
                              }
                            },
                          ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    "Best Recommended",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 8, 8, 8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _isLoading
                      ? _buildLoadingAnimation()
                      : _recommendations.isEmpty
                      ? const Text("No recommendations found.")
                      : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              _recommendations.map((place) {
                                return GestureDetector(
                                  onTap: () async {
                                    // Send view interaction for current place before navigating
                                    final viewEndTime = DateTime.now();
                                    final viewDuration =
                                        viewEndTime
                                            .difference(_viewStartTime)
                                            .inSeconds
                                            .toDouble();
                                    await _sendInteraction(
                                      action: 'view',
                                      timeSpent: viewDuration,
                                    );

                                    // Navigate to new PlaceScreen
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder:
                                            (context) =>
                                                PlaceScreen(place: place),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 150,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.white,
                                      boxShadow: const [
                                        BoxShadow(
                                          blurRadius: 4,
                                          color: Colors.black12,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(12),
                                              ),
                                          child: Image.network(
                                            place['image_url'] ??
                                                'https://via.placeholder.com/150', // Fallback image
                                            height: 100,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(
                                            place['name'] ?? 'Unknown Place',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
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
