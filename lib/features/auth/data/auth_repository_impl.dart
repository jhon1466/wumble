import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  AuthRepositoryImpl({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  @override
  Stream<User?> get user => _firebaseAuth.authStateChanges();

  @override
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Error desconocido al iniciar sesión');
    }
  }

  @override
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Error desconocido al registrarse');
    }
  }

  @override
  Future<User?> signInWithGoogle() async {
    try {
      // Force account picker if previously disconnected
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('AuthRepo: idToken present: ${googleAuth.idToken != null}');
      print('AuthRepo: accessToken present: ${googleAuth.accessToken != null}');
      
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;
      
      if (user != null) {
        // Debug Log to ensure we are capturing data
        print('✅ Google Sign-In Success: ${user.displayName} | ${user.photoURL}');
      }
      return user;
    } catch (e) {
      throw Exception('Error al iniciar sesión con Google: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      // Disconnect allows selecting a different account next time
      await _googleSignIn.disconnect(); 
    } catch (e) {
      // Ignore if already disconnected
    }
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }
}
