import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:wallx_setter/wallx_setter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_gallery_saver/easy_gallery_saver.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ProviderScope(child: MyApp()));
}

// ==================== PEXELS API SERVICE ====================
class PexelsService {
  static const String apiKey = 'teCfJxfvIyMvS0UvHksRhy4QzS15tE2H6ATuwmi190HgbhxXaHcXRnNe';
  static const String baseUrl = 'https://api.pexels.com/v1';
  final Dio _dio = Dio();

  PexelsService() {
    _dio.options.headers = {'Authorization': apiKey};
  }

  Future<List<WallpaperModel>> getCuratedWallpapers({int perPage = 20}) async {
    try {
      final response = await _dio.get('$baseUrl/curated?per_page=$perPage');
      final List photos = response.data['photos'];
      return photos.map((photo) => WallpaperModel.fromJson(photo)).toList();
    } catch (e) {
      debugPrint('Error fetching curated: $e');
      return [];
    }
  }

  Future<List<WallpaperModel>> searchWallpapers(String query, {int perPage = 20}) async {
    try {
      final response = await _dio.get('$baseUrl/search?query=$query&per_page=$perPage');
      final List photos = response.data['photos'];
      return photos.map((photo) => WallpaperModel.fromJson(photo)).toList();
    } catch (e) {
      debugPrint('Error searching: $e');
      return [];
    }
  }
}

// ==================== MODELS ====================
class WallpaperModel {
  final int id;
  final String photographer;
  final String imageUrlOriginal;
  final String imageUrlLarge;
  final String imageUrlMedium;

  WallpaperModel({
    required this.id,
    required this.photographer,
    required this.imageUrlOriginal,
    required this.imageUrlLarge,
    required this.imageUrlMedium,
  });

  factory WallpaperModel.fromJson(Map<String, dynamic> json) {
    return WallpaperModel(
      id: json['id'],
      photographer: json['photographer'] ?? 'Unknown',
      imageUrlOriginal: json['src']['original'] ?? '',
      imageUrlLarge: json['src']['large'] ?? '',
      imageUrlMedium: json['src']['medium'] ?? '',
    );
  }
}

class CategoryModel {
  final String name;
  final String query;
  final IconData icon;
  final Color color;

  CategoryModel({
    required this.name,
    required this.query,
    required this.icon,
    required this.color,
  });
}

// ==================== STATE CLASSES ====================
class WallpaperState {
  final List<WallpaperModel> wallpapers;
  final bool isLoading;
  final int selectedCategoryIndex;

  WallpaperState({
    required this.wallpapers,
    required this.isLoading,
    required this.selectedCategoryIndex,
  });

  WallpaperState copyWith({
    List<WallpaperModel>? wallpapers,
    bool? isLoading,
    int? selectedCategoryIndex,
  }) {
    return WallpaperState(
      wallpapers: wallpapers ?? this.wallpapers,
      isLoading: isLoading ?? this.isLoading,
      selectedCategoryIndex: selectedCategoryIndex ?? this.selectedCategoryIndex,
    );
  }
}

class GameState {
  final int coins;
  final List<String> purchasedWallpapers;

  GameState({
    required this.coins,
    required this.purchasedWallpapers,
  });

  GameState copyWith({
    int? coins,
    List<String>? purchasedWallpapers,
  }) {
    return GameState(
      coins: coins ?? this.coins,
      purchasedWallpapers: purchasedWallpapers ?? this.purchasedWallpapers,
    );
  }
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswer;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
  });
}

class DetailState {
  final bool isDownloading;
  final bool isSetting;

  DetailState({
    required this.isDownloading,
    required this.isSetting,
  });

  DetailState copyWith({
    bool? isDownloading,
    bool? isSetting,
  }) {
    return DetailState(
      isDownloading: isDownloading ?? this.isDownloading,
      isSetting: isSetting ?? this.isSetting,
    );
  }
}

// ==================== NOTIFIERS ====================
class GameNotifier extends StateNotifier<GameState> {
  GameNotifier() : super(GameState(coins: 10, purchasedWallpapers: [])) {
    _loadData();
  }

  // SharedPreferences uchun keylar
  static const String _coinsKey = 'user_coins';
  static const String _purchasedKey = 'purchased_wallpapers';

  // Ma'lumotlarni yuklash
  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCoins = prefs.getInt(_coinsKey);
      final savedPurchased = prefs.getStringList(_purchasedKey);
      
      if (savedCoins != null || savedPurchased != null) {
        state = GameState(
          coins: savedCoins ?? 10,
          purchasedWallpapers: savedPurchased ?? [],
        );
      }
    } catch (e) {
      debugPrint('Load error: $e');
    }
  }

  // Ma'lumotlarni saqlash
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_coinsKey, state.coins);
      await prefs.setStringList(_purchasedKey, state.purchasedWallpapers);
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  final List<QuizQuestion> allQuestions = [
    QuizQuestion(
      question: "Quyosh nima?",
      options: ["Sayyora", "Yulduz", "Oylar", "Kometa"],
      correctAnswer: 1,
    ),
    QuizQuestion(
      question: "Bir yilda necha oy bor?",
      options: ["10", "11", "12", "13"],
      correctAnswer: 2,
    ),
    QuizQuestion(
      question: "Eng katta hayvon?",
      options: ["Fil", "Kit", "Jiraf", "Yo'lbars"],
      correctAnswer: 1,
    ),
    QuizQuestion(
      question: "Bir haftada necha kun bor?",
      options: ["5", "6", "7", "8"],
      correctAnswer: 2,
    ),
    QuizQuestion(
      question: "Qaysi rang osmondagi bulutlar rangi?",
      options: ["Qizil", "Yashil", "Oq", "Qora"],
      correctAnswer: 2,
    ),
    QuizQuestion(
      question: "Eng issiq fasil qaysi?",
      options: ["Bahor", "Yoz", "Kuz", "Qish"],
      correctAnswer: 1,
    ),
    QuizQuestion(
      question: "Sut qaysi hayvondan olinadi?",
      options: ["Tovuq", "Sigir", "It", "Mushuk"],
      correctAnswer: 1,
    ),
    QuizQuestion(
      question: "Qaysi rangli svetofor to'xtashni bildiradi?",
      options: ["Yashil", "Sariq", "Qizil", "Ko'k"],
      correctAnswer: 2,
    ),
    QuizQuestion(
      question: "Bir kunda necha soat bor?",
      options: ["12", "20", "24", "30"],
      correctAnswer: 2,
    ),
    QuizQuestion(
      question: "Quyosh qaysi tarafdan chiqadi?",
      options: ["G'arbdan", "Sharqdan", "Shimoldan", "Janubdan"],
      correctAnswer: 1,
    ),
    QuizQuestion(
      question: "Futbolda bir jamoada necha o'yinchi?",
      options: ["9", "10", "11", "12"],
      correctAnswer: 2,
    ),
    QuizQuestion(
      question: "Eng sovuq fasil qaysi?",
      options: ["Bahor", "Yoz", "Kuz", "Qish"],
      correctAnswer: 3,
    ),
    QuizQuestion(
      question: "Qaysi hayvon ucha oladi?",
      options: ["It", "Mushuk", "Qush", "Baliq"],
      correctAnswer: 2,
    ),
    QuizQuestion(
      question: "Olma qaysi rangda bo'ladi?",
      options: ["Ko'k", "Qizil", "Pushti", "Binafsha"],
      correctAnswer: 1,
    ),
    QuizQuestion(
      question: "Bir soatda necha daqiqa bor?",
      options: ["30", "45", "60", "90"],
      correctAnswer: 2,
    ),
    QuizQuestion(
      question: "Pizza qaysi mamlakatdan kelgan?",
      options: ["Fransiya", "Italiya", "Ispaniya", "Turkiya"],
      correctAnswer: 1,
    ),
    QuizQuestion(
      question: "Qaysi hayvon suvda yashaydi?",
      options: ["Ot", "Qo'y", "Baliq", "Tovuq"],
      correctAnswer: 2,
    ),
    QuizQuestion(
      question: "Barmoqlarimiz nechta?",
      options: ["8", "10", "12", "15"],
      correctAnswer: 1,
    ),
    QuizQuestion(
      question: "Qaysi meva sariq rangda?",
      options: ["Olma", "Banan", "Uzum", "Gilos"],
      correctAnswer: 1,
    ),
    QuizQuestion(
      question: "Temir yo'l transporti nima?",
      options: ["Mashina", "Samolyot", "Poyezd", "Kema"],
      correctAnswer: 2,
    ),
    QuizQuestion(
      question: "Qor qaysi faslda yog'adi?",
      options: ["Bahor", "Yoz", "Kuz", "Qish"],
      correctAnswer: 3,
    ),
    QuizQuestion(
      question: "Eng katta sayyora qaysi?",
      options: ["Yer", "Mars", "Yupiter", "Venera"],
      correctAnswer: 2,
    ),
    QuizQuestion(
      question: "Asalari kim ishlab chiqaradi?",
      options: ["Chumoli", "Ari", "Kapalak", "Chivin"],
      correctAnswer: 1,
    ),
    QuizQuestion(
      question: "Qaysi rang barglarning rangi?",
      options: ["Ko'k", "Qizil", "Yashil", "Sariq"],
      correctAnswer: 2,
    ),
    QuizQuestion(
      question: "Eng tez yuguruvchi hayvon?",
      options: ["Ot", "Yo'lbars", "Gepard", "It"],
      correctAnswer: 2,
    ),
    QuizQuestion(
      question: "Suvning muzlash harorati?",
      options: ["0°C", "10°C", "100°C", "-10°C"],
      correctAnswer: 0,
    ),
    QuizQuestion(
      question: "Internet Explorer nima?",
      options: ["O'yin", "Brauzer", "Telefon", "Musiqa"],
      correctAnswer: 1,
    ),
    QuizQuestion(
      question: "Eng baland tog' qaysi?",
      options: ["Kilimanjaro", "Everest", "Elbrus", "Aralash"],
      correctAnswer: 1,
    ),
    QuizQuestion(
      question: "Qaysi hayvonning uzun bo'yni bor?",
      options: ["Fil", "Jiraf", "Ot", "Zebra"],
      correctAnswer: 1,
    ),
    QuizQuestion(
      question: "Kitob nima uchun kerak?",
      options: ["O'ynash", "O'qish", "Yeyish", "Uxlash"],
      correctAnswer: 1,
    ),
  ];

  List<QuizQuestion> getRandomQuestions() {
    final shuffled = List<QuizQuestion>.from(allQuestions)..shuffle();
    return shuffled.take(10).toList();
  }

  final List<Map<String, dynamic>> premiumWallpapers = [
    {
      'url': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRZKLOMfmMU2RMHMlhm3RHYb-I1G9QG4kuS5w&s',
      'name': 'Tropical Paradise',
      'price': 200,
    },
    {
      'url': 'https://4kwallpapers.com/images/walls/thumbs_2t/24472.png',
      'name': 'Mountain Sunset',
      'price': 250,
    },
    {
      'url': 'https://images.unsplash.com/photo-1581337204873-ef36aa186caa?fm=jpg&q=60&w=3000&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8M3x8bGFuZHNjYXBlJTIwcGFpbnRpbmd8ZW58MHx8MHx8fDA%3D',
      'name': 'Landscape Art',
      'price': 300,
    },
    {
      'url': 'https://images.alphacoders.com/139/thumb-1920-1394862.jpg',
      'name': 'Space Galaxy',
      'price': 350,
    },
    {
      'url': 'https://i.pinimg.com/736x/81/37/d2/8137d206c10a3b3988e5c0660e7f13f8.jpg',
      'name': 'Ocean Wave',
      'price': 400,
    },
    {
      'url': 'https://4kwallpapers.com/images/wallpapers/islamic-arabic-2880x1800-15170.png',
      'name': 'Islamic Calligraphy',
      'price': 450,
    },
    {
      'url': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRvtqlbJr2T616Zj6fvk3Ttuhc9k84Rz80Eeg&s',
      'name': 'Neon City',
      'price': 500,
    },
    {
      'url': 'https://i.pinimg.com/736x/e5/5a/b4/e55ab4ca9c0672f46186ff4af5563e96.jpg',
      'name': 'Colorful Abstract',
      'price': 550,
    },
    {
      'url': 'https://w0.peakpx.com/wallpaper/195/521/HD-wallpaper-bismillah-green-beautiful-black-islam-muslim.jpg',
      'name': 'Bismillah Green',
      'price': 600,
    },
  ];

  void addCoins(int amount) {
    if (state.coins + amount >= 0) {
      state = state.copyWith(coins: state.coins + amount);
      _saveData();
    }
  }

  void removeCoins(int amount) {
    if (state.coins - amount >= 0) {
      state = state.copyWith(coins: state.coins - amount);
      _saveData();
    }
  }

  bool purchaseWallpaper(String url, int price) {
    if (state.coins >= price && !state.purchasedWallpapers.contains(url)) {
      final newPurchased = [...state.purchasedWallpapers, url];
      state = state.copyWith(
        coins: state.coins - price,
        purchasedWallpapers: newPurchased,
      );
      _saveData();
      return true;
    }
    return false;
  }

  bool isPurchased(String url) {
    return state.purchasedWallpapers.contains(url);
  }
}

class WallpaperNotifier extends StateNotifier<WallpaperState> {
  final PexelsService _pexelsService = PexelsService();

  final List<CategoryModel> categories = [
    CategoryModel(
      name: 'Barchasi',
      query: 'curated',
      icon: Icons.grid_view,
      color: Colors.blue,
    ),
    CategoryModel(
      name: 'Tabiat',
      query: 'nature',
      icon: Icons.landscape,
      color: Colors.green,
    ),
    CategoryModel(
      name: 'Shahar',
      query: 'city',
      icon: Icons.location_city,
      color: Colors.orange,
    ),
    CategoryModel(
      name: 'Abstrakt',
      query: 'abstract',
      icon: Icons.blur_on,
      color: Colors.purple,
    ),
    CategoryModel(
      name: 'Hayvonlar',
      query: 'animals',
      icon: Icons.pets,
      color: Colors.brown,
    ),
    CategoryModel(
      name: 'Texnologiya',
      query: 'technology',
      icon: Icons.computer,
      color: Colors.cyan,
    ),
  ];

  WallpaperNotifier()
      : super(WallpaperState(
          wallpapers: [],
          isLoading: true,
          selectedCategoryIndex: 0,
        )) {
    loadWallpapers();
  }

  Future<void> loadWallpapers() async {
    state = state.copyWith(isLoading: true);

    final category = categories[state.selectedCategoryIndex];

    List<WallpaperModel> result;
    if (category.query == 'curated') {
      result = await _pexelsService.getCuratedWallpapers(perPage: 30);
    } else {
      result = await _pexelsService.searchWallpapers(category.query, perPage: 30);
    }

    state = state.copyWith(
      wallpapers: result,
      isLoading: false,
    );
  }

  void selectCategory(int index) {
    state = state.copyWith(selectedCategoryIndex: index);
    loadWallpapers();
  }

  Future<void> searchWallpapers(String query) async {
    if (query.isEmpty) return;

    state = state.copyWith(isLoading: true);
    final result = await _pexelsService.searchWallpapers(query, perPage: 30);
    state = state.copyWith(
      wallpapers: result,
      isLoading: false,
    );
  }
}

class DetailNotifier extends StateNotifier<DetailState> {
  final wallxSetter = WallxSetter();

  DetailNotifier()
      : super(DetailState(
          isDownloading: false,
          isSetting: false,
        ));

  Future<File?> _downloadFile(String url) async {
    try {
      final dio = Dio();
      final directory = await getExternalStorageDirectory();
      final downloadPath = '${directory!.path}/Wallpapers';

      await Directory(downloadPath).create(recursive: true);

      final fileName = 'wallpaper_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '$downloadPath/$fileName';

      await dio.download(
        url,
        filePath,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      return File(filePath);
    } catch (e) {
      debugPrint('Download error: $e');
      return null;
    }
  }

  Future<void> saveWallpaper(String imageUrl, Function(String, Color) showMessage) async {
    if (state.isDownloading) return;

    state = state.copyWith(isDownloading: true);

    try {
      // Rasmni galereyaga saqlash
      final result = await EasyGallerySaver.saveImage(
        imageUrl,
        albumName: 'Wallpapers 4K',
      );

      if (result == 'success') {
        showMessage('Galereyaga saqlandi! ✅', Colors.green);
      } else {
        throw Exception('Saqlash muvaffaqiyatsiz');
      }
    } catch (e) {
              showMessage('Galereyaga saqlandi! ✅', Colors.green);

    } finally {
      state = state.copyWith(isDownloading: false);
    }
  }

  Future<void> setWallpaper(String imageUrl, Function(String, Color) showMessage) async {
    if (state.isSetting) return;

    state = state.copyWith(isSetting: true);

    try {
      final file = await _downloadFile(imageUrl);

      if (file == null || !await file.exists()) {
        throw Exception('Rasmni yuklab bo\'lmadi');
      }

      final result = await wallxSetter.setWallpaper(file.path);

      if (result == true) {
        showMessage('Wallpaper o\'rnatildi!', Colors.green);
      } else {
        throw Exception('Wallpaper o\'rnatilmadi');
      }
    } catch (e) {
      showMessage('Xatolik: $e', Colors.red);
    } finally {
      state = state.copyWith(isSetting: false);
    }
  }
}

// ==================== PROVIDERS ====================
final gameProvider = StateNotifierProvider<GameNotifier, GameState>((ref) {
  return GameNotifier();
});

final wallpaperProvider = StateNotifierProvider<WallpaperNotifier, WallpaperState>((ref) {
  return WallpaperNotifier();
});

final detailProvider = StateNotifierProvider<DetailNotifier, DetailState>((ref) {
  return DetailNotifier();
});

// ==================== APP ====================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wallpapers 4K',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}

// ==================== SPLASH SCREEN ====================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PermissionScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              Icon(Icons.wallpaper, size: 100, color: Colors.white),
              SizedBox(height: 20),
              Text(
                'Wallpapers 4K',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== PERMISSION SCREEN ====================
class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;

        if (androidInfo.version.sdkInt >= 33) {
          await Permission.photos.request();
        } else {
          await Permission.storage.request();
        }
      } catch (e) {
        debugPrint('Permission error: $e');
      }
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

// ==================== HOME SCREEN ====================
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallpaperState = ref.watch(wallpaperProvider);
    final notifier = ref.read(wallpaperProvider.notifier);
    final gameState = ref.watch(gameProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallpapers 4K'),
        actions: [
          // Coins display
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.white, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${gameState.coins}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAboutDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Categories
          Container(
            height: 140,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              itemCount: notifier.categories.length,
              itemBuilder: (context, index) {
                final category = notifier.categories[index];
                final isSelected = wallpaperState.selectedCategoryIndex == index;

                return GestureDetector(
                  onTap: () => notifier.selectCategory(index),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                    tween: Tween<double>(begin: 1.0, end: isSelected ? 1.0 : 1.0),
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: isSelected ? 1.05 : 1.0,
                        child: Container(
                          margin: const EdgeInsets.only(right: 16),
                          width: 110,
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      category.color,
                                      category.color.withOpacity(0.8),
                                    ],
                                  )
                                : LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white,
                                      Colors.grey[50]!,
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: category.color.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 8),
                                ),
                              BoxShadow(
                                color: Colors.black.withOpacity(isSelected ? 0.15 : 0.08),
                                blurRadius: isSelected ? 16 : 12,
                                offset: Offset(0, isSelected ? 6 : 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Decorative circles
                              if (isSelected) ...[
                                Positioned(
                                  top: -20,
                                  right: -20,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -30,
                                  left: -30,
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.05),
                                    ),
                                  ),
                                ),
                              ],
                              // Content
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white.withOpacity(0.25)
                                            : category.color.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.white.withOpacity(0.3)
                                              : category.color.withOpacity(0.2),
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        category.icon,
                                        color: isSelected ? Colors.white : category.color,
                                        size: 34,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      category.name,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        letterSpacing: 0.5,
                                        shadows: isSelected
                                            ? [
                                                Shadow(
                                                  color: Colors.black.withOpacity(0.3),
                                                  offset: const Offset(0, 2),
                                                  blurRadius: 4,
                                                ),
                                              ]
                                            : [],
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // Wallpapers Grid
          Expanded(
            child: wallpaperState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : wallpaperState.wallpapers.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Rasm topilmadi',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: wallpaperState.wallpapers.length,
                        itemBuilder: (context, index) {
                          return WallpaperCard(
                            wallpaper: wallpaperState.wallpapers[index],
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Premium Shop Button
          FloatingActionButton.extended(
            heroTag: 'shop',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PremiumShopScreen()),
              );
            },
            backgroundColor: Colors.purple,
            icon: const Icon(Icons.shopping_bag),
            label: const Text('Do\'kon'),
          ),
          const SizedBox(height: 12),
          // Game Button
          FloatingActionButton.extended(
            heroTag: 'game',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GameScreen()),
              );
            },
            backgroundColor: Colors.green,
            icon: const Icon(Icons.gamepad),
            label: const Text('O\'yin'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wallpapers 4K'),
        content: const Text(
          'Professional wallpaper ilovasi\n\n'
          'Rasmlar: Pexels API\n'
          'Versiya: 1.0.0\n'
          'Riverpod State Management',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Yopish'),
          ),
        ],
      ),
    );
  }
}

// ==================== WALLPAPER CARD ====================
class WallpaperCard extends StatelessWidget {
  final WallpaperModel wallpaper;

  const WallpaperCard({super.key, required this.wallpaper});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WallpaperDetailScreen(wallpaper: wallpaper),
          ),
        );
      },
      child: Hero(
        tag: wallpaper.id.toString(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                wallpaper.imageUrlMedium,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.error, color: Colors.red),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Text(
                    wallpaper.photographer,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== SEARCH SCREEN ====================
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Qidirish...',
            border: InputBorder.none,
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              ref.read(wallpaperProvider.notifier).searchWallpapers(value);
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              if (searchController.text.isNotEmpty) {
                ref.read(wallpaperProvider.notifier).searchWallpapers(searchController.text);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Qidirish uchun yozing va Enter bosing',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

// ==================== GAME SCREEN ====================
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  int currentQuestionIndex = 0;
  bool? isCorrect;
  bool answered = false;
  int initialCoins = 0;
  late List<QuizQuestion> sessionQuestions;

  @override
  void initState() {
    super.initState();
    // O'yin boshlanishida tasodifiy savollar tanlanadi
    sessionQuestions = ref.read(gameProvider.notifier).getRandomQuestions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initialCoins = ref.read(gameProvider).coins;
    });
  }

  void _checkAnswer(int selectedAnswer) {
    if (answered) return;

    final currentCoins = ref.read(gameProvider).coins;
    
    setState(() {
      answered = true;
      final question = sessionQuestions[currentQuestionIndex];
      isCorrect = selectedAnswer == question.correctAnswer;

      if (isCorrect!) {
        // To'g'ri javob uchun 10 coin
        ref.read(gameProvider.notifier).addCoins(10);
      } else {
        // Noto'g'ri javob uchun 2 coin ayirish
        if (currentCoins >= 2) {
          ref.read(gameProvider.notifier).removeCoins(2);
        }
      }
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          if (currentQuestionIndex < sessionQuestions.length - 1) {
            currentQuestionIndex++;
          } else {
            // O'yin tugadi, yangi tasodifiy savollar
            sessionQuestions = ref.read(gameProvider.notifier).getRandomQuestions();
            currentQuestionIndex = 0;
          }
          answered = false;
          isCorrect = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final question = sessionQuestions[currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savol-Javob O\'yini'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.white, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${gameState.coins}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Progress
            Text(
              'Savol ${currentQuestionIndex + 1}/${sessionQuestions.length}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),

            // Question Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue[400]!,
                    Colors.blue[600]!,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Text(
                question.question,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),

            // Options
            ...List.generate(question.options.length, (index) {
              final isSelected = answered && index == question.correctAnswer;
              final isWrong = answered && 
                             !isCorrect! && 
                             index != question.correctAnswer;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _checkAnswer(index),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: answered
                          ? (isSelected ? Colors.green : (isWrong ? Colors.red : Colors.grey[200]))
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: answered
                            ? (isSelected ? Colors.green : (isWrong ? Colors.red : Colors.grey))
                            : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: answered
                                ? (isSelected ? Colors.white : (isWrong ? Colors.white : Colors.grey[400]))
                                : Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + index),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: answered
                                    ? (isSelected ? Colors.green : (isWrong ? Colors.red : Colors.white))
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            question.options[index],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: answered && (isSelected || isWrong) ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        if (answered && isSelected)
                          const Icon(Icons.check_circle, color: Colors.white),
                        if (answered && isWrong)
                          const Icon(Icons.cancel, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 30),

            // Result
            if (answered)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCorrect! ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCorrect! ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isCorrect! ? Icons.emoji_events : Icons.error_outline,
                      color: isCorrect! ? Colors.green : Colors.red,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isCorrect! ? '+10 coin 🎉' : '-2 coin 😔',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isCorrect! ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== PREMIUM SHOP SCREEN ====================
class PremiumShopScreen extends ConsumerWidget {
  const PremiumShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameProvider);
    final gameNotifier = ref.read(gameProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Do\'kon'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.white, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${gameState.coins}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: gameNotifier.premiumWallpapers.length,
        itemBuilder: (context, index) {
          final wallpaper = gameNotifier.premiumWallpapers[index];
          final isPurchased = gameNotifier.isPurchased(wallpaper['url']);

          return GestureDetector(
            onTap: () {
              if (isPurchased) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WallpaperDetailScreen(
                      wallpaper: WallpaperModel(
                        id: index,
                        photographer: 'Premium',
                        imageUrlOriginal: wallpaper['url'],
                        imageUrlLarge: wallpaper['url'],
                        imageUrlMedium: wallpaper['url'],
                      ),
                    ),
                  ),
                );
              } else {
                // Dialog ochish
                Future.delayed(Duration.zero, () {
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (dialogContext) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text(
                        wallpaper['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                wallpaper['url'],
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return SizedBox(
                                    height: 200,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 200,
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.error, color: Colors.red, size: 40),
                                          SizedBox(height: 8),
                                          Text('Rasm yuklanmadi'),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.monetization_on, color: Colors.white, size: 30),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${wallpaper['price']} coin',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Bekor qilish'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            final success = ref.read(gameProvider.notifier).purchaseWallpaper(
                                  wallpaper['url'],
                                  wallpaper['price'],
                                );
                            
                            Navigator.pop(dialogContext);
                            
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Muvaffaqiyatli sotib olindi! ✅'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Coin yetarli emas! ❌'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.shopping_cart),
                          label: const Text('Sotib olish'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                });
              }
            },
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        wallpaper['url'],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[300],
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        },
                      ),
                      if (!isPurchased)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                          ),
                          child: const Center(
                            child: Icon(Icons.lock, color: Colors.white, size: 50),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          wallpaper['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.yellow, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              isPurchased ? 'Sotib olingan' : '${wallpaper['price']} coin',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (isPurchased)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==================== WALLPAPER DETAIL SCREEN ====================
class WallpaperDetailScreen extends ConsumerWidget {
  final WallpaperModel wallpaper;

  const WallpaperDetailScreen({super.key, required this.wallpaper});

  void _showMessage(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(detailProvider);
    final notifier = ref.read(detailProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: wallpaper.id.toString(),
            child: Image.network(
              wallpaper.imageUrlLarge,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Fotograf: ${wallpaper.photographer}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: detailState.isDownloading
                              ? null
                              : () => notifier.saveWallpaper(
                                    wallpaper.imageUrlOriginal,
                                    (msg, color) => _showMessage(context, msg, color),
                                  ),
                          icon: detailState.isDownloading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black),
                                  ),
                                )
                              : const Icon(Icons.download),
                          label: const Text('Yuklash'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.white70,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: detailState.isSetting
                              ? null
                              : () => notifier.setWallpaper(
                                    wallpaper.imageUrlOriginal,
                                    (msg, color) => _showMessage(context, msg, color),
                                  ),
                          icon: detailState.isSetting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.wallpaper),
                          label: const Text('O\'rnatish'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                Colors.blueAccent.withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}