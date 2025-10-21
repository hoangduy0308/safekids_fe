enum Environment { local, dev, production }

class EnvironmentConfig {
  // 🧭 CHỌN MÔI TRƯỜNG HIỆN TẠI
  static const Environment currentEnvironment = Environment.local;

  // ⚙️ CẤU HÌNH CHO TỪNG MÔI TRƯỜNG
  static const Map<Environment, Map<String, String>> _config = {
    Environment.local: {
      'apiUrl': 'https://fidgetingly-unrefreshed-jeramy.ngrok-free.dev/api',
      'socketUrl': 'https://fidgetingly-unrefreshed-jeramy.ngrok-free.dev',
      'name': 'Local (Ngrok)',
    },
    Environment.dev: {
      'apiUrl':
          'https://fidgetingly-unrefreshed-jeramy.ngrok-free.dev/api', // có thể dùng chung với local khi test
      'socketUrl': 'https://fidgetingly-unrefreshed-jeramy.ngrok-free.dev',
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

  // 🔍 Tiện ích kiểm tra môi trường
  static bool get isProduction => currentEnvironment == Environment.production;
  static bool get isLocal => currentEnvironment == Environment.local;
  static bool get isDev => currentEnvironment == Environment.dev;
}
