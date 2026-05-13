import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RequestUtil {
  static final Dio _dio = Dio(BaseOptions(
    // 如果是真机调试本地开发服务器，Android 模拟器需指向 10.0.2.2，或者使用局域网 IP
    baseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://192.168.124.17:8080/api/v1'),
    connectTimeout: const Duration(seconds: 90),
    receiveTimeout: const Duration(seconds: 90),
  ));

  static void init() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // Token 过期，清除状态并退回登录页
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('token');
          await prefs.remove('user');
          // TODO: 全局导航跳回 Login
        }
        return handler.next(e);
      },
    ));
  }

  static Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    final response = await _dio.get(path, queryParameters: queryParameters);
    return response.data;
  }

  static Future<dynamic> post(String path, {dynamic data}) async {
    final response = await _dio.post(path, data: data);
    return response.data;
  }

  static Future<dynamic> put(String path, {dynamic data}) async {
    final response = await _dio.put(path, data: data);
    return response.data;
  }

  static Future<dynamic> delete(String path) async {
    final response = await _dio.delete(path);
    return response.data;
  }

  /// 上传图片到服务器
  static Future<String> uploadPhoto(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post('/mina/upload', data: formData);
    if (response.statusCode == 200) {
      if (response.data is Map && response.data['url'] != null) {
        return response.data['url'];
      }
    }
    throw Exception('图片上传失败');
  }
}
