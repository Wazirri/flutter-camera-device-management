class User {
  final String username;
  final String password;
  final String fullname;
  final String usertype;
  final bool active;
  final int created;
  final int lastlogin;

  User({
    required this.username,
    required this.password,
    required this.fullname,
    required this.usertype,
    required this.active,
    required this.created,
    required this.lastlogin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      fullname: json['fullname'] ?? '',
      usertype: json['usertype'] ?? '',
      active: (json['active'] == 1 || json['active'] == true),
      created: json['created'] is int ? json['created'] : 0,
      lastlogin: json['lastlogin'] is int ? json['lastlogin'] : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'fullname': fullname,
      'usertype': usertype,
      'active': active ? 1 : 0,
      'created': created,
      'lastlogin': lastlogin,
    };
  }

  User copyWith({
    String? username,
    String? password,
    String? fullname,
    String? usertype,
    bool? active,
    int? created,
    int? lastlogin,
  }) {
    return User(
      username: username ?? this.username,
      password: password ?? this.password,
      fullname: fullname ?? this.fullname,
      usertype: usertype ?? this.usertype,
      active: active ?? this.active,
      created: created ?? this.created,
      lastlogin: lastlogin ?? this.lastlogin,
    );
  }

  @override
  String toString() {
    return 'User(username: $username, fullname: $fullname, usertype: $usertype, active: $active)';
  }
}
