import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'service_availability.dart';

class WalletService {
  WalletService._internal() {
    _usesFirebase = ServiceAvailability.firebaseAvailable;

    if (_usesFirebase) {
      _firestore = FirebaseFirestore.instance;
      _auth = FirebaseAuth.instance;
    }
  }

  static final WalletService _instance = WalletService._internal();

  factory WalletService() => _instance;

  late final bool _usesFirebase;
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;

  // Get current user balance
  Future<double> getUserBalance() async {
    if (!_usesFirebase) {
      final user = AuthService().currentUser;
      return user?.balance ?? 0.0;
    }

    try {
      User? user = _auth!.currentUser;
      if (user != null) {
        DocumentSnapshot doc =
            await _firestore!.collection('users').doc(user.uid).get();
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return (data['balance'] ?? 0).toDouble();
        }
      }
      return 0.0;
    } catch (e) {
      debugPrint('Error getting user balance: $e');
      return 0.0;
    }
  }

  // Add money to wallet
  Future<bool> addMoney({
    required double amount,
    required String paymentMethod,
    String? transactionId,
  }) async {
    if (!_usesFirebase) {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null) {
        return false;
      }

      await authService.updateUserBalance(
        user.uid,
        user.balance + amount,
      );
      return true;
    }

    try {
      User? user = _auth!.currentUser;
      if (user == null) return false;

      await _firestore!.runTransaction((transaction) async {
        final userRef = _firestore!.collection('users').doc(user.uid);
        final snapshot = await transaction.get(userRef);
        final currentBalance = (snapshot.data()?['balance'] ?? 0).toDouble();
        final newBalance = currentBalance + amount;
        transaction.update(userRef, {'balance': newBalance});
      });

      // Create transaction record
      await _firestore!.collection('transactions').add({
        'userId': user.uid,
        'type': 'credit',
        'amount': amount,
        'paymentMethod': paymentMethod,
        'transactionId': transactionId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
        'description': 'Money added to wallet',
      });

      return true;
    } catch (e) {
      debugPrint('Error adding money: $e');
      return false;
    }
  }

  // Withdraw money from wallet
  Future<bool> withdrawMoney({
    required double amount,
    required String withdrawMethod,
    String? accountDetails,
  }) async {
    if (!_usesFirebase) {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null) {
        return false;
      }
      if (user.balance < amount) {
        debugPrint('Insufficient balance during offline withdrawal');
        return false;
      }

      await authService.updateUserBalance(
        user.uid,
        user.balance - amount,
      );
      return true;
    }

    try {
      User? user = _auth!.currentUser;
      if (user == null) return false;

      bool success = false;

      await _firestore!.runTransaction((transaction) async {
        final userRef = _firestore!.collection('users').doc(user.uid);
        final snapshot = await transaction.get(userRef);
        final currentBalance = (snapshot.data()?['balance'] ?? 0).toDouble();

        if (currentBalance < amount) {
          success = false;
          return;
        }

        final newBalance = currentBalance - amount;
        transaction.update(userRef, {'balance': newBalance});
        success = true;
      });

      if (!success) {
        debugPrint('Insufficient balance during withdrawal');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error withdrawing money: $e');
      return false;
    }
  }

  // Place bet 
  Future<bool> placeBet({
    required double amount,
    required String gameType,
    required Map<String, dynamic> betDetails,
  }) async {
    if (!_usesFirebase) {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null) {
        return false;
      }
      if (user.balance < amount) {
        debugPrint('Insufficient balance for offline bet');
        return false;
      }

      await authService.updateUserBalance(
        user.uid,
        user.balance - amount,
      );
      return true;
    }

    try {
      User? user = _auth!.currentUser;
      if (user == null) return false;

      bool success = false;

      await _firestore!.runTransaction((transaction) async {
        final userRef = _firestore!.collection('users').doc(user.uid);
        final snapshot = await transaction.get(userRef);
        final currentBalance = (snapshot.data()?['balance'] ?? 0).toDouble();

        if (currentBalance < amount) {
          success = false;
          return;
        }

        final newBalance = currentBalance - amount;
        transaction.update(userRef, {'balance': newBalance});
        success = true;
      });

      if (!success) {
        debugPrint('Insufficient balance for bet');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error placing bet: $e');
      return false;
    }
  }
}