/// Lightweight representation of a user that can be selected as the
/// "server" / staff for an order. Mirrors the populated shape returned
/// by the server's `/users/staff` endpoint.
class StaffMember {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? username;
  final String? avatar;

  const StaffMember({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.username,
    this.avatar,
  });

  String get fullName {
    final first = firstName.trim();
    final last = lastName.trim();
    if (first.isEmpty && last.isEmpty) {
      return username?.trim().isNotEmpty == true ? username!.trim() : email;
    }
    if (last.isEmpty) return first;
    if (first.isEmpty) return last;
    return '$first $last';
  }

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      firstName: (json['firstName'] as String?) ?? '',
      lastName: (json['lastName'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      username: json['username'] as String?,
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        if (username != null) 'username': username,
        if (avatar != null) 'avatar': avatar,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is StaffMember && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
