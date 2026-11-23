import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ⭐ Import the new combined module (JournalEntry + helpers)
import '../models/journal_entry.dart';

// ⭐ JournalService (CRUD only)
import '../services/journal_service.dart';

class AddEditJournalScreen extends StatefulWidget {
  final JournalEntry? existing;

  const AddEditJournalScreen({super.key, this.existing});

  @override
  State<AddEditJournalScreen> createState() => _AddEditJournalScreenState();
}

class _AddEditJournalScreenState extends State<AddEditJournalScreen> {
  final _formKey = GlobalKey<FormState>();

  final JournalService _service = JournalService();

  // ⭐ Title controller
  late TextEditingController _titleCtrl;

  // Content controller
  late TextEditingController _contentCtrl;

  List<String> _photos = [];
  bool _isFavorite = false;
  DateTime? _futureOpenDate;

  // ⭐ NEW — emotion replaces tags
  String? _selectedEmotion;

  bool _saving = false;

  // Suggested prompts
  final List<String> prompts = [
    "What made you smile today?",
    "What challenged you recently?",
    "What are you grateful for?",
    "What is something you want to improve?",
    "Write a message to your future self."
  ];

  // Emotion dropdown options
  final List<String> emotionOptions = [
    "happy",
    "sad",
    "school",
    "stress",
    "relationship",
    "motivation",
    "gratitude"
  ];

  @override
  void initState() {
    super.initState();

    _titleCtrl = TextEditingController(text: widget.existing?.title ?? "");
    _contentCtrl = TextEditingController(text: widget.existing?.content ?? "");

    if (widget.existing != null) {
      _photos = List.from(widget.existing!.photos);

      // ⭐ Load emotion (NEW FIELD)
      _selectedEmotion = widget.existing!.emotion;

      _isFavorite = widget.existing!.isFavorite;
      _futureOpenDate = widget.existing!.futureOpenDate;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  // Pick photo
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);

    if (img != null) {
      setState(() => _photos.add(img.path));
    }
  }

  // Pick future open date
  Future<void> _pickFutureDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 50),
    );

    if (picked != null) {
      setState(() => _futureOpenDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      if (widget.existing == null) {
        // ⭐ Create new journal with EMOTION instead of tags
        await _service.addEntry(
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          emotion: _selectedEmotion,   // ⭐ NEW
          photos: _photos,
          isFavorite: _isFavorite,
          futureOpenDate: _futureOpenDate,
        );
      } else {
        // ⭐ Update existing journal with emotion
        await _service.updateEntry(
          id: widget.existing!.id,
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          emotion: _selectedEmotion,    // ⭐ NEW
          photos: _photos,
          isFavorite: _isFavorite,
          futureOpenDate: _futureOpenDate,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Edit Journal" : "New Journal"),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? Colors.amber : Colors.grey,
            ),
            onPressed: () => setState(() {
              _isFavorite = !_isFavorite;
            }),
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

              // ⭐ TITLE FIELD
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? "Title required" : null,
              ),

              const SizedBox(height: 15),

              // ⭐ Writing Prompts
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: prompts.map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: OutlinedButton(
                        child: Text(p),
                        onPressed: () {
                          setState(() {
                            _contentCtrl.text += "\n\n$p\n";
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 15),

              // ✍️ CONTENT FIELD
              TextFormField(
                controller: _contentCtrl,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: "Write your thoughts...",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? "Write something" : null,
              ),

              const SizedBox(height: 15),

              // ⭐ EMOTION DROPDOWN
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Emotion",
                  border: OutlineInputBorder(),
                ),
                value: _selectedEmotion,
                items: emotionOptions.map((emotion) {
                  return DropdownMenuItem(
                    value: emotion,
                    child: Text(emotion),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedEmotion = v),
                validator: (v) =>
                (v == null || v.isEmpty) ? "Please select an emotion" : null,
              ),

              const SizedBox(height: 15),

              // ADD PHOTO
              ElevatedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.photo),
                label: const Text("Add Photo"),
              ),

              Wrap(
                children: _photos.map((p) {
                  return Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.file(
                      File(p),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // FUTURE LETTER DATE
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickFutureDate,
                    icon: const Icon(Icons.lock_clock),
                    label: const Text("Future Letter Date"),
                  ),
                  const SizedBox(width: 10),
                  if (_futureOpenDate != null)
                    Text(
                      "Opens: ${_futureOpenDate!.toString().split(' ')[0]}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                ],
              ),

              const SizedBox(height: 25),

              // SAVE BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const CircularProgressIndicator()
                      : Text(isEdit ? "Update" : "Save"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
