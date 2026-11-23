import 'dart:io';
import 'package:flutter/material.dart';

// ⭐ Import model + helpers
import '../models/journal_entry.dart';

// ⭐ Import CRUD service
import '../services/journal_service.dart';

class JournalDetailScreen extends StatefulWidget {
  final JournalEntry entry;

  const JournalDetailScreen({super.key, required this.entry});

  @override
  State<JournalDetailScreen> createState() => _JournalDetailScreenState();
}

class _JournalDetailScreenState extends State<JournalDetailScreen> {
  final JournalService _service = JournalService();
  late JournalEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  Future<void> _toggleFavorite() async {
    await _service.toggleFavorite(_entry.id, _entry.isFavorite);

    setState(() {
      // ⭐ IMPORTANT: include emotion when rebuilding entry!
      _entry = JournalEntry(
        id: _entry.id,
        title: _entry.title,
        content: _entry.content,
        createdAt: _entry.createdAt,
        photos: _entry.photos,
        tags: _entry.tags,               // still exists but unused
        isFavorite: !_entry.isFavorite,
        isArchived: _entry.isArchived,
        wordCount: _entry.wordCount,
        futureOpenDate: _entry.futureOpenDate,
        emotion: _entry.emotion,        // ⭐ FIXED → prevents disappearing
      );
    });
  }

  Future<void> _archive() async {
    await _service.archiveEntry(_entry.id);
    Navigator.pop(context, true);
  }

  Future<void> _exportPDF() async {
    await ExportPDF.generateJournalPDF(_entry);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("PDF Exported Successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isFutureLocked = _entry.futureOpenDate != null &&
        DateTime.now().isBefore(_entry.futureOpenDate!);

    return Scaffold(
      appBar: AppBar(
        title: Text(_entry.title), // ⭐ Show journal title
        actions: [
          // ⭐ Favorite Toggle
          IconButton(
            icon: Icon(
              _entry.isFavorite ? Icons.star : Icons.star_border,
              color: _entry.isFavorite ? Colors.amber : Colors.white,
            ),
            onPressed: _toggleFavorite,
          ),

          // 📄 Export PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportPDF,
          ),

          // 🗄 Archive
          IconButton(
            icon: const Icon(Icons.archive),
            onPressed: _archive,
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // ⭐ TITLE
            Text(
              _entry.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            // DATE
            Text(
              _entry.createdAt.toString(),
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 16),

            // ⭐ EMOTION DISPLAY
            if (_entry.emotion.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.mood, color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  Text(
                    "Emotion: ${_entry.emotion}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                ],
              ),

            const SizedBox(height: 16),

            // 📬 Future Letter Lock
            if (_entry.futureOpenDate != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isFutureLocked
                    ? Text(
                  "🔒 This is a Future Letter.\nOpens on: ${_entry.futureOpenDate!.toString().split(' ')[0]}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )
                    : const Text(
                  "📬 Future Letter has been unlocked.",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

            const SizedBox(height: 16),

            // ⭐ CONTENT (locked or not)
            if (isFutureLocked)
              const Center(
                child: Text(
                  "⏳ Come back when the date arrives.",
                  style: TextStyle(
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    color: Colors.black54,
                  ),
                ),
              )
            else
              Text(
                _entry.content,
                style: const TextStyle(fontSize: 17, height: 1.5),
              ),

            const SizedBox(height: 20),

            // WORD COUNT
            Text(
              "📝 ${_entry.wordCount} words",
              style: TextStyle(color: Colors.grey.shade600),
            ),

            const SizedBox(height: 20),

            // PHOTOS
            if (_entry.photos.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Photos:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    children: _entry.photos.map((path) {
                      return Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image.file(
                          File(path),
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
