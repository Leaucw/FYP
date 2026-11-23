import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // You might need intl for formatting
import 'package:uuid/uuid.dart';
import '../models/goal.dart';
import '../services/goal_service.dart';
import '../theme/app_colors.dart';
import 'location_picker_screen.dart';

const _goalCategories = [
	'Health & Wellness',
	'Career & Finance',
	'Education & Learning',
	'Relationships',
	'Personal Growth',
];

class _SubGoalDraft {
	final String id;
	final TextEditingController controller;
	bool completed;

	_SubGoalDraft({
		required this.id,
		required String initialTitle,
		required this.completed,
	}) : controller = TextEditingController(text: initialTitle);
}

class GoalUpsertScreen extends StatefulWidget {
	final Goal? existing;
	final Map<String, dynamic>? adoptData; // <--- ADD THIS

	const GoalUpsertScreen.create({super.key})
			: existing = null, adoptData = null; // <--- UPDATE THIS

	const GoalUpsertScreen.edit({super.key, required this.existing})
			: adoptData = null; // <--- UPDATE THIS

	// --- ADD THIS NEW CONSTRUCTOR ---
	const GoalUpsertScreen.adopt({super.key, required this.adoptData})
			: existing = null;

	@override
	State<GoalUpsertScreen> createState() => _GoalUpsertScreenState();
}

class _GoalUpsertScreenState extends State<GoalUpsertScreen> {
	final _formKey = GlobalKey<FormState>();
	final _titleCtrl = TextEditingController();
	final _descCtrl = TextEditingController();
	final _locationCtrl = TextEditingController();
	final List<String> _people = [];

	DateTime? _startDate;
	DateTime? _endDate;
	String? _selectedCategory = _goalCategories.first;

	double? _lat;
	double? _lng;

	final List<_SubGoalDraft> _subGoals = [];
	final _auth = FirebaseAuth.instance;
	final _service = GoalService(db: FirebaseFirestore.instance);

	@override
	void initState() {
		super.initState();
		final g = widget.existing;
		final ad = widget.adoptData; // <--- NEW

		// 1. EDIT MODE
		if (g != null) {
			_titleCtrl.text = g.title;
			_descCtrl.text = g.description;
			_people.addAll(g.associatedPeople);
			_locationCtrl.text = g.locationName ?? '';
			_selectedCategory = g.category;
			_startDate = g.startDate;
			_endDate = g.endDate;
			_lat = g.latitude;
			_lng = g.longitude;

			for (final s in g.subGoals) {
				_subGoals.add(_SubGoalDraft(
					id: s.id,
					initialTitle: s.title,
					completed: s.completed,
				));
			}
		}
		// 2. ADOPT MODE (NEW LOGIC)
		else if (ad != null) {
			_titleCtrl.text = ad['title'] ?? '';
			_descCtrl.text = ad['description'] ?? '';

			// Safety check for category
			if (_goalCategories.contains(ad['category'])) {
				_selectedCategory = ad['category'];
			}

			// Import Subgoals (Generate NEW IDs and reset completed status)
			final List rawSubs = ad['subGoals'] ?? [];
			for (var s in rawSubs) {
				_subGoals.add(_SubGoalDraft(
					id: const Uuid().v4(), // NEW ID
					initialTitle: s['title'] ?? '',
					completed: false,      // Reset to false
				));
			}
		}

		// Default empty subgoal if nothing added
		if (_subGoals.isEmpty) {
			_subGoals.add(_SubGoalDraft(
				id: const Uuid().v4(),
				initialTitle: "",
				completed: false,
			));
		}
	}

	@override
	void dispose() {
		_titleCtrl.dispose();
		_descCtrl.dispose();
		_locationCtrl.dispose();
		for (final s in _subGoals) {
			s.controller.dispose();
		}
		super.dispose();
	}

	// --- Logic Methods (Same as before) ---

	Future<void> _pickDate({required bool start}) async {
		final now = DateTime.now();
		final picked = await showDatePicker(
			context: context,
			initialDate: start ? (_startDate ?? now) : (_endDate ?? now),
			firstDate: DateTime(2000),
			lastDate: DateTime(2100),
			builder: (context, child) {
				return Theme(
					data: Theme.of(context).copyWith(
						colorScheme: ColorScheme.light(primary: AppColors.primary),
					),
					child: child!,
				);
			},
		);
		if (picked != null) {
			setState(() {
				if (start) _startDate = picked;
				else _endDate = picked;
			});
		}
	}

	Future<void> _pickLocation() async {
		final result = await Navigator.push<LocationResult>(
			context,
			MaterialPageRoute(
				builder: (_) => LocationPickerScreen(
					initialLat: _lat,
					initialLng: _lng,
					initialName: _locationCtrl.text.isEmpty ? null : _locationCtrl.text,
				),
			),
		);

		if (result != null) {
			setState(() {
				_lat = result.latitude;
				_lng = result.longitude;
				_locationCtrl.text = result.name ?? '';
			});
		}
	}

	Future<void> _addPerson() async {
		final c = TextEditingController();
		final added = await showDialog<String>(
			context: context,
			builder: (_) => AlertDialog(
				title: const Text("Add Person"),
				content: TextField(
					controller: c,
					autofocus: true,
					decoration: const InputDecoration(
						hintText: "Name",
						filled: true,
					),
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
					ElevatedButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text("Add")),
				],
			),
		);

		if (added != null && added.isNotEmpty) {
			setState(() => _people.add(added));
		}
	}

	void _addSubGoalField() {
		setState(() {
			_subGoals.add(_SubGoalDraft(
				id: const Uuid().v4(),
				initialTitle: "",
				completed: false,
			));
		});
	}

	void _openPeoplePicker() {
		final user = _auth.currentUser;
		if (user == null) return;

		// We create a local set of selected names based on the current list
		// so we can modify it inside the modal without affecting the main screen immediately
		final Set<String> tempSelected = Set.from(_people);
		String searchQuery = "";

		showModalBottomSheet(
			context: context,
			isScrollControlled: true, // Allows full height
			backgroundColor: Colors.transparent,
			builder: (ctx) => DraggableScrollableSheet(
				initialChildSize: 0.8,
				minChildSize: 0.5,
				maxChildSize: 0.95,
				builder: (_, scrollController) {
					return Container(
						decoration: const BoxDecoration(
							color: Colors.white,
							borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
						),
						padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
						child: StatefulBuilder(
							builder: (ctx, setModalState) {
								return Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										// Header
										Row(
											mainAxisAlignment: MainAxisAlignment.spaceBetween,
											children: [
												const Text(
													"Tag People",
													style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
												),
												TextButton(
													onPressed: () {
														// Save changes to the main state
														setState(() {
															_people.clear();
															_people.addAll(tempSelected);
														});
														Navigator.pop(context);
													},
													child: const Text("Done", style: TextStyle(fontWeight: FontWeight.bold)),
												)
											],
										),
										const SizedBox(height: 16),

										// Search Bar
										TextField(
											onChanged: (val) => setModalState(() => searchQuery = val.toLowerCase()),
											decoration: InputDecoration(
												hintText: "Search connections...",
												prefixIcon: const Icon(Icons.search, color: Colors.grey),
												filled: true,
												fillColor: Colors.grey.shade100,
												border: OutlineInputBorder(
													borderRadius: BorderRadius.circular(12),
													borderSide: BorderSide.none,
												),
												contentPadding: const EdgeInsets.symmetric(vertical: 0),
											),
										),
										const SizedBox(height: 16),

										// List from Firestore
										Expanded(
											child: StreamBuilder<QuerySnapshot>(
												stream: FirebaseFirestore.instance
														.collection('users')
														.doc(user.uid)
														.collection('relationships')
														.orderBy('name')
														.snapshots(),
												builder: (context, snapshot) {
													if (!snapshot.hasData) {
														return const Center(child: CircularProgressIndicator());
													}

													final docs = snapshot.data!.docs;

													// Filter locally based on search query
													final filteredDocs = docs.where((doc) {
														final data = doc.data() as Map<String, dynamic>;
														final name = (data['name'] ?? "").toString().toLowerCase();
														return name.contains(searchQuery);
													}).toList();

													if (filteredDocs.isEmpty) {
														return Center(
															child: Text(
																"No connections found.",
																style: TextStyle(color: Colors.grey.shade400),
															),
														);
													}

													return ListView.separated(
														controller: scrollController,
														itemCount: filteredDocs.length,
														separatorBuilder: (_, __) => const Divider(height: 1),
														itemBuilder: (ctx, index) {
															final data = filteredDocs[index].data() as Map<String, dynamic>;
															final name = data['name'] ?? "Unknown";
															final relation = data['relationshipType'] ?? "Connection";
															// Assuming you save photoBase64 in relationships, logic to decode:
															// final photo = data['photoBase64'];

															final isSelected = tempSelected.contains(name);

															return ListTile(
																contentPadding: EdgeInsets.zero,
																leading: CircleAvatar(
																	backgroundColor: AppColors.primary.withOpacity(0.1),
																	child: Text(
																		name.isNotEmpty ? name[0].toUpperCase() : "?",
																		style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
																	),
																	// Use backgroundImage if you have the photo available
																),
																title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
																subtitle: Text(relation, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
																trailing: Checkbox(
																	value: isSelected,
																	activeColor: AppColors.primary,
																	shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
																	onChanged: (val) {
																		setModalState(() {
																			if (val == true) {
																				tempSelected.add(name);
																			} else {
																				tempSelected.remove(name);
																			}
																		});
																	},
																),
																onTap: () {
																	setModalState(() {
																		if (isSelected) {
																			tempSelected.remove(name);
																		} else {
																			tempSelected.add(name);
																		}
																	});
																},
															);
														},
													);
												},
											),
										),
									],
								);
							},
						),
					);
				},
			),
		);
	}

	void _removeSubGoalField(_SubGoalDraft draft) {
		if (_subGoals.length == 1) return;
		setState(() {
			draft.controller.dispose();
			_subGoals.remove(draft);
		});
	}

	Future<void> _save() async {
		if (!_formKey.currentState!.validate()) return;
		final user = _auth.currentUser;
		if (user == null) return;

		final now = DateTime.now();
		final subGoals = _subGoals
				.where((s) => s.controller.text.trim().isNotEmpty)
				.map((s) => SubGoal(
			id: s.id,
			title: s.controller.text.trim(),
			completed: s.completed,
			dueDate: null,
		))
				.toList();

		final goal = Goal(
			id: widget.existing?.id ?? '',
			userId: user.uid,
			title: _titleCtrl.text.trim(),
			description: _descCtrl.text.trim(),
			category: _selectedCategory ?? _goalCategories.first,
			startDate: _startDate,
			endDate: _endDate,
			completedAt: widget.existing?.completedAt,
			locationName: _locationCtrl.text.isNotEmpty ? _locationCtrl.text : null,
			latitude: _lat,
			longitude: _lng,
			associatedPeople: _people,
			status: widget.existing?.status ?? GoalStatus.inProgress,
			subGoals: subGoals,
			convertedToAchievement: widget.existing?.convertedToAchievement ?? false,
			createdAt: widget.existing?.createdAt ?? now,
			updatedAt: now,
		);

		if (widget.existing == null) {
			await _service.createGoal(user.uid, goal);
		} else {
			await _service.updateGoal(user.uid, goal);
		}

		if (mounted) Navigator.pop(context);
	}

	// ----------------------------------------------------------
	// 🎨 UI COMPONENTS (DESIGN UPGRADE)
	// ----------------------------------------------------------

	InputDecoration _inputDecoration(String label, {IconData? icon}) {
		return InputDecoration(
			labelText: label,
			prefixIcon: icon != null ? Icon(icon, color: AppColors.primary.withOpacity(0.7)) : null,
			filled: true,
			fillColor: Colors.white,
			contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
			enabledBorder: OutlineInputBorder(
				borderRadius: BorderRadius.circular(16),
				borderSide: BorderSide(color: Colors.grey.shade200),
			),
			focusedBorder: OutlineInputBorder(
				borderRadius: BorderRadius.circular(16),
				borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
			),
			errorBorder: OutlineInputBorder(
				borderRadius: BorderRadius.circular(16),
				borderSide: const BorderSide(color: Colors.redAccent),
			),
		);
	}

	Widget _buildSectionTitle(String title) {
		return Padding(
			padding: const EdgeInsets.only(bottom: 12, left: 4),
			child: Text(
				title.toUpperCase(),
				style: TextStyle(
					fontSize: 13,
					fontWeight: FontWeight.bold,
					letterSpacing: 1.2,
					color: Colors.grey.shade600,
				),
			),
		);
	}

	Widget _buildDateTile({
		required String label,
		required DateTime? date,
		required VoidCallback onTap,
	}) {
		return Expanded(
			child: InkWell(
				onTap: onTap,
				borderRadius: BorderRadius.circular(16),
				child: Container(
					padding: const EdgeInsets.all(16),
					decoration: BoxDecoration(
						color: Colors.white,
						borderRadius: BorderRadius.circular(16),
						border: Border.all(color: Colors.grey.shade200),
						boxShadow: [
							BoxShadow(color: Colors.grey.shade100, blurRadius: 5, offset: const Offset(0, 3))
						],
					),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Row(
								children: [
									Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
									const SizedBox(width: 6),
									Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
								],
							),
							const SizedBox(height: 8),
							Text(
								date == null ? "--/--" : "${date.day}/${date.month}/${date.year}",
								style: TextStyle(
									fontSize: 16,
									fontWeight: FontWeight.bold,
									color: date == null ? Colors.grey.shade400 : AppColors.textPrimary,
								),
							),
						],
					),
				),
			),
		);
	}

	Widget _buildCategorySelector() {
		return SingleChildScrollView(
			scrollDirection: Axis.horizontal,
			physics: const BouncingScrollPhysics(),
			child: Row(
				children: _goalCategories.map((category) {
					final isSelected = _selectedCategory == category;
					return Padding(
						padding: const EdgeInsets.only(right: 8),
						child: ChoiceChip(
							label: Text(category),
							selected: isSelected,
							selectedColor: AppColors.primary,
							labelStyle: TextStyle(
								color: isSelected ? Colors.white : AppColors.textPrimary,
								fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
							),
							backgroundColor: Colors.white,
							shape: RoundedRectangleBorder(
								borderRadius: BorderRadius.circular(20),
								side: BorderSide(
									color: isSelected ? Colors.transparent : Colors.grey.shade300,
								),
							),
							onSelected: (selected) {
								if (selected) setState(() => _selectedCategory = category);
							},
						),
					);
				}).toList(),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		// Using a slight off-white background for contrast against white cards
		return Scaffold(
			backgroundColor: const Color(0xFFF8F9FC),
			appBar: AppBar(
				elevation: 0,
				backgroundColor: AppColors.primary,  // SAME COLOR AS OTHER SCREENS
				foregroundColor: Colors.white,       // Makes back button white
				centerTitle: true,

				// Title + Icon (white just like other screens)
				title: Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						Icon(
							widget.existing == null
									? Icons.flag_rounded
									: Icons.edit_rounded,
							color: Colors.white,            // MATCH STYLE
							size: 22,
						),
						const SizedBox(width: 8),
						// Inside AppBar title:
						Text(
							// Check adoptData first, then existing
							widget.adoptData != null
									? "Adopt Goal"
									: (widget.existing == null ? "New Goal" : "Edit Goal"),
							style: const TextStyle(
								fontSize: 20,
								fontWeight: FontWeight.w600,
								color: Colors.white,
							),
						),
					],
				),

				// Delete button
				actions: [
					if (widget.existing != null)
						IconButton(
							icon: const Icon(
								Icons.delete_outline,
								color: Colors.white,
							),
							onPressed: () async {
								// 1. Show Confirmation Dialog
								final confirm = await showDialog<bool>(
									context: context,
									builder: (ctx) => AlertDialog(
										shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
										title: const Text("Delete Goal?"),
										content: const Text(
											"This action cannot be undone. Are you sure you want to remove this goal permanently?",
											style: TextStyle(color: Colors.black87),
										),
										actions: [
											TextButton(
												onPressed: () => Navigator.pop(ctx, false),
												child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
											),
											TextButton(
												onPressed: () => Navigator.pop(ctx, true),
												child: const Text(
														"Delete",
														style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)
												),
											),
										],
									),
								);

								// 2. Perform Delete if Confirmed
								if (confirm == true) {
									final user = _auth.currentUser;
									if (user != null) {
										await _service.deleteGoal(user.uid, widget.existing!.id);

										// 3. Close the screen and go back to list
										if (mounted) {
											Navigator.pop(context);
										}
									}
								}
							},
						),
				],

				// Background faint white icon (same as other updated screens)
				flexibleSpace: Stack(
					children: [
						Positioned(
							right: -20,
							bottom: -20,
							child: Icon(
								Icons.analytics,
								size: 150,
								color: Colors.white.withOpacity(0.05),
							),
						),
					],
				),
			),

			body: Form(
				key: _formKey,
				child: ListView(
					physics: const BouncingScrollPhysics(),
					padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
					children: [

						// --- 1. Title & Description ---
						TextFormField(
							controller: _titleCtrl,
							style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
							decoration: InputDecoration(
								hintText: "What is your goal?",
								hintStyle: TextStyle(color: Colors.grey.shade400),
								border: InputBorder.none,
								contentPadding: EdgeInsets.zero,
							),
							validator: (v) => (v == null || v.trim().isEmpty) ? "Please enter a title" : null,
						),
						const SizedBox(height: 10),
						TextFormField(
							controller: _descCtrl,
							maxLines: null,
							style: const TextStyle(fontSize: 16, height: 1.5),
							decoration: InputDecoration(
								hintText: "Add details, motivation, or notes...",
								hintStyle: TextStyle(color: Colors.grey.shade400),
								border: InputBorder.none,
								contentPadding: EdgeInsets.zero,
							),
						),

						const Divider(height: 40),

						// --- 2. Category ---
						_buildSectionTitle("Category"),
						_buildCategorySelector(),
						const SizedBox(height: 24),

						// --- 3. Dates ---
						_buildSectionTitle("Timeline"),
						Row(
							children: [
								_buildDateTile(
									label: "START DATE",
									date: _startDate,
									onTap: () => _pickDate(start: true),
								),
								const SizedBox(width: 12),
								_buildDateTile(
									label: "TARGET DATE",
									date: _endDate,
									onTap: () => _pickDate(start: false),
								),
							],
						),
						const SizedBox(height: 24),

						// --- 4. Sub-Goals (The Checklist Look) ---
						Row(
							mainAxisAlignment: MainAxisAlignment.spaceBetween,
							children: [
								_buildSectionTitle("Action Plan"),
								TextButton.icon(
									onPressed: _addSubGoalField,
									icon: const Icon(Icons.add, size: 16),
									label: const Text("Add Sub goal"),
									style: TextButton.styleFrom(foregroundColor: AppColors.primary),
								)
							],
						),
						Container(
							decoration: BoxDecoration(
								color: Colors.white,
								borderRadius: BorderRadius.circular(16),
								border: Border.all(color: Colors.grey.shade200),
							),
							child: Column(
								children: _subGoals.asMap().entries.map((entry) {
									final index = entry.key;
									final s = entry.value;
									return Column(
										children: [
											Padding(
												padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
												child: Row(
													children: [
														Checkbox(
															value: s.completed,
															activeColor: AppColors.primary,
															shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
															onChanged: (v) => setState(() => s.completed = v ?? false),
														),
														Expanded(
															child: TextFormField(
																controller: s.controller,
																decoration: const InputDecoration(
																	hintText: "Next goal...",
																	border: InputBorder.none,
																),
															),
														),
														IconButton(
															icon: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
															onPressed: () => _removeSubGoalField(s),
														),
													],
												),
											),
											if (index != _subGoals.length - 1)
												Divider(height: 1, indent: 50, color: Colors.grey.shade100),
										],
									);
								}).toList(),
							),
						),
						const SizedBox(height: 24),

						// --- 5. Location & People (Grouped) ---
						_buildSectionTitle("Context"),
						Container(
							padding: const EdgeInsets.all(16),
							decoration: BoxDecoration(
								color: Colors.white,
								borderRadius: BorderRadius.circular(16),
								border: Border.all(color: Colors.grey.shade200),
							),
							child: Column(
								children: [
									// Location Row
									InkWell(
										onTap: _pickLocation,
										child: Row(
											children: [
												Container(
													padding: const EdgeInsets.all(8),
													decoration: BoxDecoration(
														color: Colors.orangeAccent.withOpacity(0.1),
														borderRadius: BorderRadius.circular(8),
													),
													child: const Icon(Icons.location_on, color: Colors.orangeAccent),
												),
												const SizedBox(width: 16),
												Expanded(
													child: Column(
														crossAxisAlignment: CrossAxisAlignment.start,
														children: [
															Text(
																_locationCtrl.text.isEmpty ? "Add Location" : _locationCtrl.text,
																style: TextStyle(
																	fontWeight: FontWeight.w600,
																	color: _locationCtrl.text.isEmpty ? Colors.grey.shade400 : AppColors.textPrimary,
																),
															),
															if (_lat != null)
																Text(
																	"Coordinates set",
																	style: TextStyle(fontSize: 11, color: Colors.green.shade600),
																)
														],
													),
												),
												const Icon(Icons.chevron_right, color: Colors.grey),
											],
										),
									),
									const Padding(
										padding: EdgeInsets.symmetric(vertical: 12),
										child: Divider(),
									),

									// People Row
									// People Row
									InkWell(
										onTap: _openPeoplePicker, // <--- CHANGED THIS: Point to new method
										child: Row(
											children: [
												Container(
													padding: const EdgeInsets.all(8),
													decoration: BoxDecoration(
														color: Colors.blueAccent.withOpacity(0.1),
														borderRadius: BorderRadius.circular(8),
													),
													child: const Icon(Icons.people, color: Colors.blueAccent),
												),
												const SizedBox(width: 16),
												Expanded(
													child: _people.isEmpty
															? Text("Tag People", style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600))
															: Wrap(
														spacing: 6,
														runSpacing: 4,
														children: _people.map((p) => Chip(
															label: Text(p, style: const TextStyle(fontSize: 11)),
															backgroundColor: Colors.blue.shade50,
															padding: EdgeInsets.zero,
															labelPadding: const EdgeInsets.symmetric(horizontal: 8), // Adjusted padding
															materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
															onDeleted: () => setState(() => _people.remove(p)),
														)).toList(),
													),
												),
												// Change icon to Edit/Chevron to indicate selection
												Icon(
														_people.isEmpty ? Icons.add : Icons.edit_outlined,
														color: Colors.grey,
														size: 20
												),
											],
										),
									),
								],
							),
						),

						// --- 6. Save Button ---
						const SizedBox(height: 40),
						ElevatedButton(
							onPressed: _save,
							style: ElevatedButton.styleFrom(
								backgroundColor: AppColors.primary,
								foregroundColor: Colors.white,
								elevation: 4,
								shadowColor: AppColors.primary.withOpacity(0.4),
								padding: const EdgeInsets.symmetric(vertical: 18),
								shape: RoundedRectangleBorder(
									borderRadius: BorderRadius.circular(16),
								),
							),
							child: const Text(
								"Save Goal",
								style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
							),
						),
						const SizedBox(height: 30),
					],
				),
			),
		);
	}
}