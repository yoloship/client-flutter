import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  Future<void> loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    // 假设 user 信息存为简单字符串，真实项目推荐 jsonEncode
    final userStr = prefs.getString('user');
    if (userStr != null && userStr.isNotEmpty) {
      // 简单解析，实际上应导入 dart:convert 进行 jsonDecode
      // _user = jsonDecode(userStr);
    }
    notifyListeners();
  }

  Future<void> saveAuthData(String token, Map<String, dynamic> user) async {
    _token = token;
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    // await prefs.setString('user', jsonEncode(user));
    notifyListeners();
  }

  Future<void> clearAuthData() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    notifyListeners();
  }
}
