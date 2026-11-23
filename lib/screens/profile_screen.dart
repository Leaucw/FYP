import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {

  final _auth = AuthService();
  final _firestore = FirebaseFirestore.instance;

  // CONTROLLERS
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _userIdController = TextEditingController();   // ⭐ NEW USER ID FIELD

  DateTime? _birthday;
  String? _gender;
  String? _photoBase64;
  String? _mbti;
  int _totalPoints = 0;   // ⭐ ADD THIS

  bool _isLoading = false;
  bool _notificationsEnabled = true;
  Map<String, dynamic>? _userData;

  // AVAILABLE MBTI TYPES
  final List<String> _mbtiList = [
    "INTJ","INTP","ENTJ","ENTP",
    "INFJ","INFP","ENFJ","ENFP",
    "ISTJ","ISFJ","ESTJ","ESFJ",
    "ISTP","ISFP","ESTP","ESFP",
  ];

  // 4-COLOR MBTI SYSTEM
  final Map<String, Color> _mbtiColors = {
    // PURPLE — Analysts
    "INTJ": Colors.purple,
    "INTP": Colors.purple,
    "ENTJ": Colors.purple,
    "ENTP": Colors.purple,

    // GREEN — Diplomats
    "INFJ": Colors.green,
    "INFP": Colors.green,
    "ENFJ": Colors.green,
    "ENFP": Colors.green,

    // BLUE — Sentinels
    "ISTJ": Colors.blue,
    "ISFJ": Colors.blue,
    "ESTJ": Colors.blue,
    "ESFJ": Colors.blue,

    // YELLOW — Explorers
    "ISTP": Colors.yellow,
    "ISFP": Colors.yellow,
    "ESTP": Colors.yellow,
    "ESFP": Colors.yellow,
  };

  // ANIMATIONS
  late AnimationController _animationController;
  late Animation<Offset> _slideUpAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _slideUpAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  // ============================================================
  // 🔹 LOAD USER DATA FROM FIRESTORE
  // ============================================================
  Future<void> _loadUserData() async {
    final doc = await _firestore.collection('users').doc(widget.user.uid).get();

    if (doc.exists) {
      _userData = doc.data();

      _nameController.text = _userData?['name'] ?? '';
      _phoneController.text = _userData?['phone'] ?? '';
      _userIdController.text = _userData?['userId'] ?? '';

      final g = _userData?['gender'];
      _gender = (g == 'Male' || g == 'Female' || g == 'Other') ? g : null;

      final birthdayTS = _userData?['birthday'];
      if (birthdayTS != null) _birthday = (birthdayTS as Timestamp).toDate();

      _photoBase64 = _userData?['photoBase64'];
      _mbti = _userData?['mbti'];
      if (_mbti != null && !_mbtiList.contains(_mbti)) {
        _mbti = null;
      }
      _totalPoints = _userData?["totalPoints"] ?? 0;   // ⭐ ADD THIS


      setState(() {});
    }
  }

  // ============================================================
  // 🔹 CHECK IF USER ID IS TAKEN
  // ============================================================
  Future<bool> _isUserIdTaken(String userId) async {
    final query = await _firestore
        .collection('users')
        .where('userId', isEqualTo: userId)
        .get();

    // userID exists but belongs to another user → not allowed
    return query.docs.isNotEmpty && query.docs.first.id != widget.user.uid;
  }

  // ============================================================
  // 🔹 SAVE PROFILE WITH USER ID VALIDATION
  // ============================================================
  Future<void> _saveProfile(BuildContext context) async {
    setState(() => _isLoading = true);

    final newUserId = _userIdController.text.trim();

    // USER ID VALIDATION RULES
    if (newUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User ID cannot be empty")),
      );
      setState(() => _isLoading = false);
      return;
    }

    if (newUserId.contains(" ")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User ID cannot contain spaces")),
      );
      setState(() => _isLoading = false);
      return;
    }

    if (await _isUserIdTaken(newUserId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User ID already taken")),
      );
      setState(() => _isLoading = false);
      return;
    }

    // SAVE TO FIRESTORE
    await _firestore.collection('users').doc(widget.user.uid).set({
      "uid": widget.user.uid,
      "email": widget.user.email,
      "name": _nameController.text.trim(),
      "phone": _phoneController.text.trim(),
      "userId": newUserId,               // ⭐ NEW
      "gender": _gender ?? '',
      "birthday":
      _birthday != null ? Timestamp.fromDate(_birthday!) : FieldValue.delete(),
      "photoBase64": _photoBase64 ?? '',
      "mbti": _mbti ?? '',
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    setState(() => _isLoading = false);

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!")),
      );
      _loadUserData();
    }
  }

  // ============================================================
  // 🔹 IMAGE COMPRESSION
  // ============================================================
  Future<File> _compressImage(File file) async {
    try {
      final targetPath = file.path.replaceAll('.jpg', '_compressed.jpg');
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 40,
        minWidth: 200,
        minHeight: 200,
      );
      return result != null ? File(result.path) : file;
    } catch (e) {
      debugPrint('❌ Compression failed: $e');
      return file;
    }
  }

  // ============================================================
  // 🔹 PICK + UPLOAD IMAGE
  // ============================================================
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isLoading = true);

    try {
      File img = File(picked.path);
      img = await _compressImage(img);

      final bytes = await img.readAsBytes();
      final base64 = base64Encode(bytes);

      await _firestore
          .collection('users')
          .doc(widget.user.uid)
          .update({"photoBase64": base64});

      setState(() {
        _photoBase64 = base64;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile photo updated")),
      );
    } catch (e) {
      debugPrint("❌ Upload error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    }

    setState(() => _isLoading = false);
  }

  // ============================================================
  // 🔹 PROFILE COMPLETION CALCULATION
  // ============================================================
  double _calculateCompletion() {
    int filled = 0;
    if (_nameController.text.isNotEmpty) filled++;
    if (_phoneController.text.isNotEmpty) filled++;
    if (_gender != null) filled++;
    if (_birthday != null) filled++;
    if (_photoBase64 != null && _photoBase64!.isNotEmpty) filled++;
    if (_mbti != null) filled++;
    if (_userIdController.text.isNotEmpty) filled++;  // ⭐ USER ID REQUIRED

    return filled / 7;   // now 7 fields
  }

  String _lastUpdatedText() {
    final ts = _userData?['updatedAt'];
    if (ts == null) return "Not updated yet";

    final date = (ts as Timestamp).toDate();
    return "Last updated: ${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  // ============================================================
  // 🔹 BUILD — MAIN UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.background,

        appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
    onPressed: () => Navigator.pop(context),
    ),
    title: const Text(
    "Profile",
    style: TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
    ),
    ),
    centerTitle: true,
    ),

    body: Stack(
    children: [
    SafeArea(
    child: SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
    child: Column(
    children: [
    SlideTransition(
    position: _slideUpAnimation,
    child: FadeTransition(
    opacity: _fadeAnimation,
    child: Container(
    padding: const EdgeInsets.symmetric(
    horizontal: 24, vertical: 32),
    decoration: BoxDecoration(
    color: AppColors.fourth,
    borderRadius: BorderRadius.circular(28),
    boxShadow: [
    BoxShadow(
    color: Colors.black.withOpacity(0.25),
    blurRadius: 20,
    offset: const Offset(0, 8),
    ),
    ],
    ),

    child: Column(
    children: [
    // ============================================================
    // 🔹 PROFILE PHOTO
    // ============================================================
    Stack(
    alignment: Alignment.bottomRight,
    children: [
    Container(
    decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
    BoxShadow(
    color: Colors.black.withOpacity(0.2),
    blurRadius: 10,
    offset: const Offset(0, 4),
    ),
    ],
    ),
    padding: const EdgeInsets.all(6),
    child: ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: (_photoBase64 != null &&
    _photoBase64!.isNotEmpty)
    ? Image.memory(
    base64Decode(_photoBase64!),
    height: 120,
    width: 120,
    fit: BoxFit.cover,
    )
        : Container(
    height: 120,
    width: 120,
    color: AppColors.secondary,
    child: const Icon(
    Icons.person,
    color: Colors.white,
    size: 60,
    ),
    ),
    ),
    ),

    // camera button
    Positioned(
    bottom: 4,
    right: 4,
    child: GestureDetector(
    onTap: _pickAndUploadImage,
    child: Container(
    decoration: const BoxDecoration(
    color: AppColors.highlight,
    shape: BoxShape.circle,
    ),
    padding: const EdgeInsets.all(6),
    child: const Icon(
    Icons.camera_alt,
    size: 18,
    color: AppColors.textButton,
    ),
    ),
    ),
    ),
    ],
    ),

    const SizedBox(height: 20),

    // ============================================================
    // 🔹 NAME
    // ============================================================
    Text(
    _nameController.text.isEmpty
    ? "Your Name"
        : _nameController.text,
    style: const TextStyle(
    color: AppColors.primary,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    ),
    ),

    const SizedBox(height: 6),

    // ============================================================
    // 🔹 EMAIL (Blue + Bold)
    // ============================================================
    Text(
    widget.user.email ?? '',
    style: const TextStyle(
    color: Colors.lightBlueAccent,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    ),
    ),

    const SizedBox(height: 20),

    // 🔹 PROFILE COMPLETION
    _buildProgressBar(),
    const SizedBox(height: 20),

    // ============================================================
    // 🔹 PROFILE FIELDS
    // ============================================================
    _buildProfileItem(
    "User ID",
    _userIdController.text.isNotEmpty
    ? _userIdController.text
        : "Not set"),

    _buildProfileItem(
    "Full Name",
    _nameController.text.isNotEmpty
    ? _nameController.text
        : "Not set"),

    _buildProfileItem(
    "Phone Number",
    _phoneController.text.isNotEmpty
    ? _phoneController.text
        : "Not set"),

    _buildProfileItem("Gender", _gender ?? "Not set"),

    _buildProfileItem(
    "Birthday",
    _birthday != null
    ? "${_birthday!.day}/${_birthday!.month}/${_birthday!.year}"
        : "Not set",
    ),

    _buildProfileItem("Points Available", _totalPoints.toString()),   // ⭐ NEW

    // ============================================================
    // 🔹 MBTI item
    // ============================================================
    _buildMBTIItem(),

    const SizedBox(height: 20),

    // ============================================================
    // 🔹 LAST UPDATED (BLACK)
    // ============================================================
    Text(
    _lastUpdatedText(),
    style: const TextStyle(
    color: Colors.black,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    ),
    ),

    const SizedBox(height: 30),
      // ============================================================
      // 🔹 EDIT PROFILE BUTTON
      // ============================================================
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.highlight,
          minimumSize: const Size(200, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () => _showEditBottomSheet(context),
        child: const Text(
          "Edit Profile",
          style: TextStyle(
            color: AppColors.textButton,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      const SizedBox(height: 20),

      // ============================================================
      // 🔹 NOTIFICATION SWITCH
      // ============================================================
      SwitchListTile(
        title: const Text(
          "Enable Notifications",
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        value: _notificationsEnabled,
        onChanged: (val) =>
            setState(() => _notificationsEnabled = val),
        activeColor: AppColors.highlight,
      ),

      const SizedBox(height: 10),

      // ============================================================
      // 🔹 LOGOUT
      // ============================================================
      TextButton.icon(
        onPressed: () async {
          await _auth.logout();
          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const LoginScreen(),
              ),
            );
          }
        },
        icon: const Icon(
          Icons.logout,
          color: Colors.redAccent,
          size: 20,
        ),
        label: const Text(
          "Logout",
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: 16,
          ),
        ),
      ),
    ],
    ),
    ),
    ),
    ),
    ],
    ),
    ),
    ),

      // ============================================================
      // 🔹 LOADING OVERLAY
      // ============================================================
      if (_isLoading)
        Container(
          color: Colors.black.withOpacity(0.4),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
    ],
    ),
    );
  }

  // ============================================================
  // 🔹 PROFILE COMPLETION BAR (GREEN WHEN 100%)
  // ============================================================
  Widget _buildProgressBar() {
    final progress = _calculateCompletion();
    final bool full = progress == 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Profile Completion: ${(100 * progress).round()}%",
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white24,
            color: full ? Colors.green : AppColors.highlight,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 🔹 GENERIC PROFILE ITEM
  // ============================================================
  Widget _buildProfileItem(String title, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 🔹 MBTI DISPLAY CHIP
  // ============================================================
  Widget _buildMBTIItem() {
    final color = _mbtiColors[_mbti] ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "MBTI",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _mbti ?? "Not set",
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 🔹 EDIT PROFILE BOTTOM SHEET (User ID, MBTI, Gender, Birthday)
  // ============================================================
  void _showEditBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.secondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  "Edit Profile",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),

                const SizedBox(height: 20),

                // ============================================================
                // 🔹 Profile Image Selector
                // ============================================================
                GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: (_photoBase64 != null &&
                        _photoBase64!.isNotEmpty)
                        ? Image.memory(
                      base64Decode(_photoBase64!),
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      height: 100,
                      width: 100,
                      color: AppColors.tertiary,
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ============================================================
                // 🔹 USER ID FIELD (Unique)
                // ============================================================
                _buildTextField("User ID", _userIdController, true),

                // Full Name
                _buildTextField("Full Name", _nameController, true),

                // Phone Number
                _buildTextField("Phone Number", _phoneController, true),

                // ============================================================
                // 🔹 GENDER DROPDOWN
                // ============================================================
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Gender",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  value:
                  (["Male", "Female", "Other"].contains(_gender))
                      ? _gender
                      : null,
                  items: const [
                    DropdownMenuItem(
                        value: "Male", child: Text("Male")),
                    DropdownMenuItem(
                        value: "Female", child: Text("Female")),
                    DropdownMenuItem(
                        value: "Other", child: Text("Other")),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ============================================================
                // 🔹 BIRTHDAY PICKER
                // ============================================================
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Birthday",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                GestureDetector(
                  onTap: () async {
                    final newDate = await showDatePicker(
                      context: context,
                      initialDate:
                      _birthday ?? DateTime(2000, 1, 1),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (newDate != null) {
                      setState(() => _birthday = newDate);
                    }
                  },
                  child: AbsorbPointer(
                    child: TextField(
                      controller: TextEditingController(
                        text: _birthday != null
                            ? "${_birthday!.day}/${_birthday!.month}/${_birthday!.year}"
                            : "",
                      ),
                      decoration: InputDecoration(
                        hintText: "Select your birthday",
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.cake_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ============================================================
                // 🔹 MBTI DROPDOWN
                // ============================================================
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "MBTI",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  value: _mbti,
                  items: _mbtiList
                      .map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  ))
                      .toList(),
                  onChanged: (v) => setState(() => _mbti = v),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // ============================================================
                // 🔹 SAVE BUTTON
                // ============================================================
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _saveProfile(context),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                    color: Colors.white,
                  )
                      : const Text(
                    "Save Changes",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // 🔹 GENERIC TEXT FIELD BUILDER
  // ============================================================
  Widget _buildTextField(
      String label, TextEditingController controller, bool enabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        TextField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: "Enter $label",
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}
