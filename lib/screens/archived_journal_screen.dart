import 'package:flutter/material.dart';
import '../models/journal_entry.dart';
import '../services/journal_service.dart';
import 'add_edit_journal_screen.dart';

class ArchivedJournalScreen extends StatefulWidget {
  const ArchivedJournalScreen({super.key});

  @override
  State<ArchivedJournalScreen> createState() => _ArchivedJournalScreenState();
}

class _ArchivedJournalScreenState extends State<ArchivedJournalScreen> {
  final JournalService _service = JournalService();
  List<JournalEntry> _archived = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _service.getArchivedEntries();
    setState(() {
      _archived = data;
      _loading = false;
    });
  }

  Future<void> _delete(String id) async {
    await _service.deleteEntry(id);
    _load();
  }

  Future<void> _unarchive(String id) async {
    await _service.unarchiveEntry(id);
    _load();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Journal restored")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Archived Journals"),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())

          : _archived.isEmpty
          ? const Center(
        child: Text("No archived journals."),
      )

          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _archived.length,
        itemBuilder: (context, index) {
          final entry = _archived[index];

          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddEditJournalScreen(existing: entry),
                  ),
                );
                _load();
              },

              // ⭐ Show TITLE if available
              title: Text(
                entry.title.isEmpty ? "(No Title)" : entry.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ⭐ Content preview
                  Text(
                    entry.content.length > 60
                        ? "${entry.content.substring(0, 60)}..."
                        : entry.content,
                  ),

                  const SizedBox(height: 4),

                  Text(
                    entry.createdAt.toString(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),

              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ⭐ Restore
                  IconButton(
                    icon:
                    const Icon(Icons.restore, color: Colors.green),
                    onPressed: () => _unarchive(entry.id),
                  ),

                  // ⭐ Delete permanently
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _delete(entry.id),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
