import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FeedbackDialog {
  static void show(BuildContext context, {
    required String title,
    required String message,
    bool isSuccess = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final messageColor = isDark ? Colors.white70 : Colors.grey.shade600;
    final iconBgColor = isSuccess
        ? (isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.shade50)
        : (isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red.shade50);

    showDialog(
      context: context,
      barrierDismissible: false, // User must tap button to close
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: dialogBg,
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Wrap content
            children: [
              // 1. The Icon Circle
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle : Icons.error_outline,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              
              // 2. Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 10),
              
              // 3. Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: messageColor,
                ),
              ),
              const SizedBox(height: 25),
              
              // 4. Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSuccess ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    "OK, GOT IT",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}