import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String sessionDurationKey = "session_duration";

  // Guardar duración
  Future<void> saveSessionDuration(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(sessionDurationKey, minutes);
  }

  // Cargar duración (default 25)
  Future<int> getSessionDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(sessionDurationKey) ?? 25;
  }
}
