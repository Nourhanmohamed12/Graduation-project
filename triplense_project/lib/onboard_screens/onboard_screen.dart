import 'package:flutter/material.dart';
import 'package:triplense_project/authentication/signup.dart';
import '../onboard_screens/first_screen.dart';
import '../onboard_screens/secound_screen.dart';
import '../onboard_screens/third_screen.dart';

class OnboardScreen extends StatefulWidget {
  const OnboardScreen({super.key});

  @override
  State<OnboardScreen> createState() => _OnboardScreenState();
}

class _OnboardScreenState extends State<OnboardScreen> {
  final PageController _controller = PageController();
  int index = 0;

  void _goToNextPage() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToSignup() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SignUp()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (value) => setState(() => index = value),
                    children: const [
                      FirstScreen(),
                      SecondScreen(),
                      ThirdScreen(),
                    ],
                  ),
                ),
                if (index != 2)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (i) => CustomIndicator(active: i == index),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(30),
                  child:
                      index == 2
                          ? Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: const Color.fromARGB(
                                    255,
                                    222,
                                    159,
                                    64,
                                  ),
                                ),
                                width: MediaQuery.of(context).size.width * 0.9,
                                height: 50,
                                child: TextButton(
                                  onPressed: _navigateToSignup,
                                  child: const Text(
                                    "Get Started",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 25),
                            ],
                          )
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: _navigateToSignup,
                                child: const Text(
                                  "Skip",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _goToNextPage,
                                child: const Text(
                                  "Next",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                ),
              ],
            ),
            Positioned(
              top: 20,
              left: 10,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  size: 30,
                  color: Colors.black,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomIndicator extends StatelessWidget {
  final bool active;
  const CustomIndicator({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      duration: const Duration(milliseconds: 250),
      width: active ? 30 : 10,
      height: 10,
      decoration: BoxDecoration(
        color: active ? const Color.fromARGB(255, 242, 182, 91) : Colors.grey,
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }
}
