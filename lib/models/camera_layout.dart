import 'dart:convert';

class CameraLayout {
  final String name;
  final int id;
  final int rows;
  final int columns;
  final int slots;
  final String description;
  Map<String, int> cameraAssignments; // Maps camera IDs to slot indexes

  CameraLayout({
    required this.name,
    required this.id,
    required this.rows,
    required this.columns,
    required this.slots,
    required this.description,
    Map<String, int>? cameraAssignments,
  }) : this.cameraAssignments = cameraAssignments ?? {};

  // Deep copy constructor
  CameraLayout.copy(CameraLayout source)
      : name = source.name,
        id = source.id,
        rows = source.rows,
        columns = source.columns,
        slots = source.slots,
        description = source.description,
        cameraAssignments = Map<String, int>.from(source.cameraAssignments);

  // Assign a camera to a specific slot
  void assignCamera(String cameraId, int slotIndex) {
    if (slotIndex >= 0 && slotIndex < slots) {
      cameraAssignments[cameraId] = slotIndex;
    }
  }

  // Remove a camera from its slot
  void removeCamera(String cameraId) {
    cameraAssignments.remove(cameraId);
  }

  // Clear all camera assignments
  void clearAssignments() {
    cameraAssignments.clear();
  }

  // Get the camera ID assigned to a specific slot, or null if empty
  String? getCameraIdAtSlot(int slotIndex) {
    for (var entry in cameraAssignments.entries) {
      if (entry.value == slotIndex) {
        return entry.key;
      }
    }
    return null;
  }

  // Get the slot index for a specific camera, or -1 if not assigned
  int getSlotForCamera(String cameraId) {
    return cameraAssignments[cameraId] ?? -1;
  }

  // From JSON constructor
  factory CameraLayout.fromJson(Map<String, dynamic> json) {
    return CameraLayout(
      name: json['name'] ?? 'Unknown Layout',
      id: json['id'] ?? 0,
      rows: json['rows'] ?? 0,
      columns: json['columns'] ?? 0,
      slots: json['slots'] ?? 0,
      description: json['description'] ?? '',
      cameraAssignments: json['cameraAssignments'] != null
          ? Map<String, int>.from(json['cameraAssignments'])
          : {},
    );
  }

  // To JSON method
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'id': id,
      'rows': rows,
      'columns': columns,
      'slots': slots,
      'description': description,
      'cameraAssignments': cameraAssignments,
    };
  }

  // Parse a list of layouts from JSON string
  static List<CameraLayout> parseLayouts(String jsonString) {
    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((layout) => CameraLayout.fromJson(layout))
          .toList();
    } catch (e) {
      print('Error parsing camera layouts: $e');
      return [
        // Default layout if parsing fails
        CameraLayout(
          name: 'Default',
          id: 4,
          rows: 5,
          columns: 4,
          slots: 20,
          description: 'Default grid layout with 4 columns and 5 rows',
        ),
      ];
    }
  }

  @override
  String toString() {
    return 'CameraLayout{name: $name, id: $id, rows: $rows, columns: $columns, slots: $slots}';
  }
}
