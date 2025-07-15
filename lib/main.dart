import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/file_transfer_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => FileTransferService(),
      child: MaterialApp(
        title: '文件传输助手',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Color(0xFF2176FF),                // 主色鲜明蓝
            primary: Color(0xFF2176FF),
            primaryContainer: Color(0xFFE3F2FD),
            secondary: Color(0xFFFFCA3A),                // 强调色亮黄
            secondaryContainer: Color(0xFFFFF3CD),
            surface: Color(0xFFFFFFFF),
            background: Color(0xFFF8F9FA),               // 背景高亮
            error: Color(0xFFFF4C4C),
            onPrimary: Colors.white,
            onSecondary: Colors.black,
            onSurface: Colors.black87,
            onBackground: Colors.black87,
            onError: Colors.white,
            brightness: Brightness.light,
          ),
          fontFamily: 'Roboto',            // 字体现代无衬线，如果未加自定义字体包可留空保持默认
          textTheme: const TextTheme(
            headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2176FF)),
            headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF2176FF)),
            titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
            bodyMedium: TextStyle(fontSize: 14, color: Colors.black54),
            labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF2176FF)),
            // 按钮高对比可读性
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ButtonStyle(
              backgroundColor: MaterialStatePropertyAll(Color(0xFF2176FF)),
              foregroundColor: MaterialStatePropertyAll(Colors.white),
              shape: MaterialStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
              elevation: MaterialStatePropertyAll(4),
              textStyle: MaterialStatePropertyAll(TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1.1,
              )),
            ),
          ),
          cardTheme: const CardThemeData(
            color: Colors.white,
            elevation: 6,
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2176FF), width: 2),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF2176FF),
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: Color(0xFF2176FF),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            iconTheme: IconThemeData(
              color: Color(0xFF2176FF),
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
