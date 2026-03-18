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
    if (current.trim() == target.trim()) return false;
    
    try {
      // Strip build numbers and trim whitespace (e.g., 1.0.2+3 -> 1.0.2)
      String cleanCurrent = current.split('+')[0].trim();
      String cleanTarget = target.split('+')[0].trim();

      List<int> currentParts = cleanCurrent.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
      List<int> targetParts = cleanTarget.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();

      int maxLength = currentParts.length > targetParts.length ? currentParts.length : targetParts.length;

      for (int i = 0; i < maxLength; i++) {
        int c = i < currentParts.length ? currentParts[i] : 0;
        int t = i < targetParts.length ? targetParts[i] : 0;
        
        if (t > c) return true;
        if (t < c) return false;
      }

      // If main versions are exact matches, check build numbers (+ sign)
      int buildCurrent = 0;
      int buildTarget = 0;
      if (current.contains('+')) {
        buildCurrent = int.tryParse(current.split('+')[1]) ?? 0;
      }
      if (target.contains('+')) {
        buildTarget = int.tryParse(target.split('+')[1]) ?? 0;
      }
      return buildTarget > buildCurrent;
    } catch (_) {}
    return false;
  }
}
