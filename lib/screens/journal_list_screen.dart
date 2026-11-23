import 'package:flutter/material.dart';

// ⭐ Full module imported
import '../models/journal_entry.dart';
import '../services/journal_service.dart';

import 'add_edit_journal_screen.dart';
import 'journal_detail_screen.dart';
import 'archived_journal_screen.dart';

class JournalListScreen extends StatefulWidget {
  const JournalListScreen({super.key});

  @override
  State<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends State<JournalListScreen> {
  final JournalService _service = JournalService();

  List<JournalEntry> _entries = [];
  List<JournalEntry> _filtered = [];

  String _searchQuery = "";
  String _quoteOfTheDay = QuoteOfTheDay.random();
  int _streakCount = 0;

  bool _showFavorites = false;

  // ⭐ NEW — Emotion filter list
  List<String> _emotionFilters = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final data = await _service.getAllEntries();
    setState(() {
      _entries = data;
      _applyFilters();
      _streakCount = StreakService.calculate(data);
      _loading = false;
    });
  }

  // ⭐ FILTERING (updated to include emotion)
  void _applyFilters() {
    setState(() {
      _filtered = _entries.where((e) {
        // ⭐ Favorite filter
        if (_showFavorites && !e.isFavorite) return false;

        // ⭐ Emotion filter
        if (_emotionFilters.isNotEmpty &&
            !_emotionFilters.contains(e.emotion)) {
          return false;
        }

        // ⭐ Search filter (title + content + emotion)
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          if (!e.title.toLowerCase().contains(q) &&
              !e.content.toLowerCase().contains(q) &&
              !e.emotion.toLowerCase().contains(q)) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  Future<void> _toggleFavorite(JournalEntry e) async {
    await _service.toggleFavorite(e.id, e.isFavorite);
    _loadEntries();
  }

  Future<void> _archiveEntry(JournalEntry e) async {
    // Immediate UI removal
    setState(() {
      _entries.remove(e);
      _filtered.remove(e);
    });

    // Update Firebase
    await _service.archiveEntry(e.id);

    // Reload in background to sync with server
    _loadEntries();
  }

  Future<void> _deleteEntry(JournalEntry e) async {
    await _service.deleteEntry(e.id);
    _loadEntries();
  }

  Future<void> _onAdd() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditJournalScreen()),
    );

    if (changed == true) _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Journal"),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArchivedJournalScreen()),
              ).then((_) {
                _loadEntries();   // refresh journal list after returning
              });
            },
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _onAdd,
        child: const Icon(Icons.add),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadEntries,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ⭐ Quote
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _quoteOfTheDay,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ⭐ Streak
            Text(
              "🔥 Streak: $_streakCount days",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // ⭐ Search bar
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Search entries...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) {
                _searchQuery = v;
                _applyFilters();
              },
            ),

            const SizedBox(height: 12),

            // ⭐ Favorite filter
            Row(
              children: [
                FilterChip(
                  label: const Text("Favorites"),
                  selected: _showFavorites,
                  onSelected: (value) {
                    setState(() => _showFavorites = value);
                    _applyFilters();
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ⭐ EMOTION FILTERS
            Wrap(
              spacing: 8,
              children: [
                "happy",
                "sad",
                "school",
                "stress",
                "relationship",
                "motivation",
                "gratitude"
              ].map((emotion) {
                final active = _emotionFilters.contains(emotion);
                return FilterChip(
                  label: Text(emotion),
                  selected: active,
                  onSelected: (v) {
                    setState(() {
                      v
                          ? _emotionFilters.add(emotion)
                          : _emotionFilters.remove(emotion);
                    });
                    _applyFilters();
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ⭐ JOURNAL LIST
            ..._filtered.map((entry) {
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JournalDetailScreen(entry: entry),
                      ),
                    ).then((_) => _loadEntries());
                  },

                  // ⭐ TITLE
                  title: Text(
                    entry.title.isEmpty ? "(No Title)" : entry.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  // ⭐ CONTENT PREVIEW
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.content.length > 60
                            ? "${entry.content.substring(0, 60)}..."
                            : entry.content,
                        style: const TextStyle(fontSize: 13),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        entry.createdAt.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),

                      const SizedBox(height: 4),

                      // ⭐ Show emotion
                      Chip(
                        label: Text(entry.emotion),
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ],
                  ),

                  // ⭐ EDIT + DELETE + FAVORITE BUTTONS
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddEditJournalScreen(
                                existing: entry,
                              ),
                            ),
                          );
                          _loadEntries();
                        },
                      ),

                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red),
                        onPressed: () async {
                          await _deleteEntry(entry);
                        },
                      ),

                      IconButton(
                        icon: Icon(
                          entry.isFavorite
                              ? Icons.star
                              : Icons.star_border,
                          color: entry.isFavorite
                              ? Colors.amber
                              : Colors.grey,
                        ),
                        onPressed: () => _toggleFavorite(entry),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
