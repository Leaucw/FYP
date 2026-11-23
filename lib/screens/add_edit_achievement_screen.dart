import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/achievement.dart';
import '../services/achievement_service.dart';
import '../utils/achievement_config.dart';
import 'location_picker_screen.dart'; // ⭐ ADD THIS

class AddEditAchievementScreen extends StatefulWidget {
  final Achievement? existing;

  const AddEditAchievementScreen({super.key, this.existing});

  @override
  State<AddEditAchievementScreen> createState() =>
      _AddEditAchievementScreenState();
}

class _AddEditAchievementScreenState extends State<AddEditAchievementScreen> {
  final _formKey = GlobalKey<FormState>();
  final AchievementService _service = AchievementService();

  final User? user = FirebaseAuth.instance.currentUser;

  late TextEditingController titleCtrl;
  late TextEditingController descCtrl;

  String? currentPhotoBase64;
  late AchievementCategory category;
  DateTime selectedDate = DateTime.now();

  // 🔹 Friendship fields
  String? selectedPersonId;
  String? selectedPersonName;
  String? selectedPersonAppUid;

  // 🔹 LOCATION FIELDS ⭐ ADDED
  String? selectedLocationName;
  double? selectedLatitude;
  double? selectedLongitude;

  List<Map<String, dynamic>> peopleList = [];

  @override
  void initState() {
    super.initState();

    titleCtrl = TextEditingController(text: widget.existing?.title ?? "");
    descCtrl = TextEditingController(text: widget.existing?.description ?? "");

    if (widget.existing != null) {
      category = AchievementConfig.categoryFromString(widget.existing!.category);
      selectedDate = widget.existing!.date;
      currentPhotoBase64 = widget.existing!.photoBase64;

      selectedPersonId = widget.existing!.completedWithId;
      selectedPersonName = widget.existing!.completedWithName;
      selectedPersonAppUid = widget.existing!.completedWithAppUid;

      // ⭐ LOAD EXISTING LOCATION
      selectedLocationName = widget.existing!.locationName;
      selectedLatitude = widget.existing!.latitude;
      selectedLongitude = widget.existing!.longitude;

    } else {
      category = AchievementCategory.personalGrowth;
    }

    _loadPeople();
  }

  Future<void> _loadPeople() async {
    if (user == null) return;

    final query = await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .collection("relationships")
        .get();

    peopleList = query.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;

      final String appUserUid = (data["appUserUid"] ?? "").toString();
      final bool isAppUser = appUserUid.isNotEmpty;

      return {
        "id": doc.id,
        "name": (data["name"] ?? "").toString(),
        "isAppUser": isAppUser,
        "appUid": appUserUid,
      };
    }).toList();

    setState(() {});
  }

  Future<void> _pickImage() async {
    final img = await _service.pickImageBase64();
    if (img != null) {
      setState(() => currentPhotoBase64 = img);
    }
  }

  void _removePhoto() {
    setState(() => currentPhotoBase64 = null);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Edit Achievement" : "Add Achievement"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

              // ------------------ IMAGE ------------------
              Center(
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: currentPhotoBase64 != null
                          ? Image.memory(
                        base64Decode(currentPhotoBase64!),
                        height: 160,
                        width: 160,
                        fit: BoxFit.cover,
                      )
                          : Container(
                        height: 160,
                        width: 160,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.camera_alt, size: 50),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo),
                          label: const Text("Choose Photo"),
                        ),
                        const SizedBox(width: 12),

                        if (currentPhotoBase64 != null)
                          ElevatedButton.icon(
                            onPressed: _removePhoto,
                            icon: const Icon(Icons.delete),
                            label: const Text("Remove"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ------------------ TITLE ------------------
              TextFormField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: "Title"),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? "Required" : null,
              ),

              const SizedBox(height: 12),

              // ------------------ DESCRIPTION ------------------
              TextFormField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Description"),
              ),

              const SizedBox(height: 12),

              // ------------------ CATEGORY ------------------
              DropdownButtonFormField<AchievementCategory>(
                value: category,
                decoration: const InputDecoration(labelText: "Category"),
                items: AchievementCategory.values
                    .map(
                      (c) => DropdownMenuItem(
                    value: c,
                    child: Text(AchievementConfig.categoryToString(c)),
                  ),
                )
                    .toList(),
                onChanged: (value) {
                  setState(() => category = value!);
                },
              ),

              const SizedBox(height: 12),

              // ------------------ COMPLETED WITH ------------------
              DropdownButtonFormField<String>(
                value: peopleList.any((p) => p["id"] == selectedPersonId)
                    ? selectedPersonId
                    : "none",
                decoration: const InputDecoration(labelText: "Completed With (Optional)"),
                items: [
                  const DropdownMenuItem(
                    value: "none",
                    child: Text("None"),
                  ),
                  ...peopleList.map((p) {
                    return DropdownMenuItem<String>(
                      value: p["id"] as String,
                      child: Text(p["name"] as String),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    if (value == "none") {
                      selectedPersonId = null;
                      selectedPersonName = null;
                      selectedPersonAppUid = null;
                    } else {
                      selectedPersonId = value;

                      final person =
                      peopleList.firstWhere((p) => p["id"] == value);

                      selectedPersonName = person["name"] as String;
                      selectedPersonAppUid =
                      person["isAppUser"] == true ? person["appUid"] as String : null;
                    }
                  });
                },
              ),

              const SizedBox(height: 12),

              // ------------------ LOCATION PICKER ⭐ ADDED ------------------
              ListTile(
                tileColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.location_on, color: Colors.red),
                title: Text(
                  selectedLocationName ?? "Select Location",
                  style: const TextStyle(fontSize: 16),
                ),
                subtitle: (selectedLatitude != null && selectedLongitude != null)
                    ? Text(
                  "${selectedLatitude!.toStringAsFixed(5)}, "
                      "${selectedLongitude!.toStringAsFixed(5)}",
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                )
                    : const Text("No location selected"),
                trailing: const Icon(Icons.chevron_right),

                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LocationPickerScreen(
                        initialLat: selectedLatitude,
                        initialLng: selectedLongitude,
                        initialName: selectedLocationName,
                      ),
                    ),
                  );

                  if (result != null) {
                    setState(() {
                      selectedLatitude = result.latitude;
                      selectedLongitude = result.longitude;
                      selectedLocationName = result.name;
                    });
                  }
                },
              ),

              const SizedBox(height: 12),

              // ------------------ DATE PICKER ------------------
              ElevatedButton(
                child: Text(
                  "Pick Date: ${selectedDate.toIso8601String().split('T').first}",
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDate: selectedDate,
                  );
                  if (picked != null) {
                    setState(() => selectedDate = picked);
                  }
                },
              ),

              const SizedBox(height: 25),

              // ------------------ SAVE BUTTON ------------------
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;

                  if (isEdit) {
                    await _service.updateAchievement(
                      widget.existing!.id,
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      category: category,
                      date: selectedDate,
                      photoBase64: currentPhotoBase64,
                      completedWithId: selectedPersonId,
                      completedWithName: selectedPersonName,
                      completedWithAppUid: selectedPersonAppUid,
                      locationName: selectedLocationName,
                      latitude: selectedLatitude,
                      longitude: selectedLongitude,
                    );
                  } else {
                    await _service.addAchievement(
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      category: category,
                      date: selectedDate,
                      photoBase64: currentPhotoBase64,
                      completedWithId: selectedPersonId,
                      completedWithName: selectedPersonName,
                      completedWithAppUid: selectedPersonAppUid,
                      locationName: selectedLocationName,
                      latitude: selectedLatitude,
                      longitude: selectedLongitude,
                    );
                  }

                  if (mounted) Navigator.pop(context);
                },
                child: Text(isEdit ? "Save Changes" : "Add Achievement"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
