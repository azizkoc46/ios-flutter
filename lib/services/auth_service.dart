import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Kullanıcı durumunu dinle (Zorunlu giriş kontrolü için)
  Stream<User?> get userStream => _auth.authStateChanges();

  // E-posta ile Kayıt
  Future<UserCredential> registerWithEmail(
      String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  // E-posta ile Giriş
  Future<UserCredential> loginWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  // Kullanıcıyı Firestore'a kaydet
  Future<void> saveUserToFirestore({
    required String uid,
    required String fullname,
    required String email,
    String? image,
    required String authType,
  }) async {
    await _db.collection('customers').doc(uid).set({
      'fullname': fullname,
      'email': email,
      'image': image ?? '',
      'role': 'customer',
      'isApproved': false,
      'auth-type': authType,
      'createdAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  // Çıkış Yap
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
