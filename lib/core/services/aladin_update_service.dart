import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// Play Store üzerinden sürüm kontrolü yapar.
  /// Not: Google Play Store'un resmi bir "sürüm çekme" API'si yoktur.
  /// Genellikle bir backend üzerinden veya scraping ile yapılır.
  /// Bu örnekte, geliştiricinin kendi sunucusundaki bir JSON dosyasını kontrol etmesi önerilir.
  Future<Map<String, dynamic>?> checkUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;
      final currentBuildNumber = int.tryParse(info.buildNumber) ?? 0;

      // TODO: Gerçek bir API URL'si buraya eklenmeli. 
      // Örnek: 'https://raw.githubusercontent.com/user/repo/main/version.json'
      // JSON formatı: {"version": "2.2.1", "buildNumber": 27, "url": "https://play.google.com/..."}
      
      // Şimdilik Play Store sayfasından basit bir scraping denemesi (her zaman çalışmayabilir)
      final packageName = info.packageName;
      final url = Uri.parse('https://play.google.com/store/apps/details?id=$packageName&hl=en');
      
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final html = response.body;
        
        // Play Store HTML yapısı içinde sürüm numarasını arayalım
        // Not: Bu kısım Google'ın tasarım değişikliklerine göre bozulabilir.
        // Daha güvenli yol kendi sunucunuzdur.
        final versionRegex = RegExp(r'\[\[\["([0-9]+\.[0-9]+\.[0-9]+)"\]\]');
        final match = versionRegex.firstMatch(html);
        
        if (match != null) {
          final storeVersion = match.group(1);
          if (storeVersion != null && _isVersionGreater(storeVersion, currentVersion)) {
            return {
              'hasUpdate': true,
              'version': storeVersion,
              'url': 'https://play.google.com/store/apps/details?id=$packageName',
            };
          }
        }
      }
    } catch (e) {
      print('Update check error: $e');
    }
    return {'hasUpdate': false};
  }

  bool _isVersionGreater(String newVersion, String currentVersion) {
    List<int> newV = newVersion.split('.').map(int.parse).toList();
    List<int> currV = currentVersion.split('.').map(int.parse).toList();
    
    for (var i = 0; i < newV.length; i++) {
      if (i >= currV.length) return true;
      if (newV[i] > currV[i]) return true;
      if (newV[i] < currV[i]) return false;
    }
    return false;
  }
}
