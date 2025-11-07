import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'data_provider.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  try {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    
    // Ensure the adapter is registered
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ExcelDataAdapter());
      print('ExcelDataAdapter registered successfully');
    } else {
      print('ExcelDataAdapter already registered');
    }
  } catch (e) {
    print('Error initializing Hive: $e');
    // Continue anyway, the app should still work
  }
  
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({Key? key, required this.isLoggedIn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DataProvider(),
      child: MaterialApp(
        title: 'Check Price App',
        theme: ThemeData(
          primaryColor: Color(0xFF1976D2),
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: Color(0xFF1976D2),
            secondary: Color(0xFFFF9800),
            background: Color(0xFFF5F5F5),
            error: Color(0xFFF44336),
          ),
          scaffoldBackgroundColor: Color(0xFFF5F5F5),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            ),
          ),
          cardTheme: CardThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            margin: EdgeInsets.all(8),
          ),
        ),
        home: isLoggedIn ? HomePage() : LoginPage(),
      ),
    );
  }
}
