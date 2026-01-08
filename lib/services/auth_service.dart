import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Текущий пользователь
  static User? get currentUser => _auth.currentUser;

  // Поток авторизации
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Анонимный вход (если ещё не авторизован)
  static Future<User?> signInAnonymously() async {
    if (currentUser != null) return currentUser;
    final result = await _auth.signInAnonymously();
    return result.user;
  }

  // Вход по email
  static Future<User?> signInWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return result.user;
  }

  // Регистрация
  static Future<User?> createUserWithEmail(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    return result.user;
  }

  // Привязать email к анонимному аккаунту
  static Future<User?> linkWithEmail(String email, String password) async {
    if (currentUser == null || !currentUser!.isAnonymous) return null;
    final credential = EmailAuthProvider.credential(email: email, password: password);
    final result = await currentUser!.linkWithCredential(credential);
    return result.user;
  }

  // Выход
  static Future<void> signOut() async {
    await _auth.signOut();
  }
}