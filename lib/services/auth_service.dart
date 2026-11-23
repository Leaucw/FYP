import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔹 Sign Up and store data in Firestore
  Future<User?> signup(String email, String password) async {
    try {
      // 1. Create user with Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      // 2. Store basic info in Firestore
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'displayName': user.displayName ?? '',
          'photoURL': user.photoURL ?? '',
        });
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print("Signup error: ${e.message}");
      return null;
    }
  }

  // 🔹 Login
  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return result.user;
    } catch (e) {
      print("Login Error: $e");
      return null;
    }
  }

  // 🔹 Logout
  Future<void> logout() async {
    await _auth.signOut();
  }
}
