import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:triplense_project/Home/Features/Favorite.dart';
import 'package:triplense_project/Home/Features/edit_profile.dart';
import 'package:triplense_project/Home/Features/chat-bot/view/chat-screen.dart';
import 'package:triplense_project/authentication/login.dart';
import 'package:triplense_project/provider/ui_provider.dart';
import 'package:triplense_project/Home/pages/CategoryScreen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:triplense_project/Home/Features/UploadAndCapturePhoto/capture&upload_photo.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final PageController _pageController = PageController();
  final ImagePicker _picker = ImagePicker();
  int _currentPage = 0;
  Timer? _carouselTimer;

  final List<Map<String, String>> landmarks = [
    {
      'title': 'Pyramids',
      'location': 'Giza, Egypt',
      'image': 'assets/pyramid.png',
    },
    {
      'title': 'Citadel',
      'location': 'Alexandria, Egypt',
      'image': 'assets/cat.png',
    },
    {
      'title': 'Mosque Muhammad Ali',
      'location': 'Cairo, Egypt',
      'image': 'assets/ma.png',
    },
  ];

  final List<Map<String, String>> categories = [
    {'title': 'Temple', 'image': 'assets/tem.jpg'},
    {'title': 'Religious', 'image': 'assets/Islamic.png'},
    {'title': 'Nature', 'image': 'assets/Natural.png'},
    {'title': 'Ancient', 'image': 'assets/historical.png'},
    {'title': 'Modern', 'image': 'assets/Modern.PNG'},
  ];

  List<Map<String, String>> filteredCategories = [];

  @override
  void initState() {
    super.initState();
    filteredCategories = categories;

    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients && mounted) {
        _currentPage = (_currentPage + 1) % landmarks.length;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _filterCategories(String query) {
    setState(() {
      filteredCategories =
          categories
              .where(
                (category) => category['title']!.toLowerCase().contains(
                  query.toLowerCase(),
                ),
              )
              .toList();
    });
  }

  void _openCategoryScreen(String categoryName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryScreen(categoryName: categoryName),
      ),
    );
  }

  Future<void> _openCameraOrGallery() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? photo = await _picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (photo != null) _showExploreDialog(photo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text('Choose from gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? photo = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (photo != null) _showExploreDialog(photo);
                },
              ),
            ],
          ),
    );
  }

  void _showExploreDialog(XFile photo) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Explore Landmark"),
            content: const Text("Do you want to explore this landmark?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  print("User selected image path: ${photo.path}");
                  // TODO: Navigate to landmark detail or analysis
                },
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<UiProvider>(context);

    return WillPopScope(
      onWillPop: () async {
        // Check if it is possible to go back
        if (Navigator.canPop(context)) {
          Navigator.pop(context); // Return to the previous page
        } else {
          SystemNavigator.pop(); // Close the application
        }
        return false; // Prevent normal navigation
      },
      child: Scaffold(
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 192, 141, 64),
                ),
                accountName: Text(
                  FirebaseAuth.instance.currentUser?.displayName ?? "User",
                ),
                accountEmail: Text(
                  FirebaseAuth.instance.currentUser?.email ?? "",
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: const Color.fromARGB(255, 254, 250, 224),
                  backgroundImage:
                      FirebaseAuth.instance.currentUser?.photoURL != null
                          ? NetworkImage(
                            FirebaseAuth.instance.currentUser!.photoURL!,
                          )
                          : null,
                  child:
                      FirebaseAuth.instance.currentUser?.photoURL == null
                          ? const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.black54,
                          )
                          : null,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Home'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.chat),
                title: const Text('ChatBot'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite),
                title: const Text('Favorite'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FavoriteScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfile()),
                  );
                },
              ),
              const Divider(),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode),
                title: const Text("Dark Mode"),
                value: themeProvider.isDark,
                onChanged: (value) => themeProvider.changeTheme(),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LogIn()),
                  );
                },
              ),
            ],
          ),
        ),
        appBar: null,
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: 300,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: landmarks.length,
                    itemBuilder: (context, index) {
                      final landmark = landmarks[index];
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(landmark['image']!, fit: BoxFit.cover),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.3),
                                  Colors.black.withOpacity(0.1),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 25,
                            left: 10,
                            child: Builder(
                              builder:
                                  (context) => IconButton(
                                    icon: const Icon(
                                      Icons.menu,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                    onPressed:
                                        () => Scaffold.of(context).openDrawer(),
                                  ),
                            ),
                          ),
                          Positioned(
                            bottom: 20,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.arrow_back_outlined,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          landmark['title']!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Times New Roman',
                                            shadows: [
                                              Shadow(
                                                color: Colors.black,
                                                blurRadius: 5,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Icon(
                                          Icons.arrow_forward_outlined,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      landmark['location']!,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Times New Roman',
                                        fontSize: 14,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black,
                                            blurRadius: 3,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    onChanged: _filterCategories,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[100],
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search for a category',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.camera_alt),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const UploadAndCapturePhoto(),
                            ),
                          );
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...filteredCategories.map((category) {
                  return GestureDetector(
                    onTap: () => _openCategoryScreen(category['title']!),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        image: DecorationImage(
                          image: AssetImage(category['image']!),
                          fit: BoxFit.cover,
                        ),
                      ),
                      alignment: Alignment.bottomLeft,
                      padding: const EdgeInsets.all(0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          category['title']!,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Times New Roman',
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
