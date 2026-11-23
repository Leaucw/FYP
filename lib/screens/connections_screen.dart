import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../theme/app_colors.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;

  List<DocumentSnapshot> people = [];
  String filter = "All";

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    final snap = await firestore
        .collection("users")
        .doc(user!.uid)
        .collection("relationships")
        .orderBy("name")
        .get();

    setState(() => people = snap.docs);
  }

  // =============================
  // IMAGE PICKER + COMPRESSOR
  // =============================
  Future<String?> _pickImageBase64() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;

    File img = File(file.path);
    final target = file.path.replaceAll(".jpg", "_compressed.jpg");

    final compressed = await FlutterImageCompress.compressAndGetFile(
      img.path,
      target,
      quality: 40,
      minWidth: 200,
      minHeight: 200,
    );

    final realFile = compressed != null ? File(compressed.path) : img;
    final bytes = await realFile.readAsBytes();
    return base64Encode(bytes);
  }

  // =============================
  // ADD PERSON FLOW
  // =============================
  void _showAddPersonFlow() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Is this person an app user?"),
        content: const Text("Choose how you want to add this person."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stepEnterUserId();
            },
            child: const Text("Yes, App User"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openFinalForm(appUserData: null);
            },
            child: const Text("No, Not App User"),
          ),
        ],
      ),
    );
  }

  // =============================
  // STEP 1: ENTER USER ID
  // =============================
  void _stepEnterUserId() {
    final idController = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text("Enter User ID"),
          content: TextField(
            controller: idController,
            decoration: InputDecoration(
              labelText: "User ID",
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Continue"),
              onPressed: () async {
                final entered = idController.text.trim();

                if (entered.isEmpty) {
                  setState(() => error = "Please enter a User ID");
                  return;
                }

                final result = await firestore
                    .collection("users")
                    .where("userId", isEqualTo: entered)
                    .limit(1)
                    .get();

                if (result.docs.isEmpty) {
                  setState(() => error = "User ID not found");
                  return;
                }

                if (result.docs.first.id == user!.uid) {
                  setState(() => error = "You cannot add yourself.");
                  return;
                }

                final data = result.docs.first.data();

                Navigator.pop(context);

                _openFinalForm(
                  appUserData: {
                    "uid": result.docs.first.id,
                    "userId": data["userId"],
                    "name": data["name"],
                    "photoBase64": data["photoBase64"],
                    "mbti": data["mbti"],
                  },
                );
              },
            ),
          ],
        );
      }),
    );
  }

  // =============================
  // STEP 2: FINAL FORM
  // =============================
  void _openFinalForm({Map<String, dynamic>? appUserData}) {
    final nameCtrl =
    TextEditingController(text: appUserData != null ? appUserData["name"] : "");
    final List<String> relationshipTypes = [
      "Family",
      "Friend",
      "Partner",
      "Colleague",
      "Classmate",
      "Neighbor",
      "Other",
    ];

    final List<String> closenessLevels = [
      "Very Close",
      "Close",
      "Normal",
      "Distant",
    ];

    String? relationshipType;
    String? closeness;
    String? mbti = appUserData != null ? appUserData["mbti"] : null;
    String? photoBase64 = appUserData != null ? appUserData["photoBase64"] : null;
    DateTime? firstMet;

    bool isAppUser = appUserData != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text("Add Person"),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: isAppUser
                        ? null
                        : () async {
                      final img = await _pickImageBase64();
                      if (img != null) {
                        setState(() => photoBase64 = img);
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: (photoBase64 != null && photoBase64!.isNotEmpty)
                          ? Image.memory(
                        base64Decode(photoBase64!),
                        height: 110,
                        width: 110,
                        fit: BoxFit.cover,
                      )
                          : Container(
                        height: 110,
                        width: 110,
                        color: Colors.grey.shade300,
                        alignment: Alignment.center,
                        child: const Icon(Icons.person, size: 60),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: "Name"),
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Relationship Type"),
                    items: relationshipTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    value: relationshipType,
                    onChanged: (v) => setState(() => relationshipType = v),
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Closeness Level"),
                    items: closenessLevels
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    value: closeness,
                    onChanged: (v) => setState(() => closeness = v),
                  ),

                  const SizedBox(height: 16),

                  // MBTI
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("MBTI"),
                      const SizedBox(height: 4),

                      if (isAppUser)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            mbti ?? "Unknown",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: "Select MBTI"),
                          items: [
                            "INTJ","INTP","ENTJ","ENTP",
                            "INFJ","INFP","ENFJ","ENFP",
                            "ISTJ","ISFJ","ESTJ","ESFJ",
                            "ISTP","ISFP","ESTP","ESFP",
                          ]
                              .map((m) =>
                              DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          value: mbti,
                          onChanged: (v) => setState(() => mbti = v),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(1990),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => firstMet = date);
                      }
                    },
                    child: TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: firstMet == null
                            ? "First Met Date"
                            : "${firstMet!.day}/${firstMet!.month}/${firstMet!.year}",
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Add"),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty ||
                    relationshipType == null ||
                    closeness == null) return;

                await firestore
                    .collection("users")
                    .doc(user!.uid)
                    .collection("relationships")
                    .add({
                  "name": nameCtrl.text.trim(),
                  "relationshipType": relationshipType,
                  "closeness": closeness,
                  "mbti": mbti ?? "",
                  "photoBase64": photoBase64 ?? "",
                  "firstMet":
                  firstMet != null ? Timestamp.fromDate(firstMet!) : null,

                  // ⭐ FIXED FIELDS (required by Achievement Sharing)
                  "isAppUser": isAppUser,
                  "appUserUid": appUserData?["uid"],

                  "createdAt": Timestamp.now(),
                });

                Navigator.pop(context);
                await _loadPeople();
              },
            ),
          ],
        );
      }),
    );
  }

  // =============================
  // EDIT PERSON
  // =============================
  void _editPerson(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final nameCtrl = TextEditingController(text: data["name"]);
    String? relationshipType = data["relationshipType"];
    String? closeness = data["closeness"];
    String? mbti = data["mbti"];
    String? photoBase64 = data["photoBase64"];
    DateTime? firstMet =
    data["firstMet"] != null ? (data["firstMet"] as Timestamp).toDate() : null;

    final isAppUser = data["isAppUser"] == true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text("Edit Person"),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: isAppUser
                        ? null
                        : () async {
                      final img = await _pickImageBase64();
                      if (img != null) setState(() => photoBase64 = img);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: (photoBase64 != null && photoBase64!.isNotEmpty)
                          ? Image.memory(
                        base64Decode(photoBase64!),
                        height: 110,
                        width: 110,
                        fit: BoxFit.cover,
                      )
                          : Container(
                        height: 110,
                        width: 110,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.person, size: 60),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: "Name"),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Relationship Type"),
                    items: [
                      "Family",
                      "Friend",
                      "Partner",
                      "Colleague",
                      "Classmate",
                      "Neighbor",
                      "Other"
                    ]
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    value: relationshipType,
                    onChanged: (v) => setState(() => relationshipType = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Closeness Level"),
                    items: [
                      "Very Close",
                      "Close",
                      "Normal",
                      "Distant"
                    ]
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    value: closeness,
                    onChanged: (v) => setState(() => closeness = v),
                  ),
                  const SizedBox(height: 12),

                  isAppUser
                      ? Container(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      mbti ?? "",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  )
                      : DropdownButtonFormField<String>(
                    value: mbti,
                    decoration:
                    const InputDecoration(labelText: "Select MBTI"),
                    items: [
                      "INTJ","INTP","ENTJ","ENTP",
                      "INFJ","INFP","ENFJ","ENFP",
                      "ISTJ","ISFJ","ESTJ","ESFJ",
                      "ISTP","ISFP","ESTP","ESFP",
                    ]
                        .map((m) =>
                        DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setState(() => mbti = v),
                  ),

                  const SizedBox(height: 12),

                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: firstMet ?? DateTime.now(),
                        firstDate: DateTime(1990),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) setState(() => firstMet = date);
                    },
                    child: TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: firstMet == null
                            ? "First Met Date"
                            : "${firstMet!.day}/${firstMet!.month}/${firstMet!.year}",
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          actions: [
            TextButton(
              child: const Text("Delete"),
              onPressed: () async {
                await doc.reference.delete();
                Navigator.pop(context);
                _loadPeople();
              },
            ),
            ElevatedButton(
              child: const Text("Save"),
              onPressed: () async {
                await doc.reference.update({
                  "name": nameCtrl.text.trim(),
                  "relationshipType": relationshipType,
                  "closeness": closeness,
                  "mbti": mbti,
                  "photoBase64": photoBase64 ?? "",
                  "firstMet": firstMet != null
                      ? Timestamp.fromDate(firstMet!)
                      : null,
                  // ⭐ Keep the UID of app user (VERY IMPORTANT)
                  "appUserUid": data["appUserUid"],
                });
                Navigator.pop(context);
                _loadPeople();
              },
            ),
          ],
        );
      }),
    );
  }

  // =============================
  // MAIN UI
  // =============================
  @override
  Widget build(BuildContext context) {
    final filters = [
      "All",
      "Family",
      "Friend",
      "Partner",
      "Colleague",
      "Classmate",
      "Neighbor",
      "Other",
    ];

    final filteredList = filter == "All"
        ? people
        : people.where((p) => p["relationshipType"] == filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Relationships & People"),
        backgroundColor: AppColors.primary,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.highlight,
        onPressed: _showAddPersonFlow,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: filters.map((f) {
                final selected = f == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: selected,
                    selectedColor: AppColors.highlight,
                    onSelected: (_) => setState(() => filter = f),
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: filteredList.isEmpty
                ? const Center(child: Text("No people added yet."))
                : ListView.builder(
              itemCount: filteredList.length,
              itemBuilder: (context, i) {
                final doc = filteredList[i];
                final data = doc.data() as Map<String, dynamic>;
                final photo = data["photoBase64"];
                final mbti = data["mbti"];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (photo != null && photo.isNotEmpty)
                        ? MemoryImage(base64Decode(photo))
                        : null,
                    child: (photo == null || photo.isEmpty)
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(data["name"] ?? ""),
                  subtitle: Text(
                      "${data["relationshipType"]} • ${data["closeness"]}"),
                  trailing: Text(mbti ?? ""),
                  onTap: () => _editPerson(doc),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
