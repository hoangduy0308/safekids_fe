enum Environment { local, dev, production }

class EnvironmentConfig {
  // 🧭 CHỌN MÔI TRƯỜNG HIỆN TẠI
  static const Environment currentEnvironment = Environment.local;

  // ⚙️ CẤU HÌNH CHO TỪNG MÔI TRƯỜNG
  static const String _mapTilerKey = String.fromEnvironment('MAPTILER_API_KEY', defaultValue: '');

  static const Map<Environment, Map<String, String>> _config = {
    Environment.local: {
      'apiUrl': 'https://153e188a118c.ngrok-free.app/api',
      'socketUrl': 'https://153e188a118c.ngrok-free.app',
      'name': 'Local (Ngrok)',
    },
    Environment.dev: {
      'apiUrl': 'https://153e188a118c.ngrok-free.app/api', // có thể dùng chung với local khi test
      'socketUrl': 'https://153e188a118c.ngrok-free.app',
      'name': 'Development (Ngrok)',
    },
    Environment.production: {
      'apiUrl':
          'https://safekids-backend-ggfdezcpc4cgcnfx.southeastasia-01.azurewebsites.net/api',
      'socketUrl':
          'https://safekids-backend-ggfdezcpc4cgcnfx.southeastasia-01.azurewebsites.net',
      'name': 'Production (Azure)',
    },
  };

  // 🔗 GETTERS – tự động lấy URL theo môi trường đang chọn
  static String get apiUrl => _config[currentEnvironment]!['apiUrl']!;
  static String get socketUrl => _config[currentEnvironment]!['socketUrl']!;
  static String get environmentName => _config[currentEnvironment]!['name']!;
  static String get mapTilerApiKey => _mapTilerKey;

  // 🔍 Tiện ích kiểm tra môi trường
  static bool get isProduction => currentEnvironment == Environment.production;
  static bool get isLocal => currentEnvironment == Environment.local;
  static bool get isDev => currentEnvironment == Environment.dev;
}


