import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import '../../services/game_service.dart';
import '../../services/wallet_service.dart';
import '../../models/game_model.dart';
import '../../widgets/animated_button.dart';
import '../../widgets/common_widgets.dart' as widgets;

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> with TickerProviderStateMixin {
  final GameService _gameService = GameService();
  final WalletService _walletService = WalletService();
  double _userBalance = 0.0;
  
  // Simplified Animation Controller
  late AnimationController _cardsController;
  late Animation<double> _cardsAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize Simple Animation
    _cardsController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _cardsAnimation = CurvedAnimation(parent: _cardsController, curve: Curves.easeOut);
    _cardsController.forward();
    
    _loadUserBalance();
  }
  
  @override
  void dispose() {
    _cardsController.dispose();
    super.dispose();
  }

  Future<void> _loadUserBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final balance = await _walletService.getUserBalance();
      if (!mounted) return;
      setState(() {
        _userBalance = balance;
      });
    }
  }

  void _showBettingDialog(MatkaGame game) {
    if (!game.isOpenForBetting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This game is currently closed for betting'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => BettingDialog(
        game: game,
        userBalance: _userBalance,
        onBetPlaced: () {
          _loadUserBalance(); // Refresh balance after bet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bet placed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF667eea),
                  const Color(0xFF764ba2),
                  const Color(0xFF6C63FF),
                  const Color(0xFF03DAC6),
                ],
                stops: [
                  0.0 + (math.sin(_backgroundAnimation.value) * 0.1),
                  0.3 + (math.cos(_backgroundAnimation.value) * 0.1),
                  0.7 + (math.sin(_backgroundAnimation.value + 1) * 0.1),
                  1.0,
                ],
              ),
            ),
            child: Stack(
              children: [
                // Animated Background Particles
                ...List.generate(6, (index) {
                  return Positioned(
                    top: 80.0 + (index * 120) + (math.sin(_backgroundAnimation.value + index) * 25),
                    left: 30.0 + (index * 90) + (math.cos(_backgroundAnimation.value + index) * 35),
                    child: Opacity(
                      opacity: 0.3,
                      child: Transform.rotate(
                        angle: _backgroundAnimation.value + (index * 0.3),
                        child: Container(
                          width: 50 + (index * 8),
                          height: 50 + (index * 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                // Main Content
                SafeArea(
                  child: Column(
                    children: [
                      // Professional App Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Row(
                          children: [
                            // Back Button
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                                ),
                                child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Title
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'LIVE GAMES',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  Text(
                                    'Choose your lucky game',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Balance Display
                            AnimatedBuilder(
                              animation: _statsAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _statsAnimation.value,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFFD700),
                                          Color(0xFFFFA500),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFFD700).withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.account_balance_wallet_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '₹${_userBalance.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Professional Games List
                      Expanded(
                        child: StreamBuilder<List<MatkaGame>>(
                          stream: _gameService.getActiveGames(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return _buildLoadingState();
                            }

                            if (snapshot.hasError) {
                              return _buildErrorState();
                            }

                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return _buildEmptyState();
                            }

                            final games = snapshot.data!;
                            return AnimatedBuilder(
                              animation: _cardsAnimation,
                              builder: (context, child) {
                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  itemCount: games.length,
                                  itemBuilder: (context, index) {
                                    return Transform.translate(
                                      offset: Offset(0, 30 * (1 - _cardsAnimation.value) * (index + 1)),
                                      child: Opacity(
                                        opacity: _cardsAnimation.value,
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 16),
                                          child: _buildProfessionalGameCard(games[index]),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Professional Helper Methods
  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Animated loading particles
          ...List.generate(4, (index) {
            return Positioned(
              top: 100.0 + (index * 120) + (math.sin(_backgroundAnimation.value + index) * 20),
              left: 50.0 + (index * 80) + (math.cos(_backgroundAnimation.value + index) * 30),
              child: Opacity(
                opacity: 0.3,
                child: Transform.rotate(
                  angle: _backgroundAnimation.value + (index * 0.5),
                  child: Container(
                    width: 40 + (index * 8),
                    height: 40 + (index * 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          // Loading content
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
                SizedBox(height: 24),
                Text(
                  'Loading Games...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.25),
              Colors.white.withOpacity(0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFFB347)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.error_outline_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load games',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.25),
              Colors.white.withOpacity(0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.casino_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'No games available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for exciting games',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalGameCard(MatkaGame game) {
    return GestureDetector(
      onTap: () => _showBettingDialog(game),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.25),
              Colors.white.withOpacity(0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Game Icon
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: game.isOpenForBetting 
                        ? [const Color(0xFF00C9FF), const Color(0xFF92FE9D)]
                        : [const Color(0xFFFF6B6B), const Color(0xFFFFB347)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: (game.isOpenForBetting 
                          ? const Color(0xFF00C9FF) 
                          : const Color(0xFFFF6B6B)).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      game.isOpenForBetting ? Icons.casino_rounded : Icons.pause_circle_outline_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Game Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        game.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (game.isOpenForBetting ? Colors.green : Colors.red).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: game.isOpenForBetting ? Colors.green : Colors.red,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    game.isOpenForBetting ? 'OPEN' : 'CLOSED',
                    style: TextStyle(
                      color: game.isOpenForBetting ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (game.isOpenForBetting) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Min Bet',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        Text(
                          '₹${game.minBet}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Max Bet',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        Text(
                          '₹${game.maxBet}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'PLAY NOW',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BettingDialog extends StatefulWidget {
  final MatkaGame game;
  final double userBalance;
  final VoidCallback onBetPlaced;

  const BettingDialog({
    super.key,
    required this.game,
    required this.userBalance,
    required this.onBetPlaced,
  });

  @override
  State<BettingDialog> createState() => _BettingDialogState();
}

class _BettingDialogState extends State<BettingDialog> {
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String _selectedBetType = 'single';
  bool _isLoading = false;

  @override
  void dispose() {
    _numberController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _placeBet() async {
    final number = _numberController.text.trim();
    final amountText = _amountController.text.trim();

    if (number.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (amount < widget.game.minBet || amount > widget.game.maxBet) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Amount should be between ₹${widget.game.minBet} and ₹${widget.game.maxBet}'),
        ),
      );
      return;
    }

    if (amount > widget.userBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Place bet logic here
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call
      
      if (mounted) {
        Navigator.pop(context);
        widget.onBetPlaced();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error placing bet: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Place Bet - ${widget.game.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bet Type Selection
          DropdownButtonFormField<String>(
            value: _selectedBetType,
            decoration: const InputDecoration(
              labelText: 'Bet Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'single', child: Text('Single (9.5x)')),
              DropdownMenuItem(value: 'jodi', child: Text('Jodi (95x)')),
              DropdownMenuItem(value: 'panna', child: Text('Panna (142x)')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedBetType = value;
              });
            },
          ),
          const SizedBox(height: 16),
          // Number Input
          TextFormField(
            controller: _numberController,
            decoration: const InputDecoration(
              labelText: 'Number',
              hintText: 'Enter your lucky number',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          // Amount Input
          TextFormField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Amount',
              hintText: 'Min: ₹${widget.game.minBet}, Max: ₹${widget.game.maxBet}',
              border: const OutlineInputBorder(),
              prefixText: '₹',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          // Quick Amount Buttons
          Wrap(
            spacing: 8,
            children: [10, 50, 100, 500, 1000].map((amount) {
              return ElevatedButton(
                onPressed: () {
                  _amountController.text = amount.toString();
                },
                child: Text('₹$amount'),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Balance: ₹${widget.userBalance.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _placeBet,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3C72),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Place Bet'),
        ),
      ],
    );
  }
}