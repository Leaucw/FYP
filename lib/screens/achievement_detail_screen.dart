import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../services/achievement_service.dart';
import 'add_edit_achievement_screen.dart';

class AchievementDetailScreen extends StatelessWidget {
  final Achievement achievement;
  final AchievementService _service = AchievementService();

  AchievementDetailScreen({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    final bool isSharedSimplified = achievement.sharedSimplified == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Achievement Details"),
        actions: [
          if (!isSharedSimplified) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddEditAchievementScreen(existing: achievement),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(context),
            )
          ]
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --------------------------------------------------------------------
            // PHOTO
            // --------------------------------------------------------------------
            if (achievement.photoBase64 != null &&
                achievement.photoBase64!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(achievement.photoBase64!),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.emoji_events, size: 60),
                ),
              ),

            const SizedBox(height: 20),

            // TITLE
            Text(
              achievement.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            if (isSharedSimplified)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Chip(
                  backgroundColor: Colors.blue.shade100,
                  avatar: const Icon(Icons.group, size: 18),
                  label: const Text(
                    "Shared Achievement",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // CATEGORY + POINTS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Chip(
                  label: Text(
                    achievement.category,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Chip(
                  avatar:
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  label: Text(
                    "${achievement.points} pts",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // DATE
            _sectionTitle("Date"),
            Text(
              achievement.date.toString().split(" ")[0],
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 20),

            // DESCRIPTION
            _sectionTitle("Description"),
            Text(
              achievement.description.isEmpty
                  ? "No description provided."
                  : achievement.description,
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 20),

            // --------------------------------------------------------------------
            // COMPLETED WITH (FINAL FIXED VERSION)
            // --------------------------------------------------------------------

            _sectionTitle("Completed With"),
            const SizedBox(height: 6),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.person, size: 28, color: Colors.purple),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // NAME OR USERID FALLBACK
                        FutureBuilder(
                          future: achievement.sharedSimplified == true
                          // Shared copy → show creator userId
                              ? _service.getFriendlyUserId(achievement.completedWithId ?? "")
                          // Main copy → show partner userId
                              : _service.getFriendlyUserId(achievement.completedWithAppUid ?? ""),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Text(
                                "Loading...",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              );
                            }

                            final friendlyId = snapshot.data as String;

                            return Text(
                              friendlyId,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 4),

                        // ROLE LABEL
                        Text(
                          achievement.sharedSimplified == true
                              ? "Creator"
                              : "Partner",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // APP USER CHIP
                  if (achievement.completedWithAppUid != null &&
                      achievement.completedWithAppUid!.isNotEmpty)
                    const Chip(
                      avatar: Icon(Icons.app_registration, size: 16),
                      label: Text("App User"),
                    )
                  else
                    const Chip(
                      avatar: Icon(Icons.person_outline, size: 16),
                      label: Text("Not App User"),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --------------------------------------------------------------------
            // LOCATION
            // --------------------------------------------------------------------
            if (achievement.locationName != null &&
                achievement.locationName!.isNotEmpty) ...[
              _sectionTitle("Location Name"),
              Text(
                achievement.locationName!,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
            ],

            if (achievement.latitude != null &&
                achievement.longitude != null) ...[
              _sectionTitle("Coordinates"),
              Text(
                "${achievement.latitude!.toStringAsFixed(5)}, "
                    "${achievement.longitude!.toStringAsFixed(5)}",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
            ],

            // --------------------------------------------------------------------
            // ASSOCIATED PEOPLE
            // --------------------------------------------------------------------
            if (achievement.associatedPeople.isNotEmpty) ...[
              _sectionTitle("Associated People"),
              Wrap(
                spacing: 6,
                children: achievement.associatedPeople
                    .map((p) => Chip(label: Text(p)))
                    .toList(),
              ),
            ],

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Achievement?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Delete"),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _service.deleteAchievement(achievement);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
