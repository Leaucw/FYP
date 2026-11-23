import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_colors.dart'; // Assuming you have this from the previous file

class LocationResult {
	final double latitude;
	final double longitude;
	final String? name;
	LocationResult({required this.latitude, required this.longitude, this.name});
}

class LocationPickerScreen extends StatefulWidget {
	final double? initialLat;
	final double? initialLng;
	final String? initialName;
	const LocationPickerScreen({super.key, this.initialLat, this.initialLng, this.initialName});

	@override
	State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
	final MapController _mapController = MapController(); // Controller to move the map
	LatLng? _selected;
	final _nameCtrl = TextEditingController();
	final _searchCtrl = TextEditingController();
	bool _searching = false;
	bool _isResolvingAddress = false;

	@override
	void initState() {
		super.initState();
		if (widget.initialLat != null && widget.initialLng != null) {
			_selected = LatLng(widget.initialLat!, widget.initialLng!);
		}
		_nameCtrl.text = widget.initialName ?? '';
	}

	@override
	void dispose() {
		_nameCtrl.dispose();
		_searchCtrl.dispose();
		_mapController.dispose();
		super.dispose();
	}

	// --- Logic ---

	Future<void> _searchPlace() async {
		final q = _searchCtrl.text.trim();
		if (q.isEmpty) return;

		setState(() => _searching = true);
		FocusManager.instance.primaryFocus?.unfocus(); // Hide keyboard

		try {
			final uri = Uri.parse('https://nominatim.openstreetmap.org/search?q=$q&format=json&limit=1');
			final res = await http.get(uri, headers: {'User-Agent': 'fyp/1.0'});

			if (res.statusCode == 200) {
				final List data = json.decode(res.body) as List;
				if (data.isNotEmpty) {
					final item = data.first as Map<String, dynamic>;
					final lat = double.tryParse(item['lat']?.toString() ?? '');
					final lon = double.tryParse(item['lon']?.toString() ?? '');

					if (lat != null && lon != null) {
						final newPoint = LatLng(lat, lon);
						setState(() {
							_selected = newPoint;
							_nameCtrl.text = item['display_name']?.toString().split(',').first ?? _nameCtrl.text;
						});
						// Animate map to search result
						_mapController.move(newPoint, 15.0);
					}
				} else {
					ScaffoldMessenger.of(context).showSnackBar(
						const SnackBar(content: Text("Location not found")),
					);
				}
			}
		} catch (e) {
			debugPrint("Search error: $e");
		} finally {
			setState(() => _searching = false);
		}
	}

	Future<void> _reverseGeocode(LatLng point) async {
		setState(() {
			_isResolvingAddress = true;
			_nameCtrl.clear(); // Clear while loading to show it's fresh
		});

		try {
			final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json');
			final res = await http.get(uri, headers: {'User-Agent': 'fyp/1.0'});

			if (res.statusCode == 200) {
				final data = json.decode(res.body) as Map<String, dynamic>;
				// Try to get a friendly name (Road name, or Amenity, falling back to display_name)
				final address = data['address'] as Map<String, dynamic>?;
				String display = "";

				if (address != null) {
					display = address['road'] ?? address['building'] ?? address['amenity'] ?? data['display_name']?.toString().split(',').first;
				} else {
					display = data['display_name']?.toString().split(',').first ?? "";
				}

				if (mounted) {
					setState(() => _nameCtrl.text = display ?? "Unknown Location");
				}
			}
		} catch (_) {
			// Silent fail or set to Coordinates
			if(mounted) setState(() => _nameCtrl.text = "Selected Location");
		} finally {
			if(mounted) setState(() => _isResolvingAddress = false);
		}
	}

	void _onConfirm() {
		if (_selected == null) return;
		final result = LocationResult(
			latitude: _selected!.latitude,
			longitude: _selected!.longitude,
			name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
		);
		Navigator.pop(context, result);
	}

	// --- UI Components ---

	Widget _buildSearchBar() {
		return SafeArea(
			child: Container(
				margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
				decoration: BoxDecoration(
					color: Colors.white,
					borderRadius: BorderRadius.circular(30),
					boxShadow: [
						BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
					],
				),
				child: TextField(
					controller: _searchCtrl,
					textInputAction: TextInputAction.search,
					onSubmitted: (_) => _searchPlace(),
					decoration: InputDecoration(
						hintText: 'Search city or place...',
						hintStyle: TextStyle(color: Colors.grey.shade400),
						border: InputBorder.none,
						contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
						prefixIcon: IconButton(
							icon: const Icon(Icons.arrow_back, color: Colors.black87),
							onPressed: () => Navigator.pop(context),
						),
						suffixIcon: IconButton(
							onPressed: _searching ? null : _searchPlace,
							icon: _searching
									? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
									: const Icon(Icons.search, color: AppColors.primary),
						),
					),
				),
			),
		);
	}

	Widget _buildBottomPanel() {
		if (_selected == null) return const SizedBox.shrink();

		return Align(
			alignment: Alignment.bottomCenter,
			child: Container(
				margin: const EdgeInsets.all(16),
				padding: const EdgeInsets.all(20),
				decoration: BoxDecoration(
					color: Colors.white,
					borderRadius: BorderRadius.circular(24),
					boxShadow: [
						BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 5)),
					],
				),
				child: Column(
					mainAxisSize: MainAxisSize.min,
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						// Handle bar for visual affordance
						Center(
							child: Container(
								width: 40, height: 4,
								margin: const EdgeInsets.only(bottom: 16),
								decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
							),
						),

						// Coordinates label
						Row(
							children: [
								Icon(Icons.my_location, size: 16, color: Colors.grey.shade500),
								const SizedBox(width: 6),
								Text(
									"${_selected!.latitude.toStringAsFixed(5)}, ${_selected!.longitude.toStringAsFixed(5)}",
									style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500),
								),
							],
						),
						const SizedBox(height: 12),

						// Location Name Input
						TextField(
							controller: _nameCtrl,
							decoration: InputDecoration(
								labelText: "Location Name",
								floatingLabelBehavior: FloatingLabelBehavior.always,
								filled: true,
								fillColor: Colors.grey.shade50,
								border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
								suffixIcon: _isResolvingAddress
										? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2)))
										: const Icon(Icons.edit, size: 18, color: Colors.grey),
							),
						),
						const SizedBox(height: 16),

						// Confirm Button
						SizedBox(
							width: double.infinity,
							child: ElevatedButton(
								onPressed: _onConfirm,
								style: ElevatedButton.styleFrom(
									backgroundColor: AppColors.primary,
									foregroundColor: Colors.white,
									padding: const EdgeInsets.symmetric(vertical: 16),
									elevation: 0,
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
								),
								child: const Text("Confirm Location", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
							),
						),
					],
				),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		// Default center (can be set to user's current location in a real app)
		final mapCenter = _selected ?? const LatLng(3.1390, 101.6869);

		return Scaffold(
			body: Stack(
				children: [
					// 1. The Map Layer
					FlutterMap(
						mapController: _mapController, // Attach controller
						options: MapOptions(
							initialCenter: mapCenter,
							initialZoom: _selected != null ? 15 : 11,
							onTap: (tapPosition, point) async {
								setState(() => _selected = point);
								await _reverseGeocode(point);
							},
						),
						children: [
							TileLayer(
								urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
								userAgentPackageName: 'com.example.fyp',
							),
							if (_selected != null)
								MarkerLayer(
									markers: [
										Marker(
											point: _selected!,
											width: 50,
											height: 50,
											// Animated bouncing pin effect can be added here, but static is fine for now
											child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 48),
										),
									],
								),
						],
					),

					// 2. Floating Search Bar (Top)
					Align(
						alignment: Alignment.topCenter,
						child: _buildSearchBar(),
					),

					// 3. Details Panel (Bottom)
					// We wrap in SafeAreaBottom to ensure it doesn't conflict with home gestures on iOS
					SafeArea(
						child: _buildBottomPanel(),
					),
				],
			),
		);
	}
}