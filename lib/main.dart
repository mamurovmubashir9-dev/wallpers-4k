import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
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
  runApp(const MyApp());
}

// ==================== APP ====================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
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
    Get.off(() => const PermissionScreen(), transition: Transition.fade);
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
    Get.off(() => const HomeScreen(), transition: Transition.fadeIn);
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

// ==================== HOME CONTROLLER ====================
class HomeController extends GetxController {
  final wallpapers = <String>[].obs;
  final isLoading = true.obs;
  final searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadWallpapers();
  }

  Future<void> loadWallpapers() async {
    isLoading.value = true;
    await Future.delayed(const Duration(seconds: 1));
    
    wallpapers.value = List.generate(
      30,
      (index) => 'https://picsum.photos/seed/${index + 100}/600/900',
    );
    
    isLoading.value = false;
  }

  List<String> get filteredWallpapers {
    if (searchQuery.value.isEmpty) {
      return wallpapers;
    }
    return wallpapers
        .where((w) => w.toLowerCase().contains(searchQuery.value.toLowerCase()))
        .toList();
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  void clearSearch() {
    searchQuery.value = '';
  }
}

// ==================== HOME SCREEN ====================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.put(HomeController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallpapers 4K'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Get.to(() => const SearchScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAboutDialog(context),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final wallpapers = controller.filteredWallpapers;

        if (wallpapers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Rasm topilmadi',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: wallpapers.length,
          itemBuilder: (context, index) {
            return _WallpaperCard(imageUrl: wallpapers[index]);
          },
        );
      }),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wallpapers 4K'),
        content: const Text(
          'Professional wallpaper ilovasi\n\n'
          'Versiya: 1.0.0\n'
          'GetX State Management\n'
          'WallX Setter Plugin',
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
class _WallpaperCard extends StatelessWidget {
  final String imageUrl;

  const _WallpaperCard({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.to(
        () => WallpaperDetailScreen(imageUrl: imageUrl),
        transition: Transition.zoom,
      ),
      child: Hero(
        tag: imageUrl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUrl,
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
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
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
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.find();
    final TextEditingController searchController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Qidirish...',
            border: InputBorder.none,
          ),
          onChanged: (value) => controller.setSearchQuery(value),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              searchController.clear();
              controller.clearSearch();
            },
          ),
        ],
      ),
      body: Obx(() {
        final wallpapers = controller.filteredWallpapers;

        if (controller.searchQuery.value.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Qidirish uchun yozing',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        if (wallpapers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Natija topilmadi',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: wallpapers.length,
          itemBuilder: (context, index) {
            return _WallpaperCard(imageUrl: wallpapers[index]);
          },
        );
      }),
    );
  }
}

// ==================== WALLPAPER DETAIL CONTROLLER ====================
class WallpaperDetailController extends GetxController {
  final wallxSetter = WallxSetter();
  final isDownloading = false.obs;
  final isSetting = false.obs;

  Future<File?> downloadFile(String url) async {
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

  Future<void> saveWallpaper(String imageUrl) async {
    if (isDownloading.value) return;

    isDownloading.value = true;

    try {
      final file = await downloadFile(imageUrl);

      if (file != null && await file.exists()) {
        Get.snackbar(
          'Muvaffaqiyatli',
          'Rasm saqlandi: ${file.path}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      } else {
        throw Exception('Fayl yuklanmadi');
      }
    } catch (e) {
      Get.snackbar(
        'Xatolik',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isDownloading.value = false;
    }
  }

  Future<void> setWallpaper(String imageUrl) async {
    if (isSetting.value) return;

    isSetting.value = true;

    try {
      final file = await downloadFile(imageUrl);

      if (file == null || !await file.exists()) {
        throw Exception('Rasmni yuklab bo\'lmadi');
      }

      final result = await wallxSetter.setWallpaper(file.path);

      if (result == true) {
        Get.snackbar(
          'Muvaffaqiyatli',
          'Wallpaper o\'rnatildi!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      } else {
        throw Exception('Wallpaper o\'rnatilmadi');
      }
    } catch (e) {
      Get.snackbar(
        'Xatolik',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isSetting.value = false;
    }
  }
}

// ==================== WALLPAPER DETAIL SCREEN ====================
class WallpaperDetailScreen extends StatelessWidget {
  final String imageUrl;

  const WallpaperDetailScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final WallpaperDetailController controller =
        Get.put(WallpaperDetailController());

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
            onPressed: () => Get.back(),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: imageUrl,
            child: Image.network(
              imageUrl,
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
              height: 200,
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
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Obx(() => Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: controller.isDownloading.value
                            ? null
                            : () => controller.saveWallpaper(imageUrl),
                        icon: controller.isDownloading.value
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
                        onPressed: controller.isSetting.value
                            ? null
                            : () => controller.setWallpaper(imageUrl),
                        icon: controller.isSetting.value
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
                )),
          ),
        ],
      ),
    );
  }
}