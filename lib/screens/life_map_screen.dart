import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:intl/intl.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'dart:math' as math;

import '../models/map_pin.dart';
import '../models/goal.dart';
import '../models/achievement.dart';
import '../services/map_pin_service.dart';
import '../services/goal_service.dart';
import '../services/achievement_service.dart';
import '../theme/app_colors.dart';
import 'dart:convert'; // Don't forget this for base64Decode

// -----------------------------------------------------------------------------
// THEME & STYLING CONSTANTS
// -----------------------------------------------------------------------------
class MapTheme {
	static const Color accentGold = Color(0xFFFFD700);
	static const Color accentBlue = Color(0xFF448AFF);
	static const Color glassWhite = Color(0xB3FFFFFF); // ~70% opacity white
	static const Color textDark = Color(0xFF2D3436);

	static BoxDecoration glassDecoration = BoxDecoration(
		color: glassWhite,
		borderRadius: BorderRadius.circular(24),
		border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
		boxShadow: [
			BoxShadow(
				color: Colors.black.withOpacity(0.1),
				blurRadius: 20,
				offset: const Offset(0, 10),
			),
		],
	);
}

class LifeMapScreen extends StatefulWidget {
	const LifeMapScreen({super.key});

	@override
	State<LifeMapScreen> createState() => _LifeMapScreenState();
}

class _LifeMapScreenState extends State<LifeMapScreen> with TickerProviderStateMixin {
	final _auth = FirebaseAuth.instance;
	final _service = MapPinService(db: FirebaseFirestore.instance);
	final _goalService = GoalService(db: FirebaseFirestore.instance);
	final _achievementService = AchievementService(db: FirebaseFirestore.instance);

	final MapController _mapController = MapController();

	// UI State
	bool _showSidebar = false;
	_MapItem? _selectedItem;
	_MapItem? _subtitleItem;// The item currently showing in the bottom card
	bool _isPlaying = false;

	List<List<LatLng>> _drawnDashes = [];
	String? _activePlaybackId;

	int _playbackSessionId = 0;

	// Animations
	late AnimationController _sidebarController;
	late AnimationController _cardController;

	// NEW: Dedicated controller for smooth camera movement
	late AnimationController _cameraMoveController;

	// --- NEW: AVATAR STATE ---
	String? _userPhotoBase64;
	LatLng? _currentTravelPos; // Tracks where the avatar is right now
	late AnimationController _avatarShakeController; // Controls the "walking" bounce

	// Generates a list of small segments (dashes) between two points
	// Longer distance = More dashes = Slower, smoother camera panning.
	List<List<LatLng>> _createDynamicDashedLine(LatLng start, LatLng end, double distKm) {
		final List<List<LatLng>> segments = [];

		// BASE CALCULATION:
		// Short trip (<500km): 60 steps
		// Long trip (>5000km): 200 steps
		// This prevents the camera from "flying" too fast across the screen.
		int steps = 60;
		if (distKm > 5000) steps = 200;
		else if (distKm > 2000) steps = 150;
		else if (distKm > 1000) steps = 100;
		else if (distKm > 500) steps = 80;

		for (int i = 0; i < steps; i++) {
			final t1 = i / steps;
			// 0.6 gap ratio creates the dashed effect
			final t2 = (i + 0.6) / steps;

			final lat1 = start.latitude + (end.latitude - start.latitude) * t1;
			final lng1 = start.longitude + (end.longitude - start.longitude) * t1;

			final lat2 = start.latitude + (end.latitude - start.latitude) * t2;
			final lng2 = start.longitude + (end.longitude - start.longitude) * t2;

			segments.add([LatLng(lat1, lng1), LatLng(lat2, lng2)]);
		}
		return segments;
	}

	// 1. Calculate distance between points using latlong2
	double _calculateDistance(LatLng p1, LatLng p2) {
		const Distance distance = Distance();
		return distance.as(LengthUnit.Kilometer, p1, p2);
	}

	// 1. GET CLOSER ZOOM (Updated for visibility)
	// We stay much closer to the ground now so the line is clearly visible.
	// DYNAMIC ZOOM CALCULATOR
	// Uses a logarithmic formula to calculate the exact perfect zoom
	// for any given distance.
	double _getTravelZoom(double distKm) {
		// Protect against 0km distance errors
		if (distKm <= 0) return 15.0;

		// Formula: Start at high zoom (22.5) and subtract based on log10 of distance
		// 50km   -> ~14.0
		// 200km  -> ~11.0
		// 1000km -> ~7.5
		// 5000km -> ~4.0
		double zoom = 22.5 - (5 * (math.log(distKm) / math.log(10)));

		// CLAMPING:
		// Ensure we never zoom in closer than 16 (too pixelated)
		// Ensure we never zoom out further than 3 (world too small)
		return zoom.clamp(3.0, 16.0);
	}

	// 3. Smooth Camera Transition Helper (prevents "snapping")
	// Manually interpolates camera position for soft landings
	Future<void> _smoothCameraMove(LatLng dest, double destZoom, {int durationMs = 1500}) async {
		final startLat = _mapController.camera.center.latitude;
		final startLng = _mapController.camera.center.longitude;
		final startZoom = _mapController.camera.zoom;

		// 60 frames per second
		final int steps = (durationMs / 16).round();

		for (int i = 1; i <= steps; i++) {
			if (!mounted || !_isPlaying) break;

			final t = i / steps;
			// Ease-Out Cubic formula (starts fast, slows down gently)
			final curve = 1 - (1 - t) * (1 - t) * (1 - t);

			final lat = startLat + (dest.latitude - startLat) * curve;
			final lng = startLng + (dest.longitude - startLng) * curve;
			final zoom = startZoom + (destZoom - startZoom) * curve;

			_mapController.move(LatLng(lat, lng), zoom);
			await Future.delayed(const Duration(milliseconds: 16));
		}
	}

	// 1. SMART ZOOM CALCULATOR
	// Calculates the zoom level required to fit two points on screen with padding
	double _calculateFitZoom(LatLng p1, LatLng p2) {
		// Determine the bounds
		final double minLat = math.min(p1.latitude, p2.latitude);
		final double maxLat = math.max(p1.latitude, p2.latitude);
		final double minLng = math.min(p1.longitude, p2.longitude);
		final double maxLng = math.max(p1.longitude, p2.longitude);

		// Calculate rough distance
		final dist = _calculateDistance(p1, p2);

		// Zoom mapping logic (Heuristic)
		if (dist < 10) return 14.0;
		if (dist < 50) return 12.0;
		if (dist < 200) return 9.5;
		if (dist < 1000) return 7.0;
		if (dist < 5000) return 5.0;
		return 3.0;
	}

	// 2. SILKY SMOOTH CAMERA MOVEMENT
	// Uses TickerProvider (AnimationController) to sync with screen refresh rate
	Future<void> _animateCamera(LatLng target, double targetZoom, {int durationMs = 1500}) async {
		final startLat = _mapController.camera.center.latitude;
		final startLng = _mapController.camera.center.longitude;
		final startZoom = _mapController.camera.zoom;

		_cameraMoveController.duration = Duration(milliseconds: durationMs);

		// Create a temporary animation to drive the values
		final Animation<double> curve = CurvedAnimation(
				parent: _cameraMoveController,
				curve: Curves.easeInOutCubic // Slow start, fast middle, slow stop
		);

		_cameraMoveController.reset();
		_cameraMoveController.forward();

		return Future.doWhile(() async {
			if (!mounted || !_isPlaying) return false; // Stop if cancelled

			if (_cameraMoveController.isCompleted) {
				return false;
			}

			// Calculate current frame values
			final t = curve.value;
			final lat = startLat + (target.latitude - startLat) * t;
			final lng = startLng + (target.longitude - startLng) * t;
			final zoom = startZoom + (targetZoom - startZoom) * t;

			_mapController.move(LatLng(lat, lng), zoom);

			// Wait for next frame
			await Future.delayed(const Duration(milliseconds: 16));
			return true;
		});
	}

	@override
	void initState() {
		super.initState();
		_sidebarController = AnimationController(
			vsync: this,
			duration: const Duration(milliseconds: 400),
		);
		_cardController = AnimationController(
			vsync: this,
			duration: const Duration(milliseconds: 400),
		);
		_cameraMoveController = AnimationController(
			vsync: this,
			duration: const Duration(milliseconds: 1000), // Default, will change dynamically
		);

		// 1. Setup Shake Animation (Fast bounce)
		_avatarShakeController = AnimationController(
			vsync: this,
			duration: const Duration(milliseconds: 300), // Speed of the "step"
			lowerBound: 0.0,
			upperBound: 1.0,
		);

		// 2. Fetch User Photo immediately
		_loadUserPhoto();
	}

	Future<void> _loadUserPhoto() async {
		final user = _auth.currentUser;
		if (user != null) {
			final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
			if (doc.exists && mounted) {
				setState(() {
					_userPhotoBase64 = doc.data()?['photoBase64'];
				});
			}
		}
	}

	@override
	void dispose() {
		_avatarShakeController.dispose();
		_sidebarController.dispose();
		_cardController.dispose();
		_cameraMoveController.dispose(); // Don't forget this
		_mapController.dispose();
		super.dispose();
	}

	// ---------------------------------------------------------------------------
	// CINEMATIC PLAYBACK
	// ---------------------------------------------------------------------------
	Future<void> _playMemories(String userId) async {
		// 1. GENERATE NEW SESSION ID
		// This immediately invalidates any running previous animations
		final int currentSession = DateTime.now().millisecondsSinceEpoch;

		setState(() {
			_playbackSessionId = currentSession; // Set the active session
			_isPlaying = true;
			_showSidebar = false;
			_sidebarController.reverse();
			_selectedItem = null;
			_subtitleItem = null;
			_drawnDashes = [];
			_currentTravelPos = null; // Reset avatar
		});

		// Helper to check if we should stop
		bool shouldStop() {
			return !mounted || !_isPlaying || _playbackSessionId != currentSession;
		}

		// Stop any existing camera movement immediately
		_cameraMoveController.stop();

		final goalsSnap = await _goalService.streamGoals(userId).first;
		final achievementsSnap = await _achievementService.stream(userId).first;
		final items = _prepareItems(goalsSnap, achievementsSnap);
		items.sort((a, b) => a.date.compareTo(b.date));

		if (items.isEmpty) {
			if (mounted) setState(() => _isPlaying = false);
			return;
		}

		// --- START ANIMATION ---

		// Move to start
		if (shouldStop()) return;
		setState(() => _currentTravelPos = LatLng(items.first.latitude, items.first.longitude));
		await _animateCamera(
				LatLng(items.first.latitude, items.first.longitude),
				12.0,
				durationMs: 1000
		);

		for (int i = 0; i < items.length; i++) {
			if (shouldStop()) return; // Check Session ID

			final currentItem = items[i];
			final currentLoc = LatLng(currentItem.latitude, currentItem.longitude);

			// --- TRAVEL PHASE ---
			if (i > 0) {
				final prevItem = items[i - 1];
				final prevLoc = LatLng(prevItem.latitude, prevItem.longitude);
				final dist = _calculateDistance(prevLoc, currentLoc);

				// Zoom out
				final travelZoom = _calculateFitZoom(prevLoc, currentLoc);

				// Generate path
				final dashes = _createDynamicDashedLine(prevLoc, currentLoc, dist);

				// START WALKING ANIMATION
				_avatarShakeController.repeat(reverse: true);

				// Draw Loop
				int skipFrame = 0;
				for (final segment in dashes) {
					if (shouldStop()) return; // Check Session ID inside the fast loop

					setState(() {
						_drawnDashes.add(segment);
						// UPDATE AVATAR POSITION HERE
						_currentTravelPos = segment[1];
					});

					if (skipFrame % 2 == 0) {
						_mapController.move(segment[1], travelZoom);
					}
					skipFrame++;

					await Future.delayed(const Duration(milliseconds: 10));

					// STOP WALKING ANIMATION
					_avatarShakeController.stop();
					_avatarShakeController.reset();
				}
			}

			// --- ARRIVAL PHASE ---
			// Ensure avatar is exactly at destination
			setState(() => _currentTravelPos = currentLoc);
			if (shouldStop()) return;

			// Zoom In
			await _animateCamera(currentLoc, 15.5, durationMs: 1200);

			// Show Subtitle
			if (shouldStop()) return;
			setState(() => _subtitleItem = currentItem);

			// Pause for reading
			int pauseSeconds = currentItem.description.length > 50 ? 5 : 3;
			// We break the delay into small chunks so we can stop faster
			for(int s=0; s<pauseSeconds*2; s++) {
				if (shouldStop()) return;
				await Future.delayed(const Duration(milliseconds: 500));
			}

			// Hide Subtitle
			if (mounted && _playbackSessionId == currentSession) {
				setState(() => _subtitleItem = null);
			}

			await Future.delayed(const Duration(milliseconds: 500));
		}

		// --- FINISH ---
		if (mounted && _playbackSessionId == currentSession) {
			setState(() {
				_isPlaying = false;
				// Sidebar does NOT open automatically anymore
				_activePlaybackId = null;
			});
		}
	}

	void _selectItem(_MapItem? item) {
		setState(() => _selectedItem = item);
		if (item != null) {
			_cardController.forward();
		} else {
			_cardController.reverse();
		}
	}

	List<_MapItem> _prepareItems(List<Goal> goals, List<Achievement> achs) {
		return [
			...goals
					.where((g) => g.status == GoalStatus.completed && g.latitude != null && g.longitude != null)
					.map((g) => _MapItem.fromGoal(g)),
			...achs
					.where((a) => a.latitude != null && a.longitude != null)
					.map((a) => _MapItem.fromAchievement(a)),
		];
	}

	// ---------------------------------------------------------------------------
	// BUILD
	// ---------------------------------------------------------------------------
	@override
	Widget build(BuildContext context) {
		final user = _auth.currentUser;
		if (user == null) return const Scaffold(body: Center(child: Text("Please sign in")));

		return Scaffold(
			// Extend body behind app bar for full-screen map feel
			extendBodyBehindAppBar: true,
				appBar: AppBar(
					elevation: 0,
					backgroundColor: AppColors.primary, // unified color
					foregroundColor: Colors.white,
					centerTitle: true,

					// Leading BackButton stays
					leading: const BackButton(color: Colors.white),

					// Title with optional icon (if you want one)
					title: Row(
						mainAxisSize: MainAxisSize.min,
						children: const [
							Icon(
								Icons.map_rounded, // optional, small icon left of title
								color: Colors.white,
								size: 22,
							),
							SizedBox(width: 8),
							Text(
								'World Map',
								style: TextStyle(
									color: Colors.white,
									fontWeight: FontWeight.w600,
									fontSize: 20,
									letterSpacing: 1.2,
								),
							),
						],
					),

					// Action buttons (same as before)
					actions: [
						_AppBarButton(
							icon: _isPlaying ? Icons.stop_circle_outlined : Icons.play_circle_outline,
							color: _isPlaying ? Colors.redAccent : Colors.white,
							tooltip: _isPlaying ? "Stop" : "Play Journey",
							onPressed: () {
								if (_isPlaying) {
									// STOPPING
									setState(() {
										_isPlaying = false;
										_playbackSessionId = 0; // Invalidates the current session immediately
										_subtitleItem = null;
									});
									_cameraMoveController.stop(); // Stops the camera physics
								} else {
									// PLAYING
									_playMemories(user.uid);
								}
							},
						),
						_AppBarButton(
							icon: _showSidebar ? Icons.map_outlined : Icons.view_sidebar_outlined,
							color: Colors.white,
							tooltip: "Toggle List",
							onPressed: () {
								setState(() {
									_showSidebar = !_showSidebar;
									_showSidebar ? _sidebarController.forward() : _sidebarController.reverse();
								});
							},
						),
						const SizedBox(width: 8),
					],

					// Faint background icon for consistency
					flexibleSpace: Stack(
						children: [
							Positioned(
								right: -20,
								bottom: -20,
								child: Icon(
									Icons.analytics, // map-related faint icon
									size: 150,
									color: Colors.white.withOpacity(0.05),
								),
							),
						],
					),
				),


				body: StreamBuilder<List<MapPin>>(
				stream: _service.stream(user.uid),
				builder: (_, pinSnap) {
					if (!pinSnap.hasData) return const Center(child: CircularProgressIndicator());
					final pins = pinSnap.data!;

					return StreamBuilder<List<Goal>>(
						stream: _goalService.streamGoals(user.uid),
						builder: (_, goalSnap) {
							if (!goalSnap.hasData) return const SizedBox();
							final goals = goalSnap.data!;

							return StreamBuilder<List<Achievement>>(
								stream: _achievementService.stream(user.uid),
								builder: (_, achSnap) {
									if (!achSnap.hasData) return const SizedBox();
									final achievements = achSnap.data!;

									final items = _prepareItems(goals, achievements);
									// Sort by date desc for the list
									final listItems = List<_MapItem>.from(items)..sort((a, b) => b.date.compareTo(a.date));

									return Stack(
										children: [
											// 1) THE MAP
											Positioned.fill(
												child: FlutterMap(
													mapController: _mapController,
													options: MapOptions(
														initialCenter: const LatLng(20, 0), // World view
														initialZoom: 2.5,
														onTap: (_, __) => _selectItem(null), // Close card on map tap
													),
													children: [
														// Beautiful clean tiles
														TileLayer(
															urlTemplate: "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png",
															subdomains: const ['a', 'b', 'c', 'd'],
														),

														PolylineLayer(
															polylines: _drawnDashes.map((dash) {
																return Polyline(
																	points: dash,
																	strokeWidth: 4.0,
																	color: Colors.redAccent, // Red looks classic for travel maps
																	strokeCap: StrokeCap.round, // Rounds the ends of the dashes
																	borderColor: Colors.white, // Optional: White border to pop against dark maps
																	borderStrokeWidth: 1.0,
																);
															}).toList(),
														),
														// --- NEW: TRAVELING AVATAR LAYER ---

// -----------------------------------

														// --- NEW CLUSTER LAYER ---
														MarkerClusterLayerWidget(
															options: MarkerClusterLayerOptions(
																maxClusterRadius: 45,
																size: const Size(40, 40),
																alignment: Alignment.center,
																padding: const EdgeInsets.all(50),
																maxZoom: 15, // Stop clustering after this zoom level
																markers: _buildMarkers(items, pins), // Your existing marker logic

																// This handles items at the exact same coordinate
																spiderfyCircleRadius: 80,

																// THE DESIGN OF THE CLUSTER CIRCLE (The bubble with the number)
																builder: (context, markers) {
																	return Container(
																		decoration: BoxDecoration(
																			color: MapTheme.accentBlue,
																			shape: BoxShape.circle,
																			border: Border.all(color: Colors.white, width: 3),
																			boxShadow: [
																				BoxShadow(
																					color: Colors.black.withOpacity(0.2),
																					blurRadius: 10,
																					offset: const Offset(0, 5),
																				)
																			],
																		),
																		child: Center(
																			child: Text(
																				markers.length.toString(),
																				style: const TextStyle(
																					color: Colors.white,
																					fontWeight: FontWeight.bold,
																					fontSize: 14,
																				),
																			),
																		),
																	);
																},
															),
														),
														if (_isPlaying && _currentTravelPos != null)
															MarkerLayer(
																markers: [
																	Marker(
																		point: _currentTravelPos!,
																		width: 60, // Slightly larger than pins
																		height: 60,
																		alignment: Alignment.topCenter, // Align bottom of marker to the line
																		child: _TravelingAvatar(
																			photoBase64: _userPhotoBase64,
																			shakeAnimation: _avatarShakeController,
																		),
																	),
																],
															),
													],
												),
											),

											// 2) FLOATING INFO CARD (Bottom Center) OR CINEMATIC SUBTITLE
											// This is the key switch for your requirement
											Positioned(
												bottom: _isPlaying ? 50 : 40,
												left: 20,
												right: 20,
												child: _isPlaying
														? _buildCinematicSubtitle() // NEW WIDGET
														: _buildFloatingCard(),     // OLD WIDGET
											),

											// 3) GLASS SIDEBAR (Right Side)
											_buildAnimatedSidebar(listItems),
										],
									);
								},
							);
						},
					);
				},
			),
		);
	}

	Widget _buildCinematicSubtitle() {
		return AnimatedSwitcher(
			duration: const Duration(milliseconds: 600),
			transitionBuilder: (Widget child, Animation<double> animation) {
				return FadeTransition(
					opacity: animation,
					child: SlideTransition(
						position: Tween<Offset>(
							begin: const Offset(0.0, 0.2),
							end: Offset.zero,
						).animate(animation),
						child: child,
					),
				);
			},
			child: _subtitleItem == null
					? const SizedBox.shrink()
					: Center( // Center aligns the box horizontally
				child: Container(
					key: ValueKey(_subtitleItem!.title),
					// 1. LIMIT WIDTH: constrain width to 90% of screen to prevent edge touching
					constraints: BoxConstraints(
						maxWidth: MediaQuery.of(context).size.width * 0.9,
					),
					padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
					decoration: BoxDecoration(
						color: Colors.black.withOpacity(0.8), // Slightly darker for better contrast
						borderRadius: BorderRadius.circular(24),
						boxShadow: [
							BoxShadow(
								color: Colors.black.withOpacity(0.3),
								blurRadius: 20,
								offset: const Offset(0, 10),
							)
						],
						border: Border.all(color: Colors.white.withOpacity(0.15)),
					),
					child: Column(
						mainAxisSize: MainAxisSize.min, // Shrinks vertically to fit content
						children: [
							// --- TITLE ---
							Text(
								_subtitleItem!.title.toUpperCase(),
								style: const TextStyle(
									color: Colors.white,
									fontSize: 16,
									fontWeight: FontWeight.bold,
									letterSpacing: 1.5,
								),
								textAlign: TextAlign.center,
								maxLines: 1, // Prevent multiline title taking too much space
								overflow: TextOverflow.ellipsis, // Add "..." if too long
							),
							const SizedBox(height: 6),

							// --- DATE & LOCATION ---
							// 2. PREVENT ROW OVERFLOW: Use Flexible
							Row(
								mainAxisSize: MainAxisSize.min, // Keep row compact
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									Icon(
											_subtitleItem!.isAchievement ? Icons.emoji_events : Icons.place,
											color: MapTheme.accentGold,
											size: 14
									),
									const SizedBox(width: 6),
									Flexible( // <--- THIS FIXES THE OVERFLOW
										child: Text(
											"${DateFormat.yMMMd().format(_subtitleItem!.date)} • ${_subtitleItem!.locationName ?? 'Unknown'}",
											style: TextStyle(
												color: Colors.white.withOpacity(0.8),
												fontSize: 12,
											),
											overflow: TextOverflow.ellipsis,
											maxLines: 1,
										),
									),
								],
							),

							// --- DESCRIPTION ---
							if (_subtitleItem!.description.isNotEmpty) ...[
								const SizedBox(height: 10),
								Container(height: 1, width: 40, color: Colors.white24),
								const SizedBox(height: 10),
								Text(
									_subtitleItem!.description,
									style: TextStyle(
										color: Colors.white.withOpacity(0.9),
										fontSize: 13,
										fontStyle: FontStyle.italic,
										height: 1.3,
									),
									textAlign: TextAlign.center,
									maxLines: 2, // Limit description height
									overflow: TextOverflow.ellipsis,
								),
							]
						],
					),
				),
			),
		);
	}

	// ---------------------------------------------------------------------------
	// MARKERS
	// ---------------------------------------------------------------------------
	List<Marker> _buildMarkers(List<_MapItem> items, List<MapPin> pins) {
		final markers = <Marker>[];

		for (final item in items) {
			markers.add(
				Marker(
					point: LatLng(item.latitude, item.longitude),
					width: 60,
					height: 60,
					child: GestureDetector(
						onTap: () => _selectItem(item),
						child: _AnimatedMarker(
							color: item.isAchievement ? MapTheme.accentGold : MapTheme.accentBlue,
							icon: item.isAchievement ? Icons.emoji_events : Icons.flag,
						),
					),
				),
			);
		}
		return markers;
	}

	// ---------------------------------------------------------------------------
	// WIDGETS: SIDEBAR & CARD
	// ---------------------------------------------------------------------------

	Widget _buildAnimatedSidebar(List<_MapItem> items) {
		return AnimatedBuilder(
			animation: _sidebarController,
			builder: (_, child) {
				// Slide in from right
				final slide = Tween<Offset>(begin: const Offset(1.2, 0.0), end: Offset.zero)
						.animate(CurvedAnimation(parent: _sidebarController, curve: Curves.easeOutQuart));

				return FractionalTranslation(
					translation: slide.value,
					child: Align(
						alignment: Alignment.centerRight,
						child: Container(
							width: 300,
							margin: const EdgeInsets.only(top: 100, bottom: 20, right: 20),
							child: ClipRRect(
								borderRadius: BorderRadius.circular(24),
								child: BackdropFilter(
									filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
									child: Container(
										decoration: MapTheme.glassDecoration,
										child: Column(
											children: [
												Container(
													padding: const EdgeInsets.all(20),
													decoration: BoxDecoration(
														border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05))),
													),
													child: Row(
														children: [
															const Icon(Icons.history_edu, color: MapTheme.textDark),
															const SizedBox(width: 10),
															const Text("Journal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
															const Spacer(),
															Text("${items.length} spots", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
														],
													),
												),
												Expanded(
													child: ListView.builder(
														padding: const EdgeInsets.symmetric(vertical: 10),
														itemCount: items.length,
														itemBuilder: (_, i) {
															final item = items[i];
															return ListTile(
																leading: Container(
																	padding: const EdgeInsets.all(8),
																	decoration: BoxDecoration(
																		color: (item.isAchievement ? MapTheme.accentGold : MapTheme.accentBlue).withOpacity(0.2),
																		shape: BoxShape.circle,
																	),
																	child: Icon(
																		item.isAchievement ? Icons.emoji_events_rounded : Icons.flag_rounded,
																		size: 18,
																		color: item.isAchievement ? Colors.orange[800] : Colors.blue[800],
																	),
																),
																title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
																subtitle: Text(DateFormat.yMMMd().format(item.date), style: const TextStyle(fontSize: 12)),
																onTap: () {
																	_mapController.move(LatLng(item.latitude, item.longitude), 13);
																	_selectItem(item);
																},
															);
														},
													),
												),
											],
										),
									),
								),
							),
						),
					),
				);
			},
		);
	}

	Widget _buildFloatingCard() {
		return AnimatedBuilder(
			animation: _cardController,
			builder: (context, child) {
				final offset = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero)
						.animate(CurvedAnimation(parent: _cardController, curve: Curves.elasticOut)); // Bouncy effect

				// If no item selected, don't render contents to save resources (opacity 0)
				if (_selectedItem == null) return const SizedBox.shrink();

				return SlideTransition(
					position: offset,
					child: Center(
						child: Container(
							width: double.infinity,
							constraints: const BoxConstraints(maxWidth: 500), // Max width for tablet
							child: ClipRRect(
								borderRadius: BorderRadius.circular(24),
								child: BackdropFilter(
									filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
									child: Container(
										padding: const EdgeInsets.all(24),
										decoration: BoxDecoration(
											color: Colors.white.withOpacity(0.9),
											borderRadius: BorderRadius.circular(24),
											boxShadow: [
												BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))
											],
										),
										child: Row(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												// Icon Column
												Column(
													children: [
														Container(
															padding: const EdgeInsets.all(12),
															decoration: BoxDecoration(
																color: _selectedItem!.isAchievement
																		? MapTheme.accentGold.withOpacity(0.2)
																		: MapTheme.accentBlue.withOpacity(0.2),
																shape: BoxShape.circle,
															),
															child: Icon(
																_selectedItem!.isAchievement ? Icons.emoji_events_rounded : Icons.flag_rounded,
																color: _selectedItem!.isAchievement ? Colors.orange[800] : Colors.blue[800],
																size: 28,
															),
														),
													],
												),
												const SizedBox(width: 20),
												// Text Column
												Expanded(
													child: Column(
														crossAxisAlignment: CrossAxisAlignment.start,
														mainAxisSize: MainAxisSize.min,
														children: [
															Text(
																_selectedItem!.title,
																style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: MapTheme.textDark),
															),
															const SizedBox(height: 4),
															Row(
																children: [
																	const Icon(Icons.location_on, size: 12, color: Colors.grey),
																	const SizedBox(width: 4),
																	Expanded(
																		child: Text(
																			_selectedItem!.locationName ?? "Unknown Location",
																			style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
																			overflow: TextOverflow.ellipsis,
																		),
																	),
																	Text(
																		DateFormat.yMMMd().format(_selectedItem!.date),
																		style: const TextStyle(color: Colors.grey, fontSize: 12),
																	),
																],
															),
															if (_selectedItem!.description.isNotEmpty) ...[
																const SizedBox(height: 12),
																Text(
																	_selectedItem!.description,
																	style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.4),
																	maxLines: 3,
																	overflow: TextOverflow.ellipsis,
																),
															]
														],
													),
												),
												// Close Button
												IconButton(
													icon: const Icon(Icons.close, color: Colors.grey),
													onPressed: () => _selectItem(null),
												)

											],
										),
									),
								),
							),
						),
					),
				);
			},
		);
	}
}

// -----------------------------------------------------------------------------
// CUSTOM MARKER WIDGET (THE "BUBBLE")
// -----------------------------------------------------------------------------
class _AnimatedMarker extends StatelessWidget {
	final Color color;
	final IconData icon;

	const _AnimatedMarker({required this.color, required this.icon});

	@override
	Widget build(BuildContext context) {
		// Simple bounce or pulse effect could be added here with flutter_animate
		// For now, we create a beautiful static composition
		return Column(
			mainAxisSize: MainAxisSize.min,
			children: [
				Container(
					width: 44,
					height: 44,
					decoration: BoxDecoration(
						color: Colors.white,
						shape: BoxShape.circle,
						border: Border.all(color: Colors.white, width: 3),
						boxShadow: [
							BoxShadow(color: color.withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 6)),
							BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
						],
					),
					child: Container(
						decoration: BoxDecoration(
							color: color,
							shape: BoxShape.circle,
						),
						child: Icon(icon, color: Colors.white, size: 22),
					),
				),
				// Little triangle arrow at bottom
				ClipPath(
					clipper: _TriangleClipper(),
					child: Container(
						width: 10, height: 8,
						color: Colors.white,
					),
				)
			],
		);
	}
}

class _TriangleClipper extends CustomClipper<Path> {
	@override
	Path getClip(Size size) {
		// 1. Create the path object
		final path = Path();

		// 2. Call methods ON the path object
		path.moveTo(0, 0);
		path.lineTo(size.width / 2, size.height);
		path.lineTo(size.width, 0);
		path.close();

		return path;
	}

	@override
	bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// -----------------------------------------------------------------------------
// HELPER: APP BAR BUTTON
// -----------------------------------------------------------------------------
class _AppBarButton extends StatelessWidget {
	final IconData icon;
	final VoidCallback onPressed;
	final Color color;
	final String tooltip;

	const _AppBarButton({required this.icon, required this.onPressed, required this.color, required this.tooltip});

	@override
	Widget build(BuildContext context) {
		return Container(
			margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
			decoration: BoxDecoration(
				color: Colors.black.withOpacity(0.3),
				shape: BoxShape.circle,
			),
			child: IconButton(
				icon: Icon(icon, color: color, size: 22),
				tooltip: tooltip,
				onPressed: onPressed,
			),
		);
	}
}

// -----------------------------------------------------------------------------
// DATA MODEL (Consolidated)
// -----------------------------------------------------------------------------
class _MapItem {
	final String title;
	final String description;
	final String category;
	final DateTime date;
	final double latitude;
	final double longitude;
	final bool isAchievement;
	final String? locationName;

	_MapItem({
		required this.title,
		required this.description,
		required this.category,
		required this.date,
		required this.latitude,
		required this.longitude,
		required this.isAchievement,
		required this.locationName,
	});

	factory _MapItem.fromGoal(Goal g) {
		return _MapItem(
			title: g.title,
			description: g.description,
			category: g.category,
			date: g.completedAt ?? g.endDate ?? g.createdAt,
			latitude: g.latitude!,
			longitude: g.longitude!,
			isAchievement: false,
			locationName: g.locationName,
		);
	}

	factory _MapItem.fromAchievement(Achievement a) {
		return _MapItem(
			title: a.title,
			description: a.description,
			category: a.category,
			date: a.date,
			latitude: a.latitude!,
			longitude: a.longitude!,
			isAchievement: true,
			locationName: a.locationName,
		);
	}
}


class _TravelingAvatar extends StatelessWidget {
	final String? photoBase64;
	final Animation<double> shakeAnimation;

	const _TravelingAvatar({
		required this.photoBase64,
		required this.shakeAnimation,
	});

	@override
	Widget build(BuildContext context) {
		return AnimatedBuilder(
			animation: shakeAnimation,
			builder: (context, child) {
				// Create a bounce effect:
				// Translate Y moves up and down
				// Rotate gives a slight "waddle"
				return Transform.translate(
					offset: Offset(0, -10 * shakeAnimation.value), // Bobs up by 10 pixels
					child: Transform.rotate(
						angle: 0.1 * (shakeAnimation.value - 0.5), // Slight tilt left/right
						child: child,
					),
				);
			},
			child: Container(
				decoration: BoxDecoration(
					color: Colors.white,
					shape: BoxShape.circle,
					border: Border.all(color: MapTheme.accentGold, width: 3),
					boxShadow: [
						BoxShadow(
							color: Colors.black.withOpacity(0.3),
							blurRadius: 10,
							offset: const Offset(0, 5),
						)
					],
				),
				child: CircleAvatar(
					backgroundColor: Colors.grey[200],
					backgroundImage: (photoBase64 != null && photoBase64!.isNotEmpty)
							? MemoryImage(base64Decode(photoBase64!))
							: null,
					child: (photoBase64 == null || photoBase64!.isEmpty)
							? const Icon(Icons.person, color: Colors.grey)
							: null,
				),
			),
		);
	}
}