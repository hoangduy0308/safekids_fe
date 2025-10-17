/// Environment Configuration
/// Quáº£n lÃ½ cÃ¡c mÃ´i trÆ°á»ng khÃ¡c nhau: Local (ngrok), Development, Production
enum Environment {
  local,      // Development vá»›i ngrok
  dev,        // Azure dev environment (náº¿u cÃ³)
  production, // Azure production
}

class EnvironmentConfig {
  // Äá»•i giÃ¡ trá»‹ nÃ y Ä‘á»ƒ switch giá»¯a cÃ¡c mÃ´i trÆ°á»ng
  static const Environment currentEnvironment = Environment.local;
  
  // Cáº¥u hÃ¬nh cho tá»«ng mÃ´i trÆ°á»ng
  static const Map<Environment, Map<String, String>> _config = {
    Environment.local: {
      'apiUrl': 'https://2515480b5207.ngrok-free.app/api',  // âœ… Fixed: Single slash
      'socketUrl': 'https://2515480b5207.ngrok-free.app',
      'name': 'Local (Ngrok)',
    },
    Environment.dev: {
      'apiUrl': 'https://safekids-backend-dev.azurewebsites.net/api',
      'socketUrl': 'https://safekids-backend-dev.azurewebsites.net',
      'name': 'Development (Azure)',
    },
    Environment.production: {
      'apiUrl': 'https://safekids-backend-ggfdezcpc4cgcnfx.southeastasia-01.azurewebsites.net/api',
      'socketUrl': 'https://safekids-backend-ggfdezcpc4cgcnfx.southeastasia-01.azurewebsites.net',
      'name': 'Production (Azure)',
    },
  };
  
  // Getters Ä‘á»ƒ láº¥y config hiá»‡n táº¡i
  static String get apiUrl => _config[currentEnvironment]!['apiUrl']!;
  static String get socketUrl => _config[currentEnvironment]!['socketUrl']!;
  static String get environmentName => _config[currentEnvironment]!['name']!;
  
  // Helper Ä‘á»ƒ check mÃ´i trÆ°á»ng
  static bool get isProduction => currentEnvironment == Environment.production;
  static bool get isLocal => currentEnvironment == Environment.local;
  static bool get isDev => currentEnvironment == Environment.dev;
}

