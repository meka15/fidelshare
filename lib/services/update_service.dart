import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/update_info.dart';
import 'supabase_service.dart';

class UpdateService {
  static Future<AppUpdateInfo?> checkUpdate() async {
    try {
      final response = await SupabaseService.client
          .from('app_version')
          .select()
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final updateInfo = AppUpdateInfo.fromJson(response);
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isUpdateAvailable(currentVersion, updateInfo.latestVersion)) {
        return updateInfo;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  static bool isForcedUpdate(String currentVersion, String minVersion) {
    return _isUpdateAvailable(currentVersion, minVersion);
  }

  static bool _isUpdateAvailable(String current, String target) {
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> targetParts = target.split('.').map(int.parse).toList();

    for (int i = 0; i < targetParts.length; i++) {
      int c = i < currentParts.length ? currentParts[i] : 0;
      int t = targetParts[i];
      if (t > c) return true;
      if (t < c) return false;
    }
    return false;
  }
}
