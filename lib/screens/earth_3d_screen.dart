import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart'; // The 3D package
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/goal.dart';
import '../models/achievement.dart';
import '../services/goal_service.dart';
import '../services/achievement_service.dart';

class Earth3DScreen extends StatefulWidget {
  const Earth3DScreen({super.key});

  @override
  State<Earth3DScreen> createState() => _Earth3DScreenState();
}

class _Earth3DScreenState extends State<Earth3DScreen> {
  final _auth = FirebaseAuth.instance;
  final _goalService = GoalService(db: FirebaseFirestore.instance);
  final _achievementService = AchievementService(db: FirebaseFirestore.instance);

  late FlutterEarthGlobeController _controller;
  List<Point> _points = [];
  bool _isLoading = true;

  // 1. ADD ZOOM STATE VARIABLES
  double _globeRadius = 120.0; // Initial size
  double _minRadius = 50.0;    // Zoomed out (far away)
  double _maxRadius = 350.0;   // Zoomed in (close up)
  double _baseScaleFactor = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = FlutterEarthGlobeController(
      rotationSpeed: 0.05, // Auto-rotate slowly
      surface: AssetImage('assets/images/earth_texture.jpg'),
      background: Image.network(
        'https://upload.wikimedia.org/wikipedia/commons/8/80/Hyades.jpg', // Starry background
      ).image,
    );

    _loadData();
  }

  Future<void> _loadData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final goals = await _goalService.streamGoals(user.uid).first;
    final achievements = await _achievementService.stream(user.uid).first;

    final newPoints = <Point>[];

    // 1. Process Goals
    for (var g in goals) {
      if (g.status == GoalStatus.completed && g.latitude != null && g.longitude != null) {
        newPoints.add(_create3DMarker(
          id: g.id,
          lat: g.latitude!,
          lng: g.longitude!,
          title: g.title,
          isAchievement: false,
        ));
      }
    }

    // 2. Process Achievements
    for (var a in achievements) {
      if (a.latitude != null && a.longitude != null) {
        newPoints.add(_create3DMarker(
          id: a.id,
          lat: a.latitude!,
          lng: a.longitude!,
          title: a.title,
          isAchievement: true,
        ));
      }
    }

    setState(() {
      _points = newPoints;
      for (var point in _points) {
        _controller.addPoint(point);
      }
      _isLoading = false;
    });
  }

  // Helper to build the Marker
  Point _create3DMarker({
    required String id,
    required double lat,
    required double lng,
    required String title,
    required bool isAchievement,
  }) {
    return Point(
      id: id,
      coordinates: GlobeCoordinates(lat, lng),
      label: title,
      isLabelVisible: true,
      // FIX: Use PointStyle instead of TextStyle
      style: PointStyle(
        color: isAchievement ? const Color(0xFFFFD700) : const Color(0xFF448AFF),
        size: isAchievement ? 10 : 6, // Make achievements slightly larger
      ),
      // Note: 'widget', 'child', and 'onTap' are removed as they are not supported here
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // The 3D Earth with Gesture Detection
          Positioned.fill(
            child: GestureDetector(
              // 2. HANDLE PINCH TO ZOOM
              onScaleStart: (details) {
                _baseScaleFactor = _globeRadius;
              },
              onScaleUpdate: (details) {
                setState(() {
                  // Calculate new radius based on pinch scale
                  double newRadius = _baseScaleFactor * details.scale;
                  // Clamp ensures we don't zoom in too far or invert the globe
                  _globeRadius = newRadius.clamp(_minRadius, _maxRadius);
                });
              },
              child: SafeArea(
                child: FlutterEarthGlobe(
                  controller: _controller,
                  radius: _globeRadius, // 3. USE DYNAMIC RADIUS
                ),
              ),
            ),
          ),

          // Back Button
          Positioned(
            top: 50,
            left: 20,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
              child: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Title
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "GLOBAL VIEW",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          // 4. ADD A ZOOM SLIDER (Optional but helpful)
          Positioned(
            right: 20,
            top: 150,
            bottom: 150,
            child: RotatedBox(
              quarterTurns: 3, // Vertical Slider
              child: Slider(
                value: _globeRadius,
                min: _minRadius,
                max: _maxRadius,
                activeColor: Colors.white.withOpacity(0.5),
                inactiveColor: Colors.white.withOpacity(0.1),
                onChanged: (value) {
                  setState(() {
                    _globeRadius = value;
                  });
                },
              ),
            ),
          ),

          // Loading Indicator
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}

// Simple pulsing marker for the 3D view
class _AnimatedPulseMarker extends StatefulWidget {
  final Color color;
  final IconData icon;
  const _AnimatedPulseMarker({required this.color, required this.icon});

  @override
  State<_AnimatedPulseMarker> createState() => _AnimatedPulseMarkerState();
}

class _AnimatedPulseMarkerState extends State<_AnimatedPulseMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: widget.color,
                blurRadius: 5 + (_controller.value * 10), // Pulsing glow
                spreadRadius: 1 + (_controller.value * 3),
              )
            ],
          ),
          child: Icon(widget.icon, color: Colors.white, size: 16),
        );
      },
    );
  }
}