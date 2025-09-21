import 'package:flutter/foundation.dart';

enum UserRole { employee, boss }

class SessionStore extends ChangeNotifier {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  UserRole? _role;
  String? _employeeIdentifier; // tipicamente email
  String? _employeeDisplayName;

  UserRole? get role => _role;
  String? get employeeIdentifier => _employeeIdentifier;
  String? get employeeDisplayName => _employeeDisplayName;
  bool get isLoggedIn => _role != null;
  bool get isEmployee => _role == UserRole.employee;
  bool get isBoss => _role == UserRole.boss;

  void loginEmployee({required String identifier, String? displayName}) {
    _role = UserRole.employee;
    _employeeIdentifier = identifier.trim();
    _employeeDisplayName = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : _employeeIdentifier;
    notifyListeners();
  }

  void loginBoss() {
    _role = UserRole.boss;
    _employeeIdentifier = null;
    _employeeDisplayName = null;
    notifyListeners();
  }

  void logout() {
    _role = null;
    _employeeIdentifier = null;
    _employeeDisplayName = null;
    notifyListeners();
  }
}
