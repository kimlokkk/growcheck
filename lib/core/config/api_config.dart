class ApiConfig {
  static const String productionBaseUrl = 'https://app.kizzukids.com.my';
  static const String localBaseUrl = 'http://app-kizzu.test';

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: productionBaseUrl,
  );

  static String url(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$cleanPath';
  }

  static String growkids(String path) {
    return url('/growkids/$path');
  }

  static String flutter(String fileName) {
    return growkids('flutter/$fileName');
  }

  static String journal(String path) {
    return growkids('journal/$path');
  }

  static String parentsFlutter(String fileName) {
    return growkids('flutter_growcheck_parents/$fileName');
  }
}
