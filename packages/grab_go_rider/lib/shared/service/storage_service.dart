import 'cache_service.dart';

class StorageService {
  static Future<bool> isFirstLaunch() async {
    return CacheService.isFirstLaunch();
  }

  static Future<void> setFirstLaunchComplete() async {
    await CacheService.setFirstLaunchComplete();
  }
}
