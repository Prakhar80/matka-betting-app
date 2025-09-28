import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import 'service_availability.dart';

class AuthService {
  AuthService._internal() {
    _usesFirebase = ServiceAvailability.firebaseAvailable;

    if (_usesFirebase) {
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
    } else {
      _setupOfflineStore();
    }
  }

  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;

  late final bool _usesFirebase;
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;

  final StreamController<UserModel?> _offlineAuthController =
      StreamController<UserModel?>.broadcast();

  final Map<String, _OfflineCredential> _offlineUsers = {};
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  Stream<UserModel?> get authStateChanges {
    if (_usesFirebase) {
      return _auth!.authStateChanges().asyncMap(
        (user) async {
          if (user == null) {
            _currentUser = null;
            return null;
          }
          final userModel =
              await _fetchUser(user.uid) ?? _userModelFromFirebase(user);
          _currentUser = userModel;
          return userModel;
        },
      );
    }

    return _offlineAuthController.stream;
  }

  Future<bool> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    if (!_usesFirebase) {
      final uid = _generateOfflineId(prefix: 'user');
      final userModel = UserModel(
        uid: uid,
        email: email,
        name: name,
        phone: phone,
        balance: 1000.0,
        createdAt: DateTime.now(),
      );

      _storeOfflineUser(userModel, password);
      _currentUser = userModel;
      _offlineAuthController.add(_currentUser);
      return true;
    }

    try {
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return false;
      }

      final userData = {
        'uid': user.uid,
        'email': email,
        'name': name,
        'phone': phone,
        'balance': 1000.0,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

  await _firestore!.collection('users').doc(user.uid).set(
            userData,
            SetOptions(merge: true),
          );

      _currentUser = UserModel(
        uid: user.uid,
        email: email,
        name: name,
        phone: phone,
        balance: 1000.0,
        createdAt: DateTime.now(),
      );

      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during registration: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('Error in registration: $e');
      return false;
    }
  }

  Future<bool> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (!_usesFirebase) {
      final key = email.trim().toLowerCase();
      final existing = _offlineUsers[key];

      if (existing != null) {
        if (existing.password != password) {
          return false;
        }
        _currentUser = existing.user;
        _offlineAuthController.add(_currentUser);
        return true;
      }

      final generatedUser = UserModel(
        uid: _generateOfflineId(prefix: 'user'),
        email: email,
        name: 'Offline Player',
        phone: '',
        balance: 1000.0,
        createdAt: DateTime.now(),
      );

      _storeOfflineUser(generatedUser, password);
      _currentUser = generatedUser;
      _offlineAuthController.add(_currentUser);
      return true;
    }

    try {
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return false;
      }

      _currentUser = await _fetchUser(user.uid) ?? _userModelFromFirebase(user);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during sign in: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('Error in sign in: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    if (!_usesFirebase) {
      _currentUser = null;
      _offlineAuthController.add(null);
      return;
    }

    try {
      await _auth!.signOut();
    } catch (e) {
      debugPrint('Error in sign out: $e');
    } finally {
      _currentUser = null;
    }
  }

  Future<UserModel?> getUserData(String uid) async {
    if (!_usesFirebase) {
      if (_currentUser != null && _currentUser!.uid == uid) {
        return _currentUser;
      }
      final credential = _getOfflineCredentialByUid(uid);
      return credential?.user;
    }

    if (_currentUser != null && _currentUser!.uid == uid) {
      return _currentUser;
    }
    final userModel = await _fetchUser(uid);
    if (userModel != null) {
      _currentUser = userModel;
    }
    return userModel;
  }

  Future<bool> updateUserBalance(String uid, double newBalance) async {
    if (!_usesFirebase) {
      final credential = _getOfflineCredentialByUid(uid);
      if (credential == null) {
        return false;
      }
      final updatedUser = credential.user.copyWith(balance: newBalance);
      _replaceOfflineUser(updatedUser);
      if (_currentUser != null && _currentUser!.uid == uid) {
        _currentUser = updatedUser;
      }
      _offlineAuthController.add(_currentUser);
      return true;
    }

    try {
      await _firestore!.runTransaction((transaction) async {
        final docRef = _firestore!.collection('users').doc(uid);
        transaction.update(docRef, {'balance': newBalance});
      });

      if (_currentUser != null && _currentUser!.uid == uid) {
        _currentUser = _currentUser!.copyWith(balance: newBalance);
      }
      return true;
    } catch (e) {
      debugPrint('Error updating balance: $e');
      return false;
    }
  }

  Future<UserModel?> _fetchUser(String uid) async {
    if (!_usesFirebase) {
      return _getOfflineCredentialByUid(uid)?.user;
    }

    try {
      final doc = await _firestore!.collection('users').doc(uid).get();
      if (!doc.exists) {
        final user = _auth!.currentUser;
        if (user != null && user.uid == uid) {
          final fallback = _userModelFromFirebase(user);
          await _firestore!.collection('users').doc(uid).set(
                {
                  'uid': fallback.uid,
                  'email': fallback.email,
                  'name': fallback.name,
                  'phone': fallback.phone,
                  'balance': fallback.balance,
                  'isActive': fallback.isActive,
                  'createdAt': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true),
              );
          return fallback;
        }
        return null;
      }

      final data = doc.data()!;
      data['uid'] = uid;
      data['email'] = data['email'] ?? _auth!.currentUser?.email ?? '';
      return UserModel.fromMap(data);
    } catch (e) {
      debugPrint('Error fetching user: $e');
      return null;
    }
  }

  UserModel _userModelFromFirebase(User user) {
    final creationTime = user.metadata.creationTime ?? DateTime.now();
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? 'Matka Player',
      phone: user.phoneNumber ?? '',
      balance: 0.0,
      createdAt: creationTime,
    );
  }

  void _setupOfflineStore() {
    _offlineAuthController.onListen = () {
      _offlineAuthController.add(_currentUser);
    };
  }

  void _storeOfflineUser(UserModel user, String password) {
    final key = user.email.trim().toLowerCase();
    _offlineUsers[key] = _OfflineCredential(
      email: user.email,
      password: password,
      user: user,
    );
  }

  void _replaceOfflineUser(UserModel updatedUser) {
    final key = updatedUser.email.trim().toLowerCase();
    final existing = _offlineUsers[key];
    if (existing == null) {
      return;
    }
    _offlineUsers[key] = existing.copyWith(user: updatedUser);
  }

  _OfflineCredential? _getOfflineCredentialByUid(String uid) {
    for (final credential in _offlineUsers.values) {
      if (credential.user.uid == uid) {
        return credential;
      }
    }
    return null;
  }

  String _generateOfflineId({required String prefix}) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  }

}

class _OfflineCredential {
  const _OfflineCredential({
    required this.email,
    required this.password,
    required this.user,
  });

  final String email;
  final String password;
  final UserModel user;

  _OfflineCredential copyWith({
    String? password,
    UserModel? user,
  }) {
    return _OfflineCredential(
      email: email,
      password: password ?? this.password,
      user: user ?? this.user,
    );
  }
}
