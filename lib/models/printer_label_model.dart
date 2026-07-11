class PrinterLabel {
  final String id;
  final String name;
  final String? description;
  final String? createdAt;
  final String? updatedAt;
  final bool isSelected;

  const PrinterLabel({
    required this.id,
    required this.name,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.isSelected = false,
  });

  factory PrinterLabel.fromJson(Map<String, dynamic> json) {
    return PrinterLabel(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      isSelected: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      if (description != null) 'description': description,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  PrinterLabel copyWith({
    String? id,
    String? name,
    String? description,
    String? createdAt,
    String? updatedAt,
    bool? isSelected,
  }) {
    return PrinterLabel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
