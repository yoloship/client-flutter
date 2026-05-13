import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/user_provider.dart';
import 'utils/request.dart';
import 'pages/auth/login_page.dart';
import 'pages/index/index_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化全局网络拦截器
  RequestUtil.init();

  // 初始化用户状态
  final userProvider = UserProvider();
  await userProvider.loadLocalData();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userProvider),
      ],
      child: const PixelLogicApp(),
    ),
  );
}

class PixelLogicApp extends StatelessWidget {
  const PixelLogicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PixelLogic',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      initialRoute: context.watch<UserProvider>().isLoggedIn ? '/index' : '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/index': (context) => const IndexPage(),
      },
    );
  }
}
