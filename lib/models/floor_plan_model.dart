/// Table status enum
enum TableStatus {
  available,
  occupied, // Currently in use by a dine-in order
  reserved; // Reserved for advance booking (future use)

  static TableStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'available':
        return TableStatus.available;
      case 'occupied':
        return TableStatus.occupied;
      case 'reserved':
        return TableStatus.reserved;
      default:
        return TableStatus.available;
    }
  }

  String get value {
    switch (this) {
      case TableStatus.available:
        return 'available';
      case TableStatus.occupied:
        return 'occupied';
      case TableStatus.reserved:
        return 'reserved';
    }
  }
}

/// Order info for reserved tables
class TableOrderInfo {
  final String? orderId;
  final String? orderNumber;
  final double? orderTotal;
  final String? staffName;

  TableOrderInfo({
    this.orderId,
    this.orderNumber,
    this.orderTotal,
    this.staffName,
  });

  factory TableOrderInfo.fromJson(Map<String, dynamic> json) {
    return TableOrderInfo(
      orderId: json['orderId'] as String?,
      orderNumber: json['orderNumber'] as String?,
      orderTotal: (json['orderTotal'] as num?)?.toDouble(),
      staffName: json['staffName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (orderId != null) 'orderId': orderId,
      if (orderNumber != null) 'orderNumber': orderNumber,
      if (orderTotal != null) 'orderTotal': orderTotal,
      if (staffName != null) 'staffName': staffName,
    };
  }
}

/// Floor item type enum
enum FloorItemType {
  rectangular,
  square,
  circular,
  barStool,
  wall,
  cashRegister,
  door,
  window,
  bar,
  counter,
  table;

  static FloorItemType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'rectangular':
        return FloorItemType.rectangular;
      case 'square':
        return FloorItemType.square;
      case 'circular':
        return FloorItemType.circular;
      case 'bar-stool':
        return FloorItemType.barStool;
      case 'wall':
        return FloorItemType.wall;
      case 'cash-register':
        return FloorItemType.cashRegister;
      case 'door':
        return FloorItemType.door;
      case 'window':
        return FloorItemType.window;
      case 'bar':
        return FloorItemType.bar;
      case 'counter':
        return FloorItemType.counter;
      case 'table':
        return FloorItemType.table;
      default:
        return FloorItemType.table;
    }
  }

  String get value {
    switch (this) {
      case FloorItemType.rectangular:
        return 'rectangular';
      case FloorItemType.square:
        return 'square';
      case FloorItemType.circular:
        return 'circular';
      case FloorItemType.barStool:
        return 'bar-stool';
      case FloorItemType.wall:
        return 'wall';
      case FloorItemType.cashRegister:
        return 'cash-register';
      case FloorItemType.door:
        return 'door';
      case FloorItemType.window:
        return 'window';
      case FloorItemType.bar:
        return 'bar';
      case FloorItemType.counter:
        return 'counter';
      case FloorItemType.table:
        return 'table';
    }
  }

  /// Returns true if this item type is a table
  bool get isTable {
    return this == FloorItemType.rectangular ||
        this == FloorItemType.square ||
        this == FloorItemType.circular ||
        this == FloorItemType.barStool ||
        this == FloorItemType.table;
  }
}

/// Floor item (table, wall, cash register, etc.)
class FloorItem {
  final String id;
  final FloorItemType type;
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final bool selected;
  final String? section;
  final int? seats;
  final int? minSeats;
  final int? maxSeats;
  final TableStatus status;
  final DateTime? occupiedAt; // When table was occupied by active order
  final DateTime? reservedAt; // When table was reserved for advance booking
  final TableOrderInfo? orderInfo;

  FloorItem({
    required this.id,
    required this.type,
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.selected = false,
    this.section,
    this.seats,
    this.minSeats,
    this.maxSeats,
    this.status = TableStatus.available,
    this.occupiedAt,
    this.reservedAt,
    this.orderInfo,
  });

  factory FloorItem.fromJson(Map<String, dynamic> json) {
    return FloorItem(
      id: json['id'] as String? ?? '',
      type: FloorItemType.fromString(json['type'] as String?),
      name: json['name'] as String? ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 60,
      height: (json['height'] as num?)?.toDouble() ?? 60,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      selected: json['selected'] as bool? ?? false,
      section: json['section'] as String?,
      seats: json['seats'] as int?,
      minSeats: json['minSeats'] as int?,
      maxSeats: json['maxSeats'] as int?,
      status: TableStatus.fromString(json['status'] as String?),
      occupiedAt: json['occupiedAt'] != null
          ? DateTime.tryParse(json['occupiedAt'] as String)
          : null,
      reservedAt: json['reservedAt'] != null
          ? DateTime.tryParse(json['reservedAt'] as String)
          : null,
      orderInfo: json['orderInfo'] != null
          ? TableOrderInfo.fromJson(json['orderInfo'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.value,
      'name': name,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
      'selected': selected,
      if (section != null) 'section': section,
      if (seats != null) 'seats': seats,
      if (minSeats != null) 'minSeats': minSeats,
      if (maxSeats != null) 'maxSeats': maxSeats,
      'status': status.value,
      if (occupiedAt != null) 'occupiedAt': occupiedAt!.toIso8601String(),
      if (reservedAt != null) 'reservedAt': reservedAt!.toIso8601String(),
      if (orderInfo != null) 'orderInfo': orderInfo!.toJson(),
    };
  }

  FloorItem copyWith({
    String? id,
    FloorItemType? type,
    String? name,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    bool? selected,
    String? section,
    int? seats,
    int? minSeats,
    int? maxSeats,
    TableStatus? status,
    DateTime? occupiedAt,
    DateTime? reservedAt,
    TableOrderInfo? orderInfo,
  }) {
    return FloorItem(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      selected: selected ?? this.selected,
      section: section ?? this.section,
      seats: seats ?? this.seats,
      minSeats: minSeats ?? this.minSeats,
      maxSeats: maxSeats ?? this.maxSeats,
      status: status ?? this.status,
      occupiedAt: occupiedAt ?? this.occupiedAt,
      reservedAt: reservedAt ?? this.reservedAt,
      orderInfo: orderInfo ?? this.orderInfo,
    );
  }
}

/// Section in a floor plan
class FloorSection {
  final String id;
  final String name;

  FloorSection({required this.id, required this.name});

  factory FloorSection.fromJson(Map<String, dynamic> json) {
    return FloorSection(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}

/// Store reference
class FloorPlanStore {
  final String id;
  final String? name;

  FloorPlanStore({required this.id, this.name});

  factory FloorPlanStore.fromJson(Map<String, dynamic> json) {
    return FloorPlanStore(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String?,
    );
  }
}

/// Created by user reference
class FloorPlanCreatedBy {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? username;

  FloorPlanCreatedBy({
    required this.id,
    this.firstName,
    this.lastName,
    this.username,
  });

  factory FloorPlanCreatedBy.fromJson(Map<String, dynamic> json) {
    return FloorPlanCreatedBy(
      id: json['_id'] as String? ?? '',
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      username: json['username'] as String?,
    );
  }

  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return username ?? 'Unknown';
  }
}

/// Floor Plan model
class FloorPlan {
  final String id;
  final String planId;
  final String name;
  final String? description;
  final String? floorType;
  final double width;
  final double height;
  final List<FloorItem> items;
  final List<FloorSection> sections;
  final FloorPlanStore? store;
  final FloorPlanCreatedBy? createdBy;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FloorPlan({
    required this.id,
    required this.planId,
    required this.name,
    this.description,
    this.floorType,
    required this.width,
    required this.height,
    required this.items,
    required this.sections,
    this.store,
    this.createdBy,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory FloorPlan.fromJson(Map<String, dynamic> json) {
    return FloorPlan(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      planId: json['planId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      floorType: json['floorType'] as String?,
      width: (json['width'] as num?)?.toDouble() ?? 800,
      height: (json['height'] as num?)?.toDouble() ?? 600,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((item) => FloorItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      sections:
          (json['sections'] as List<dynamic>?)
              ?.map((s) => FloorSection.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      store: json['store'] != null
          ? (json['store'] is Map<String, dynamic>
                ? FloorPlanStore.fromJson(json['store'] as Map<String, dynamic>)
                : FloorPlanStore(id: json['store'] as String))
          : null,
      createdBy: json['createdBy'] != null
          ? (json['createdBy'] is Map<String, dynamic>
                ? FloorPlanCreatedBy.fromJson(
                    json['createdBy'] as Map<String, dynamic>,
                  )
                : null)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'planId': planId,
      'name': name,
      if (description != null) 'description': description,
      if (floorType != null) 'floorType': floorType,
      'width': width,
      'height': height,
      'items': items.map((item) => item.toJson()).toList(),
      'sections': sections.map((s) => s.toJson()).toList(),
      'isActive': isActive,
    };
  }

  /// Get table count
  int get tableCount => items.where((item) => item.type.isTable).length;

  /// Get available tables count
  int get availableTableCount => items
      .where(
        (item) => item.type.isTable && item.status == TableStatus.available,
      )
      .length;

  /// Get reserved tables count
  int get reservedTableCount => items
      .where((item) => item.type.isTable && item.status == TableStatus.reserved)
      .length;

  FloorPlan copyWith({
    String? id,
    String? planId,
    String? name,
    String? description,
    String? floorType,
    double? width,
    double? height,
    List<FloorItem>? items,
    List<FloorSection>? sections,
    FloorPlanStore? store,
    FloorPlanCreatedBy? createdBy,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FloorPlan(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      name: name ?? this.name,
      description: description ?? this.description,
      floorType: floorType ?? this.floorType,
      width: width ?? this.width,
      height: height ?? this.height,
      items: items ?? this.items,
      sections: sections ?? this.sections,
      store: store ?? this.store,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Floor Plans API response
class FloorPlansResponse {
  final List<FloorPlan> floorPlans;
  final String? message;

  FloorPlansResponse({required this.floorPlans, this.message});

  factory FloorPlansResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    List<FloorPlan> plans = [];

    if (data is List) {
      plans = data
          .map((item) => FloorPlan.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return FloorPlansResponse(
      floorPlans: plans,
      message: json['message'] as String?,
    );
  }
}
