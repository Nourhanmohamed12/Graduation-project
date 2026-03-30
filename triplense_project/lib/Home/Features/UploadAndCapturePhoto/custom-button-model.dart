
import 'package:flutter/material.dart';

class CustomButtonModel extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isProcessing;

  const CustomButtonModel({super.key, 
    required this.text,
    required this.onPressed,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(

      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor:Colors.white, // Customize button color
        padding:const  EdgeInsets.symmetric(vertical: 14, horizontal: 40), // Adjust padding as needed
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // Adjust border radius as needed
        ),
      ),
      child:  Stack(
        alignment: Alignment.center,
        children: [
          if (!isProcessing) // Show button text when not processing
            Text(
              text,
              style:const  TextStyle(
                color:Color.fromARGB(255, 192, 141, 64),
                fontSize: 20,
              ),
            ),
          if (isProcessing) // Show CircularProgressIndicator when processing
           const  SizedBox(
              height: 30, // Adjust size as needed
              width: 30,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            ),
        ],
      ),
    );
  }
}
