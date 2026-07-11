class Category {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final bool isActive;
  final bool showOnPos;
  final bool? showOnWeb;
  final CategoryStore? store;
  final List<CategoryProductRef> products;
  final int sortOrder;
  final CategoryAvailability? availability;
  final CategoryCreatedBy? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final CategoryParent? parent;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.isActive = true,
    this.showOnPos = true,
    this.showOnWeb,
    this.store,
    List<CategoryProductRef>? products,
    this.sortOrder = 0,
    this.availability,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.parent,
  }) : products = products ?? [];

  int get productsCount => products.length;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      showOnPos: json['showOnPos'] as bool? ?? true,
      showOnWeb: json['showOnWeb'] as bool?,
      store: json['store'] != null
          ? CategoryStore.fromJson(json['store'] as Map<String, dynamic>)
          : null,
      products: (json['products'] as List<dynamic>?)
              ?.map((product) => CategoryProductRef.fromJson(product as Map<String, dynamic>))
              .toList() ??
          [],
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      availability: json['availability'] != null
          ? CategoryAvailability.fromJson(json['availability'] as Map<String, dynamic>)
          : null,
      createdBy: json['createdBy'] != null
          ? CategoryCreatedBy.fromJson(json['createdBy'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      parent: json['parent'] != null
          ? CategoryParent.fromJson(json['parent'] as Map<String, dynamic>)
          : null,
    );
  }
}

class CategoryStore {
  final String id;
  final String name;

  CategoryStore({required this.id, required this.name});

  factory CategoryStore.fromJson(Map<String, dynamic> json) {
    return CategoryStore(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class CategoryProductRef {
  final String id;
  final String name;

  CategoryProductRef({required this.id, required this.name});

  factory CategoryProductRef.fromJson(Map<String, dynamic> json) {
    return CategoryProductRef(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class CategoryAvailability {
  final String type;
  final String? start;
  final String? end;
  final String? note;

  CategoryAvailability({
    required this.type,
    this.start,
    this.end,
    this.note,
  });

  factory CategoryAvailability.fromJson(Map<String, dynamic> json) {
    return CategoryAvailability(
      type: json['type'] as String? ?? 'all-day',
      start: json['start'] as String?,
      end: json['end'] as String?,
      note: json['note'] as String?,
    );
  }
}

class CategoryCreatedBy {
  final String id;
  final String username;
  final String firstName;
  final String lastName;

  CategoryCreatedBy({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
  });

  factory CategoryCreatedBy.fromJson(Map<String, dynamic> json) {
    return CategoryCreatedBy(
      id: json['_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
    );
  }

  String get fullName {
    if (lastName.isEmpty) return firstName;
    return '$firstName $lastName';
  }
}

class CategoryParent {
  final String id;
  final String name;
  final String slug;

  CategoryParent({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory CategoryParent.fromJson(Map<String, dynamic> json) {
    return CategoryParent(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
    );
  }
}

