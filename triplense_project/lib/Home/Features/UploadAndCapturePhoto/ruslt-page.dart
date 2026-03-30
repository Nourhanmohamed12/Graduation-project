import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ResultPage extends StatefulWidget {
  final Map<String, dynamic> place;

  const ResultPage({super.key, required this.place});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage>
    with SingleTickerProviderStateMixin {
  bool _zoomed = false;
  bool _isFavorite = false;

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

  @override
  Widget build(BuildContext context) {
    final data = widget.place;
    final String name = data['name'] ?? 'Unknown Landmark';
    final String description =
        data['description'] ?? 'No description available.';
    final String locationString = data['locationString'] ?? 'Unknown location';
    final String imageUrl = data['image_url'] ?? '';
    final double rating = (data['rating'] ?? 4).toDouble();
    final String linkLocation = data['link_location'] ?? '';

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
                      errorBuilder:
                          (context, error, stackTrace) => Container(
                            height: 250,
                            color: Colors.grey[300],
                            alignment: Alignment.center,
                            child: const Text("Image not available"),
                          ),
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
                    onTap: () => setState(() => _zoomed = !_zoomed),
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.8),
                      child: const Icon(Icons.zoom_in),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      if (linkLocation.isNotEmpty) {
                        _openMapLink(context, linkLocation);
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          locationString,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.blueAccent,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Description",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          if (index < rating.floor()) {
                            return const Icon(Icons.star, color: Colors.orange);
                          } else if (index == rating.floor() &&
                              rating % 1 >= 0.5) {
                            return const Icon(
                              Icons.star_half,
                              color: Colors.orange,
                            );
                          } else {
                            return const Icon(
                              Icons.star_border,
                              color: Colors.orange,
                            );
                          }
                        }),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          setState(() {
                            _isFavorite = !_isFavorite;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _isFavorite
                                    ? 'Added to favorites (not saved in backend)'
                                    : 'Removed from favorites',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Best Recommended",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color.fromARGB(255, 8, 8, 8),
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
