// lib/providers/auth_provider.dart - v1.0
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  bool _isLoading = true; // Initial loading state

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _auth.userChanges().listen(_onAuthStateChanged);
    // Initial check, especially if userChanges doesn't fire immediately on startup for existing session
    _user = _auth.currentUser; 
    _isLoading = false;
    notifyListeners(); // Notify after initial check
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    print('AuthProvider: Auth state changed. User: ${firebaseUser?.uid}');
    _user = firebaseUser;
    _isLoading = false; // No longer loading once first auth state is received
    notifyListeners(); // This will trigger rebuilds in widgets listening to AuthProvider
  }

  Future<void> signOut() async {
    print('AuthProvider: Signing out...');
    await _auth.signOut();
    // _onAuthStateChanged will be called automatically by the stream listener,
    // which will set _user to null and notify listeners.
    print('AuthProvider: Sign out complete. Current user in provider: ${_user?.uid}');
  }
}