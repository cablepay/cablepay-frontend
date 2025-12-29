import 'package:flutter/material.dart';


class LoadingButton extends StatelessWidget {
  final bool isLoading;
  final String label;
  final VoidCallback onPressed;
  const LoadingButton({required this.isLoading, required this.label, required this.onPressed});


  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label),
    );
  }
}