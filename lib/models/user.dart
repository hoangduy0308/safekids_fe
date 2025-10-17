class User {
  final String id;
  final String name;
  final String? fullName;
  final String email;
  final String? phone;
  final String role; // 'parent' or 'child'
  final int? age;
  final List<String> linkedUsers; // User IDs or populated user objects
  final List<Map<String, dynamic>> linkedUsersData; // Populated user objects from backend
  final String? fcmToken;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    this.fullName,
    required this.email,
    this.phone,
    required this.role,
    this.age,
    this.linkedUsers = const [],
    this.linkedUsersData = const [],
    this.fcmToken,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Handle linkedUsers - can be array of IDs or populated objects
    List<String> linkedUserIds = [];
    List<Map<String, dynamic>> linkedUsersDataList = [];
    
    // Try to get linkedUsersData first (populated objects from backend)
    if (json['linkedUsersData'] != null && json['linkedUsersData'] is List) {
      for (var item in json['linkedUsersData']) {
        if (item is Map<String, dynamic>) {
          linkedUsersDataList.add({
            '_id': item['_id'] ?? item['id'] ?? '',
            'id': item['_id'] ?? item['id'] ?? '',
            'name': item['name'] ?? item['fullName'] ?? '',
            'fullName': item['fullName'] ?? item['name'] ?? '',
            'email': item['email'] ?? '',
            'role': item['role'] ?? 'child',
            'age': item['age'],
            'avatar': item['avatar'],
          });
          linkedUserIds.add(item['_id'] ?? item['id'] ?? '');
        }
      }
    }
    // Fallback to linkedUsers if linkedUsersData is empty
    else if (json['linkedUsers'] != null && json['linkedUsers'] is List) {
      for (var item in json['linkedUsers']) {
        if (item is String) {
          linkedUserIds.add(item);
        } else if (item is Map<String, dynamic>) {
          linkedUsersDataList.add({
            '_id': item['_id'] ?? item['id'] ?? '',
            'id': item['_id'] ?? item['id'] ?? '',
            'name': item['name'] ?? item['fullName'] ?? '',
            'fullName': item['fullName'] ?? item['name'] ?? '',
            'email': item['email'] ?? '',
            'role': item['role'] ?? 'child',
            'age': item['age'],
            'avatar': item['avatar'],
          });
          linkedUserIds.add(item['_id'] ?? item['id'] ?? '');
        }
      }
    }
    
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? json['fullName'] ?? '',
      fullName: json['fullName'] ?? json['name'], // Fallback to name
      email: json['email'] ?? '',
      phone: json['phone'],
      role: json['role'] ?? 'child',
      age: json['age'],
      linkedUsers: linkedUserIds,
      linkedUsersData: linkedUsersDataList,
      fcmToken: json['fcmToken'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'age': age,
      'linkedUsers': linkedUsers,
      'fcmToken': fcmToken,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? fullName,
    String? email,
    String? phone,
    String? role,
    int? age,
    List<String>? linkedUsers,
    List<Map<String, dynamic>>? linkedUsersData,
    String? fcmToken,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      age: age ?? this.age,
      linkedUsers: linkedUsers ?? this.linkedUsers,
      linkedUsersData: linkedUsersData ?? this.linkedUsersData,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isParent => role == 'parent';
  bool get isChild => role == 'child';
}