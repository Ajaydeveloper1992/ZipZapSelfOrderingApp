class TimeClockBreak {
  final DateTime start;
  final DateTime? end;

  TimeClockBreak({required this.start, this.end});

  factory TimeClockBreak.fromJson(Map<String, dynamic> json) {
    return TimeClockBreak(
      start: DateTime.parse(json['start']),
      end: json['end'] != null ? DateTime.parse(json['end']) : null,
    );
  }

  Duration get duration {
    final endTime = end ?? DateTime.now();
    return endTime.difference(start);
  }
}

class TimeClockUser {
  final String id;
  final String firstName;
  final String? lastName;
  final String username;
  final String? email;
  final String? avatar;

  TimeClockUser({
    required this.id,
    required this.firstName,
    this.lastName,
    required this.username,
    this.email,
    this.avatar,
  });

  factory TimeClockUser.fromJson(Map<String, dynamic> json) {
    return TimeClockUser(
      id: json['_id'] ?? json['id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'],
      username: json['username'] ?? '',
      email: json['email'],
      avatar: json['avatar'],
    );
  }

  String get fullName => '${firstName} ${lastName ?? ''}'.trim();
}

class TimeClockStore {
  final String id;
  final String? name;

  TimeClockStore({required this.id, this.name});

  factory TimeClockStore.fromJson(Map<String, dynamic> json) {
    return TimeClockStore(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'],
    );
  }
}

class TimeClockEntry {
  final String id;
  final TimeClockUser? user;
  final TimeClockStore? store;
  final DateTime clockIn;
  final DateTime? clockOut;
  final List<TimeClockBreak> breaks;
  final String status;
  final String? note;
  final int totalBreakMinutes;
  final int totalWorkMinutes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TimeClockEntry({
    required this.id,
    this.user,
    this.store,
    required this.clockIn,
    this.clockOut,
    required this.breaks,
    required this.status,
    this.note,
    this.totalBreakMinutes = 0,
    this.totalWorkMinutes = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory TimeClockEntry.fromJson(Map<String, dynamic> json) {
    return TimeClockEntry(
      id: json['_id'] ?? json['id'] ?? '',
      user: json['user'] is Map<String, dynamic>
          ? TimeClockUser.fromJson(json['user'])
          : null,
      store: json['store'] is Map<String, dynamic>
          ? TimeClockStore.fromJson(json['store'])
          : null,
      clockIn: DateTime.parse(json['clockIn']),
      clockOut:
          json['clockOut'] != null ? DateTime.parse(json['clockOut']) : null,
      breaks: (json['breaks'] as List<dynamic>?)
              ?.map((b) => TimeClockBreak.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
      status: json['status'] ?? 'active',
      note: json['note'],
      totalBreakMinutes: json['totalBreakMinutes'] ?? 0,
      totalWorkMinutes: json['totalWorkMinutes'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  bool get isActive => status == 'active';
  bool get isOnBreak => status == 'on_break';
  bool get isCompleted => status == 'completed';
  bool get isClockedIn => isActive || isOnBreak;

  Duration get elapsedTime {
    final endTime = clockOut ?? DateTime.now();
    return endTime.difference(clockIn);
  }

  Duration get currentBreakDuration {
    if (!isOnBreak || breaks.isEmpty) return Duration.zero;
    final lastBreak = breaks.last;
    if (lastBreak.end != null) return Duration.zero;
    return DateTime.now().difference(lastBreak.start);
  }
}
