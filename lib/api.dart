class Api {
  static const String baseUrl = 'http://194.156.66.100:3100';
  static String? token;

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}