class SelfOrderRequest {
  final String? id;
  final String orderNumber;
  final String tableNumber;
  final String store;
  final List<String> selectedNeeds;
  final bool other;
  final String customRequest;
  final String customerName;
  final String phone;
  final String status; // Pending, Accepted, Completed, etc.
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SelfOrderRequest({
    this.id,
    required this.orderNumber,
    required this.tableNumber,
    required this.store,
    this.selectedNeeds = const [],
    this.other = false,
    this.customRequest = '',
    this.customerName = '',
    this.phone = '',
    this.status = 'Pending',
    this.createdAt,
    this.updatedAt,
  });

  // Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'orderNumber': orderNumber,
      'tableNumber': tableNumber,
      'store': store,
      'selectedNeeds': selectedNeeds,
      'other': other,
      'customRequest': customRequest,
      'customerName': customerName,
      'phone': phone,
    };
  }

  // Create from JSON response
  factory SelfOrderRequest.fromJson(Map<String, dynamic> json) {
    return SelfOrderRequest(
      id: json['_id'] ?? json['id'],
      orderNumber: json['orderNumber'] ?? '',
      tableNumber: json['tableNumber'] ?? '',
      store: json['store'] ?? '',
      selectedNeeds: List<String>.from(json['selectedNeeds'] ?? []),
      other: json['other'] ?? false,
      customRequest: json['customRequest'] ?? '',
      customerName: json['customerName'] ?? '',
      phone: json['phone'] ?? '',
      status: json['status'] ?? 'Pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  // Copy with method
  SelfOrderRequest copyWith({
    String? id,
    String? orderNumber,
    String? tableNumber,
    String? store,
    List<String>? selectedNeeds,
    bool? other,
    String? customRequest,
    String? customerName,
    String? phone,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SelfOrderRequest(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      tableNumber: tableNumber ?? this.tableNumber,
      store: store ?? this.store,
      selectedNeeds: selectedNeeds ?? this.selectedNeeds,
      other: other ?? this.other,
      customRequest: customRequest ?? this.customRequest,
      customerName: customerName ?? this.customerName,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Response model for paginated results
class SelfOrderRequestsResponse {
  final List<SelfOrderRequest> requests;
  final int total;
  final int page;
  final int limit;
  final int pages;

  SelfOrderRequestsResponse({
    required this.requests,
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
  });

  factory SelfOrderRequestsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>?;
    final requests = (data ?? [])
        .map((item) => SelfOrderRequest.fromJson(item as Map<String, dynamic>))
        .toList();

    return SelfOrderRequestsResponse(
      requests: requests,
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      pages: json['pages'] ?? 1,
    );
  }
}
