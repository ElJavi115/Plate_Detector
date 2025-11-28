import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'dart:convert';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  Persona? _currentUser;
  Persona? get currentUser => _currentUser;

  bool get isLogin => _currentUser != null;
  bool get esAdmin => _currentUser?.esAdmin ?? false;
  bool get esUsuario => _currentUser?.esUsuario ?? false;

  Future<void> login(Persona persona) async {
    _currentUser = persona;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(persona.toJson()));
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
  }

  Future<bool> loadSavedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('current_user');
      
      if (userData != null) {
        final json = jsonDecode(userData) as Map<String, dynamic>;
        _currentUser = Persona.fromJson(json);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}