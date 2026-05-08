class ApiConstants {
  static const String baseUrl = 'http://localhost:8000';
  // Pour émulateur Android : http://10.0.2.2:8000
  // Pour device physique   : http://192.168.X.X:8000

  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String predict = '/scan/predict';
  static const String history = '/history';
  static const String stats = '/stats';
}
