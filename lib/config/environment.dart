
enum Environment {
  local,      
  dev,        
  production, 
}

class EnvironmentConfig {
  
  static const Environment currentEnvironment = Environment.local;
  
  static const Map<Environment, Map<String, String>> _config = {
    Environment.local: {
      'apiUrl': 'https://4bcb5f6ab8f1.ngrok-free.app/api',
      'socketUrl': 'https://4bcb5f6ab8f1.ngrok-free.app',
      'name': 'Local (Emulator)',
    },
    Environment.dev: {
      'apiUrl': 'https://4bcb5f6ab8f1.ngrok-free.app/api',
      'socketUrl': 'https://4bcb5f6ab8f1.ngrok-free.app',
      'name': 'Development (Azure)',
    },
    Environment.production: {
      'apiUrl': 'https://safekids-backend-ggfdezcpc4cgcnfx.southeastasia-01.azurewebsites.net/api',
      'socketUrl': 'https://safekids-backend-ggfdezcpc4cgcnfx.southeastasia-01.azurewebsites.net',
      'name': 'Production (Azure)',
    },
  };
  
 
  static String get apiUrl => _config[currentEnvironment]!['apiUrl']!;
  static String get socketUrl => _config[currentEnvironment]!['socketUrl']!;
  static String get environmentName => _config[currentEnvironment]!['name']!;
  
  
  static bool get isProduction => currentEnvironment == Environment.production;
  static bool get isLocal => currentEnvironment == Environment.local;
  static bool get isDev => currentEnvironment == Environment.dev;
}






