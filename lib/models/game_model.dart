import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _parseDate(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.now();
}

class MatkaGame {
  final String id;
  final String name;
  final String description;
  final DateTime openTime;
  final DateTime closeTime;
  final bool isActive;
  final String? result;
  final double minBet;
  final double maxBet;

  MatkaGame({
    required this.id,
    required this.name,
    required this.description,
    required this.openTime,
    required this.closeTime,
    required this.isActive,
    this.result,
    this.minBet = 10.0,
    this.maxBet = 50000.0,
  });

  factory MatkaGame.fromMap(Map<String, dynamic> map) {
    return MatkaGame(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      openTime: _parseDate(map['openTime']),
      closeTime: _parseDate(map['closeTime']),
      isActive: map['isActive'] ?? true,
      result: map['result'],
      minBet: (map['minBet'] ?? 10.0).toDouble(),
      maxBet: (map['maxBet'] ?? 50000.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'openTime': Timestamp.fromDate(openTime),
      'closeTime': Timestamp.fromDate(closeTime),
      'isActive': isActive,
      'result': result,
      'minBet': minBet,
      'maxBet': maxBet,
    };
  }

  bool get isOpenForBetting {
    final now = DateTime.now();
    return now.isAfter(openTime) && now.isBefore(closeTime) && isActive;
  }

  bool get isResultTime {
    final now = DateTime.now();
    return now.isAfter(closeTime);
  }
}

class BetModel {
  final String id;
  final String userId;
  final String gameId;
  final String betType;
  final String betNumber;
  final double amount;
  final DateTime betTime;
  final String status; // pending, won, lost
  final double? winAmount;

  BetModel({
    required this.id,
    required this.userId,
    required this.gameId,
    required this.betType,
    required this.betNumber,
    required this.amount,
    required this.betTime,
    this.status = 'pending',
    this.winAmount,
  });

  factory BetModel.fromMap(Map<String, dynamic> map) {
    final betTimeValue = map['betTime'];
    DateTime betTime;
    if (betTimeValue is Timestamp) {
      betTime = betTimeValue.toDate();
    } else if (betTimeValue is String) {
      betTime = DateTime.tryParse(betTimeValue) ?? DateTime.now();
    } else if (betTimeValue is DateTime) {
      betTime = betTimeValue;
    } else {
      betTime = DateTime.now();
    }

    return BetModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      gameId: map['gameId'] ?? '',
      betType: map['betType'] ?? '',
      betNumber: map['betNumber'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      betTime: betTime,
      status: map['status'] ?? 'pending',
      winAmount: map['winAmount']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'gameId': gameId,
      'betType': betType,
      'betNumber': betNumber,
      'amount': amount,
      'betTime': Timestamp.fromDate(betTime),
      'status': status,
      'winAmount': winAmount,
    };
  }
}