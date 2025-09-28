import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/game_model.dart';
import '../models/transaction_model.dart';
import 'auth_service.dart';
import 'service_availability.dart';

class GameService {
  GameService._internal() {
    _usesFirebase = ServiceAvailability.firebaseAvailable;

    if (_usesFirebase) {
      _firestore = FirebaseFirestore.instance;
    } else {
      _setupOfflineData();
    }
  }

  static final GameService _instance = GameService._internal();

  factory GameService() => _instance;

  late final bool _usesFirebase;
  FirebaseFirestore? _firestore;

  final List<MatkaGame> _offlineGames = [];
  final Map<String, List<BetModel>> _offlineBetsByUser = {};
  final Map<String, StreamController<List<BetModel>>> _offlineBetControllers = {};

  final StreamController<List<MatkaGame>> _offlineActiveGamesController =
      StreamController<List<MatkaGame>>.broadcast();
  final StreamController<List<MatkaGame>> _offlineResultsController =
      StreamController<List<MatkaGame>>.broadcast();

  // Get all active games
  Stream<List<MatkaGame>> getActiveGames() {
    if (_usesFirebase) {
      return _firestore!
          .collection('games')
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => MatkaGame.fromMap(doc.data()))
              .toList());
    }

    return _offlineActiveGamesController.stream;
  }

  // Get specific game
  Future<MatkaGame?> getGame(String gameId) async {
    if (!_usesFirebase) {
      try {
        return _offlineGames.firstWhere((game) => game.id == gameId);
      } catch (_) {
        return null;
      }
    }

    try {
      DocumentSnapshot doc =
          await _firestore!.collection('games').doc(gameId).get();
      if (doc.exists) {
        return MatkaGame.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting game: $e');
      return null;
    }
  }

  // Place a bet
  Future<bool> placeBet({
    required String userId,
    required String gameId,
    required String betType,
    required String betNumber,
    required double amount,
  }) async {
    if (!_usesFirebase) {
      final game = await getGame(gameId);
      if (game == null || !game.isOpenForBetting) {
        return false;
      }

      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null || user.balance < amount) {
        debugPrint('Offline bet failed due to missing user or low balance');
        return false;
      }

      final balanceUpdated =
          await authService.updateUserBalance(user.uid, user.balance - amount);
      if (!balanceUpdated) {
        return false;
      }

      final bet = BetModel(
        id: _generateOfflineId('bet'),
        userId: userId,
        gameId: gameId,
        betType: betType,
        betNumber: betNumber,
        amount: amount,
        betTime: DateTime.now(),
      );

      final bets = _offlineBetsByUser.putIfAbsent(userId, () => []);
      bets.insert(0, bet);
      _emitOfflineBets(userId);
      return true;
    }

    try {
      // Check if game is open for betting
      MatkaGame? game = await getGame(gameId);
      if (game == null || !game.isOpenForBetting) {
        return false;
      }

      // Generate bet ID
      String betId = _firestore!.collection('bets').doc().id;

      BetModel bet = BetModel(
        id: betId,
        userId: userId,
        gameId: gameId,
        betType: betType,
        betNumber: betNumber,
        amount: amount,
        betTime: DateTime.now(),
      );

      // Save bet to Firestore
      await _firestore!.collection('bets').doc(betId).set(bet.toMap());

      // Create transaction record
      String transactionId = _firestore!.collection('transactions').doc().id;
      TransactionModel transaction = TransactionModel(
        id: transactionId,
        userId: userId,
        type: 'bet',
        amount: amount,
        timestamp: DateTime.now(),
        status: 'completed',
        description: 'Bet placed on ${game.name}',
      );

      await _firestore!
          .collection('transactions')
          .doc(transactionId)
          .set(transaction.toMap());

      return true;
    } catch (e) {
      debugPrint('Error placing bet: $e');
      return false;
    }
  }

  // Get user's bets
  Stream<List<BetModel>> getUserBets(String userId) {
    if (_usesFirebase) {
      return _firestore!
          .collection('bets')
          .where('userId', isEqualTo: userId)
          .orderBy('betTime', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => BetModel.fromMap(doc.data()))
              .toList());
    }

    final controller = _offlineBetControllers.putIfAbsent(
      userId,
      () => StreamController<List<BetModel>>.broadcast(
        onListen: () {
          _emitOfflineBets(userId);
        },
      ),
    );

    return controller.stream;
  }

  // Get game results
  Stream<List<MatkaGame>> getGameResults() {
    if (_usesFirebase) {
      return _firestore!
          .collection('games')
          .where('result', isNotEqualTo: null)
          .orderBy('closeTime', descending: true)
          .limit(50)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => MatkaGame.fromMap(doc.data()))
              .toList());
    }

    return _offlineResultsController.stream;
  }

  // Admin: Update game result (for testing purposes)
  Future<void> updateGameResult(String gameId, String result) async {
    if (!_usesFirebase) {
      _applyOfflineGameResult(gameId, result);
      await _processOfflineWinningBets(gameId, result);
      return;
    }

    try {
      await _firestore!.collection('games').doc(gameId).update({
        'result': result,
      });

      // Process winning bets
      await _processWinningBets(gameId, result);
    } catch (e) {
      debugPrint('Error updating game result: $e');
    }
  }

  // Process winning bets
  Future<void> _processWinningBets(String gameId, String result) async {
    if (!_usesFirebase) {
      await _processOfflineWinningBets(gameId, result);
      return;
    }

    try {
      // Get all bets for this game
      QuerySnapshot betsSnapshot = await _firestore!
          .collection('bets')
          .where('gameId', isEqualTo: gameId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (QueryDocumentSnapshot betDoc in betsSnapshot.docs) {
        BetModel bet = BetModel.fromMap(betDoc.data() as Map<String, dynamic>);
        
        // Check if bet won
        bool isWinner = _checkIfBetWon(bet, result);
        
        if (isWinner) {
          double winAmount = _calculateWinAmount(bet);
          
          // Update bet status
          await _firestore!.collection('bets').doc(bet.id).update({
            'status': 'won',
            'winAmount': winAmount,
          });

          // Create winning transaction
          String transactionId = _firestore!
              .collection('transactions')
              .doc()
              .id;
          TransactionModel transaction = TransactionModel(
            id: transactionId,
            userId: bet.userId,
            type: 'win',
            amount: winAmount,
            timestamp: DateTime.now(),
            status: 'completed',
            description: 'Won bet on game',
          );

          await _firestore!
              .collection('transactions')
              .doc(transactionId)
              .set(transaction.toMap());
        } else {
          // Update bet status to lost
          await _firestore!.collection('bets').doc(bet.id).update({
            'status': 'lost',
          });
        }
      }
    } catch (e) {
      debugPrint('Error processing winning bets: $e');
    }
  }

  // Check if bet won (simplified logic)
  bool _checkIfBetWon(BetModel bet, String result) {
    // This is a simplified logic - in real Matka, rules are complex
    return bet.betNumber == result;
  }

  // Calculate win amount (simplified logic)
  double _calculateWinAmount(BetModel bet) {
    // This is simplified - real Matka has different payout ratios for different bet types
    switch (bet.betType.toLowerCase()) {
      case 'single':
        return bet.amount * 9.5; // 9.5x for single digit
      case 'jodi':
        return bet.amount * 95; // 95x for jodi
      case 'panna':
        return bet.amount * 142; // 142x for panna
      default:
        return bet.amount * 9.5;
    }
  }

  void _setupOfflineData() {
    _offlineActiveGamesController.onListen = _emitOfflineGameUpdates;
    _offlineResultsController.onListen = _emitOfflineGameUpdates;
    _seedOfflineGames();
  }

  void _seedOfflineGames({bool forceRefresh = false}) {
    if (_offlineGames.isNotEmpty && !forceRefresh) {
      _emitOfflineGameUpdates();
      return;
    }

    _offlineGames
      ..clear()
      ..addAll(_buildSampleGames());
    _emitOfflineGameUpdates();
  }

  List<MatkaGame> _buildSampleGames() {
    final now = DateTime.now();
    return [
      MatkaGame(
        id: 'kalyan_day',
        name: 'Kalyan Day',
        description: 'Open 3:45 PM - Close 5:45 PM',
        openTime: now.add(const Duration(hours: 1)),
        closeTime: now.add(const Duration(hours: 3)),
        isActive: true,
        minBet: 10.0,
        maxBet: 50000.0,
      ),
      MatkaGame(
        id: 'milan_day',
        name: 'Milan Day',
        description: 'Open 2:30 PM - Close 4:30 PM',
        openTime: now.add(const Duration(minutes: 30)),
        closeTime: now.add(const Duration(hours: 2, minutes: 30)),
        isActive: true,
        minBet: 10.0,
        maxBet: 50000.0,
      ),
      MatkaGame(
        id: 'rajdhani_day',
        name: 'Rajdhani Day',
        description: 'Open 4:20 PM - Close 6:20 PM',
        openTime: now.add(const Duration(hours: 2)),
        closeTime: now.add(const Duration(hours: 4)),
        isActive: true,
        minBet: 10.0,
        maxBet: 50000.0,
      ),
    ];
  }

  void _emitOfflineGameUpdates() {
    final activeGames = _offlineGames.where((game) => game.isActive).toList();
    final resultGames =
        _offlineGames.where((game) => game.result != null).toList();

    if (!_offlineActiveGamesController.isClosed) {
      _offlineActiveGamesController.add(List.unmodifiable(activeGames));
    }
    if (!_offlineResultsController.isClosed) {
      _offlineResultsController.add(List.unmodifiable(resultGames));
    }
  }

  void _emitOfflineBets(String userId) {
    final controller = _offlineBetControllers[userId];
    if (controller != null && !controller.isClosed) {
      controller.add(
        List.unmodifiable(_offlineBetsByUser[userId] ?? const []),
      );
    }
  }

  void _applyOfflineGameResult(String gameId, String result) {
    final index = _offlineGames.indexWhere((game) => game.id == gameId);
    if (index == -1) {
      return;
    }

    final game = _offlineGames[index];
    _offlineGames[index] = MatkaGame(
      id: game.id,
      name: game.name,
      description: game.description,
      openTime: game.openTime,
      closeTime: game.closeTime,
      isActive: false,
      result: result,
      minBet: game.minBet,
      maxBet: game.maxBet,
    );

    _emitOfflineGameUpdates();
  }

  Future<void> _processOfflineWinningBets(
    String gameId,
    String result,
  ) async {
    final authService = AuthService();

    for (final entry in _offlineBetsByUser.entries) {
      final userId = entry.key;
      final bets = entry.value;
      var updated = false;

      for (var i = 0; i < bets.length; i++) {
        final bet = bets[i];
        if (bet.gameId != gameId || bet.status != 'pending') {
          continue;
        }

        if (_checkIfBetWon(bet, result)) {
          final winAmount = _calculateWinAmount(bet);
          bets[i] = BetModel(
            id: bet.id,
            userId: bet.userId,
            gameId: bet.gameId,
            betType: bet.betType,
            betNumber: bet.betNumber,
            amount: bet.amount,
            betTime: bet.betTime,
            status: 'won',
            winAmount: winAmount,
          );

          final userModel = await authService.getUserData(userId);
          if (userModel != null) {
            await authService.updateUserBalance(
              userId,
              userModel.balance + winAmount,
            );
          }
        } else {
          bets[i] = BetModel(
            id: bet.id,
            userId: bet.userId,
            gameId: bet.gameId,
            betType: bet.betType,
            betNumber: bet.betNumber,
            amount: bet.amount,
            betTime: bet.betTime,
            status: 'lost',
            winAmount: bet.winAmount,
          );
        }

        updated = true;
      }

      if (updated) {
        _emitOfflineBets(userId);
      }
    }
  }

  String _generateOfflineId(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  }

  // Create sample games (for development)
  Future<void> createSampleGames() async {
    if (!_usesFirebase) {
      _seedOfflineGames(forceRefresh: true);
      return;
    }

    final sampleGames = _buildSampleGames();

    for (final game in sampleGames) {
      await _firestore!
          .collection('games')
          .doc(game.id)
          .set(game.toMap(), SetOptions(merge: true));
    }
  }
}