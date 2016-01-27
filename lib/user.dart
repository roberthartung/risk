library risk.user;

class User {
  final String name;

  static Map<String, User> _users = new Map<String, User>();

  factory User(name) {
    if (_users.containsKey(name)) {
      return _users[name];
    } else {
      final user = new User._(name);
      _users[name] = user;
      return user;
    }
  }

  User._(this.name);

  String toString() => name;
}