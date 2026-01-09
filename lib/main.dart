import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:wallx_setter/wallx_setter.dart';

void main() {
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
      final file = await _downloadFile(imageUrl);

      if (file != null && await file.exists()) {
        showMessage('Rasm saqlandi', Colors.green);
      } else {
        throw Exception('Fayl yuklanmadi');
      }
    } catch (e) {
      showMessage('Xatolik: $e', Colors.red);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallpapers 4K'),
        actions: [
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
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: notifier.categories.length,
              itemBuilder: (context, index) {
                final category = notifier.categories[index];
                final isSelected = wallpaperState.selectedCategoryIndex == index;

                return GestureDetector(
                  onTap: () => notifier.selectCategory(index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? category.color : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          category.icon,
                          color: isSelected ? Colors.white : Colors.black87,
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
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