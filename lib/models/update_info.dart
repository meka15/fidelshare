class AppUpdateInfo {
  final String latestVersion;
  final String minVersion;
  final String updateUrl;
  final String? releaseNotes;

  AppUpdateInfo({
    required this.latestVersion,
    required this.minVersion,
    required this.updateUrl,
    this.releaseNotes,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersion: json['latest_version'] ?? '1.0.0',
      minVersion: json['min_version'] ?? '1.0.0',
      updateUrl: json['update_url'] ?? '',
      releaseNotes: json['release_notes'],
    );
  }
}
