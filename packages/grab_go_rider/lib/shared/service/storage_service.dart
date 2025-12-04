import 'package:grab_go_shared/shared/services/cache_service.dart';

class StorageService {
  static Future<bool> isFirstLaunch() async {
    return CacheService.isFirstLaunch();
  }

  static Future<void> setFirstLaunchComplete() async {
    await CacheService.setFirstLaunchComplete();
  }
}
