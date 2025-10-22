enum Environment { local, dev, production }

class EnvironmentConfig {

  static const Environment currentEnvironment = Environment.local;


  static const String _mapTilerKey = String.fromEnvironment(
    'MAPTILER_API_KEY',
    defaultValue: '',
  );

  static const Map<Environment, Map<String, String>> _config = {
    Environment.local: {
      'apiUrl': 'https://77a20a314989.ngrok-free.app/api',
      'socketUrl': 'https://77a20a314989.ngrok-free.app',
      'name': 'Local (Ngrok)',
      'mapTilerKey': '9QLr4F8rSTmO8Rl9c4Dl',
    },
    Environment.dev: {
      'apiUrl': '/api', // cÃ³ thá»ƒ dÃ¹ng chung vá»›i local khi test
      'socketUrl': '',
      'name': 'Development (Ngrok)',
      'mapTilerKey': '',
    },
    Environment.production: {
      'apiUrl':
          'https://safekids-backend-ggfdezcpc4cgcnfx.southeastasia-01.azurewebsites.net/api',
      'socketUrl':
          'https://safekids-backend-ggfdezcpc4cgcnfx.southeastasia-01.azurewebsites.net',
      'name': 'Production (Azure)',
      'mapTilerKey': '',
    },
  };

  // ðŸ”— GETTERS â€“ tá»± Ä‘á»™ng láº¥y URL theo mÃ´i trÆ°á»ng Ä‘ang chá»n
  static String get apiUrl => _config[currentEnvironment]!['apiUrl']!;
  static String get socketUrl => _config[currentEnvironment]!['socketUrl']!;
  static String get environmentName => _config[currentEnvironment]!['name']!;
  static String get mapTilerApiKey {
    if (_mapTilerKey.trim().isNotEmpty) {
      return _mapTilerKey.trim();
    }

    final fallbackKey =
        _config[currentEnvironment]?['mapTilerKey']?.trim() ?? '';
    return fallbackKey;
  }

  static bool get hasMapTilerKey => mapTilerApiKey.isNotEmpty;

  // ðŸ” Tiá»‡n Ã­ch kiá»ƒm tra mÃ´i trÆ°á»ng
  static bool get isProduction => currentEnvironment == Environment.production;
  static bool get isLocal => currentEnvironment == Environment.local;
  static bool get isDev => currentEnvironment == Environment.dev;
}

