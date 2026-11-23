import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../services/achievement_service.dart';
import 'add_edit_achievement_screen.dart';
import 'achievement_detail_screen.dart';
import 'package:fyp/utils/achievement_config.dart';
import 'achievement_analytics_screen.dart';

class AchievementsListScreen extends StatefulWidget {
  const AchievementsListScreen({super.key});

  @override
  State<AchievementsListScreen> createState() => _AchievementsListScreenState();
}

class _AchievementsListScreenState extends State<AchievementsListScreen> {
  final AchievementService service = AchievementService();

  String searchText = "";
  AchievementCategory? selectedCategory;
  int? selectedMonth;
  int? selectedYear;

  void _openFilterPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  const Text(
                    "Filters",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 20),

                  // Category filter
                  DropdownButtonFormField<AchievementCategory>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: "Category"),
                    items: AchievementCategory.values
                        .map(
                          (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.toString().split('.').last),
                      ),
                    )
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedCategory = v),
                  ),

                  const SizedBox(height: 12),

                  // Month
                  DropdownButtonFormField<int>(
                    value: selectedMonth,
                    decoration: const InputDecoration(labelText: "Month"),
                    items: List.generate(
                      12,
                          (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text("Month ${i + 1}"),
                      ),
                    ),
                    onChanged: (v) => setModalState(() => selectedMonth = v),
                  ),

                  const SizedBox(height: 12),

                  // Year
                  DropdownButtonFormField<int>(
                    value: selectedYear,
                    decoration: const InputDecoration(labelText: "Year"),
                    items: List.generate(
                      20,
                          (i) => DropdownMenuItem(
                        value: 2010 + i,
                        child: Text("${2010 + i}"),
                      ),
                    ),
                    onChanged: (v) => setModalState(() => selectedYear = v),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              selectedCategory = null;
                              selectedMonth = null;
                              selectedYear = null;
                            });
                          },
                          child: const Text("Reset"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {});
                          },
                          child: const Text("Apply"),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Stream<List<Achievement>> _getStream() {
    final hasFilters =
        selectedCategory != null || selectedMonth != null || selectedYear != null;

    if (hasFilters) {
      return service.filterAchievements(
        category: selectedCategory,
        month: selectedMonth,
        year: selectedYear,
      );
    }

    if (searchText.isNotEmpty) {
      return service.searchAchievements(searchText);
    }

    return service.getAchievements();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Achievements"),
        actions: [
          // 📊 NEW ANALYTICS BUTTON
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: "View Analytics",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AchievementAnalyticsScreen(),
                ),
              );
            },
          ),

          // Existing filter button
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _openFilterPanel,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(55),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              onChanged: (v) => setState(() => searchText = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Search achievements...",
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),

      // LIST
      body: StreamBuilder<List<Achievement>>(
        stream: _getStream(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snap.data!;

          if (list.isEmpty) {
            return const Center(
              child: Text("No achievements found."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final a = list[i];

              final bool isSharedSimplified =
                  a.sharedSimplified == true; // 🔥 mark shared type

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: a.photoBase64 != null && a.photoBase64!.isNotEmpty
                      ? CircleAvatar(
                    backgroundImage:
                    MemoryImage(base64Decode(a.photoBase64!)),
                  )
                      : const CircleAvatar(
                    child: Icon(Icons.emoji_events),
                  ),

                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),

                      // ⭐ Shared Badge
                      if (isSharedSimplified)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "Shared",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                    ],
                  ),

                  subtitle: Text(
                    "${a.category} • ${a.points} pts\n${a.date.toLocal().toString().split(' ')[0]}",
                  ),

                  isThreeLine: true,

                  // ❌ hide delete for shared achievements
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // VIEW ICON (always visible)
                      IconButton(
                        icon: const Icon(Icons.visibility, color: Colors.blue),
                        tooltip: "View Achievement",
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AchievementDetailScreen(achievement: a),
                            ),
                          );
                        },
                      ),

                      // EDIT ICON (only for main achievements)
                      if (!isSharedSimplified)
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.green),
                          tooltip: "Edit Achievement",
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddEditAchievementScreen(existing: a),
                              ),
                            );
                          },
                        ),

                      // DELETE ICON (only for main achievements)
                      if (!isSharedSimplified)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: "Delete Achievement",
                          onPressed: () => _confirmDelete(a),
                        ),
                    ],
                  ),

                  // 🔥 Shared → detail only. Normal → edit screen.
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => isSharedSimplified
                            ? AchievementDetailScreen(achievement: a)
                            : AddEditAchievementScreen(existing: a),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddEditAchievementScreen(),
            ),
          );
          setState(() {});  // 🔥 refresh list after returning
        },
      ),
    );
  }

  void _confirmDelete(Achievement a) {
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
              await service.deleteAchievement(a);
            },
          ),
        ],
      ),
    );
  }
}
