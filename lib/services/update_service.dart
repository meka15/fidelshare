import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/update_info.dart';
import 'supabase_service.dart';

class UpdateService {
  static Future<AppUpdateInfo?> getLatestVersion() async {
    try {
      final response = await SupabaseService.client
          .from('app_version')
          .select()
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return AppUpdateInfo.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  static Future<AppUpdateInfo?> checkUpdate() async {
    try {
      final updateInfo = await getLatestVersion();
      if (updateInfo == null) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (isUpdateAvailable(currentVersion, updateInfo.latestVersion)) {
        return updateInfo;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  static bool isForcedUpdate(String currentVersion, String minVersion) {
    return isUpdateAvailable(currentVersion, minVersion);
  }

  static bool isUpdateAvailable(String current, String target) {
    try {
      List<int> currentParts = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
      List<int> targetParts = target.split('.').map((s) => int.tryParse(s) ?? 0).toList();

      for (int i = 0; i < targetParts.length; i++) {
        int c = i < currentParts.length ? currentParts[i] : 0;
        int t = targetParts[i];
        if (t > c) return true;
        if (t < c) return false;
      }
    } catch (_) {}
    return false;
  }
}
