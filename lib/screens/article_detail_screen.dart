import 'package:flutter/material.dart';


class ArticleDetailScreen extends StatelessWidget {
  // Use the same model, but we pass it locally
  final dynamic article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: article.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                article.category.toUpperCase(),
                style: TextStyle(color: article.color, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              article.title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2),
            ),

            const SizedBox(height: 24),

            // Match Score Indicator
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.amber[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  "This matches ${article.matchScore}% with your goals",
                  style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic),
                ),
              ],
            ),

            const Divider(height: 40),

            // Content
            Text(
              article.content,
              style: const TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF4A4A4A)),
            ),
          ],
        ),
      ),
    );
  }
}