part of 'erp_danf_app.dart';

enum _CheckersPlayer { a, b }

extension on _CheckersPlayer {
  _CheckersPlayer get opponent =>
      this == _CheckersPlayer.a ? _CheckersPlayer.b : _CheckersPlayer.a;

  String get label =>
      this == _CheckersPlayer.a ? 'Jogador 1 (claras)' : 'Jogador 2 (escuras)';
}

class _CheckersPiece {
  _CheckersPiece({required this.owner});

  final _CheckersPlayer owner;
  bool isKing = false;
}

class _CheckersMove {
  const _CheckersMove({
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    this.capturedRow,
    this.capturedCol,
  });

  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;
  final int? capturedRow;
  final int? capturedCol;

  bool get isCapture => capturedRow != null;
}

typedef _CheckersBoard = List<List<_CheckersPiece?>>;

_CheckersBoard _checkersInitialBoard() {
  final board = List.generate(8, (_) => List<_CheckersPiece?>.filled(8, null));
  for (var row = 0; row < 3; row++) {
    for (var col = 0; col < 8; col++) {
      if ((row + col).isOdd) {
        board[row][col] = _CheckersPiece(owner: _CheckersPlayer.a);
      }
    }
  }
  for (var row = 5; row < 8; row++) {
    for (var col = 0; col < 8; col++) {
      if ((row + col).isOdd) {
        board[row][col] = _CheckersPiece(owner: _CheckersPlayer.b);
      }
    }
  }
  return board;
}

bool _checkersInBounds(int row, int col) =>
    row >= 0 && row < 8 && col >= 0 && col < 8;

List<List<int>> _checkersDirectionsFor(_CheckersPiece piece) {
  if (piece.isKing) {
    return const [
      [-1, -1],
      [-1, 1],
      [1, -1],
      [1, 1],
    ];
  }
  return piece.owner == _CheckersPlayer.a
      ? const [
          [1, -1],
          [1, 1],
        ]
      : const [
          [-1, -1],
          [-1, 1],
        ];
}

List<_CheckersMove> _checkersMovesForPiece(
  _CheckersBoard board,
  int row,
  int col,
) {
  final piece = board[row][col];
  if (piece == null) {
    return const [];
  }

  final simpleMoves = <_CheckersMove>[];
  final captureMoves = <_CheckersMove>[];

  for (final direction in _checkersDirectionsFor(piece)) {
    final stepRow = row + direction[0];
    final stepCol = col + direction[1];
    if (!_checkersInBounds(stepRow, stepCol)) {
      continue;
    }
    final stepPiece = board[stepRow][stepCol];
    if (stepPiece == null) {
      simpleMoves.add(
        _CheckersMove(
          fromRow: row,
          fromCol: col,
          toRow: stepRow,
          toCol: stepCol,
        ),
      );
      continue;
    }
    if (stepPiece.owner == piece.owner) {
      continue;
    }
    final jumpRow = row + direction[0] * 2;
    final jumpCol = col + direction[1] * 2;
    if (_checkersInBounds(jumpRow, jumpCol) &&
        board[jumpRow][jumpCol] == null) {
      captureMoves.add(
        _CheckersMove(
          fromRow: row,
          fromCol: col,
          toRow: jumpRow,
          toCol: jumpCol,
          capturedRow: stepRow,
          capturedCol: stepCol,
        ),
      );
    }
  }

  return captureMoves.isNotEmpty ? captureMoves : simpleMoves;
}

int _checkersPieceCount(_CheckersBoard board, _CheckersPlayer player) {
  var count = 0;
  for (final row in board) {
    for (final piece in row) {
      if (piece != null && piece.owner == player) {
        count++;
      }
    }
  }
  return count;
}

bool _checkersHasAnyLegalMove(_CheckersBoard board, _CheckersPlayer player) {
  for (var row = 0; row < 8; row++) {
    for (var col = 0; col < 8; col++) {
      final piece = board[row][col];
      if (piece != null &&
          piece.owner == player &&
          _checkersMovesForPiece(board, row, col).isNotEmpty) {
        return true;
      }
    }
  }
  return false;
}

List<_CheckersMove> _checkersAllMovesFor(
  _CheckersBoard board,
  _CheckersPlayer player,
) {
  final moves = <_CheckersMove>[];
  for (var row = 0; row < 8; row++) {
    for (var col = 0; col < 8; col++) {
      final piece = board[row][col];
      if (piece != null && piece.owner == player) {
        moves.addAll(_checkersMovesForPiece(board, row, col));
      }
    }
  }
  final captures = moves.where((m) => m.isCapture).toList(growable: false);
  return captures.isNotEmpty ? captures : moves;
}

class _CheckersGameScreen extends StatefulWidget {
  const _CheckersGameScreen({this.vsComputer = false});

  final bool vsComputer;

  @override
  State<_CheckersGameScreen> createState() => _CheckersGameScreenState();
}

class _CheckersGameScreenState extends State<_CheckersGameScreen> {
  late _CheckersBoard _board;
  _CheckersPlayer _turn = _CheckersPlayer.a;
  int? _selectedRow;
  int? _selectedCol;
  List<_CheckersMove> _legalMoves = const [];
  bool _mustContinueCapture = false;
  _CheckersPlayer? _winner;
  int _winsA = 0;
  int _winsB = 0;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    setState(() {
      _board = _checkersInitialBoard();
      _turn = _CheckersPlayer.a;
      _selectedRow = null;
      _selectedCol = null;
      _legalMoves = const [];
      _mustContinueCapture = false;
      _winner = null;
    });
  }

  void _selectCell(int row, int col) {
    final piece = _board[row][col];
    if (piece == null || piece.owner != _turn) {
      return;
    }
    setState(() {
      _selectedRow = row;
      _selectedCol = col;
      _legalMoves = _checkersMovesForPiece(_board, row, col);
    });
  }

  void _applyMove(_CheckersMove move) {
    final piece = _board[move.fromRow][move.fromCol]!;
    setState(() {
      _board[move.fromRow][move.fromCol] = null;
      if (move.isCapture) {
        _board[move.capturedRow!][move.capturedCol!] = null;
      }
      final promotionRow = piece.owner == _CheckersPlayer.a ? 7 : 0;
      if (move.toRow == promotionRow) {
        piece.isKing = true;
      }
      _board[move.toRow][move.toCol] = piece;

      if (move.isCapture) {
        final furtherCaptures = _checkersMovesForPiece(
          _board,
          move.toRow,
          move.toCol,
        ).where((m) => m.isCapture).toList(growable: false);
        if (furtherCaptures.isNotEmpty) {
          _selectedRow = move.toRow;
          _selectedCol = move.toCol;
          _legalMoves = furtherCaptures;
          _mustContinueCapture = true;
          return;
        }
      }
      _endTurn();
    });
    _maybeTriggerComputerMove();
  }

  void _maybeTriggerComputerMove() {
    if (widget.vsComputer &&
        _winner == null &&
        _turn == _CheckersPlayer.b) {
      Future.delayed(const Duration(milliseconds: 500), _performComputerMove);
    }
  }

  void _performComputerMove() {
    if (!mounted || _winner != null || _turn != _CheckersPlayer.b) {
      return;
    }
    final candidates = _mustContinueCapture
        ? _legalMoves
        : _checkersAllMovesFor(_board, _CheckersPlayer.b);
    if (candidates.isEmpty) {
      return;
    }
    final pool = List<_CheckersMove>.from(candidates)..shuffle();
    _applyMove(pool.first);
  }

  void _endTurn() {
    _selectedRow = null;
    _selectedCol = null;
    _legalMoves = const [];
    _mustContinueCapture = false;
    final nextPlayer = _turn.opponent;
    if (_checkersPieceCount(_board, nextPlayer) == 0 ||
        !_checkersHasAnyLegalMove(_board, nextPlayer)) {
      _winner = _turn;
      if (_turn == _CheckersPlayer.a) {
        _winsA++;
      } else {
        _winsB++;
      }
    } else {
      _turn = nextPlayer;
    }
  }

  void _onCellTap(int row, int col) {
    if (_winner != null) {
      return;
    }
    final move = _legalMoves
        .where((m) => m.toRow == row && m.toCol == col)
        .toList(growable: false);
    if (move.isNotEmpty) {
      _applyMove(move.first);
      return;
    }
    if (_mustContinueCapture) {
      return;
    }
    _selectCell(row, col);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1E4D3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1E4D3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        title: const Text(
          'Damas',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _resetGame,
            icon: const Icon(Icons.refresh, color: Color(0xFF1A1A1A)),
            tooltip: 'Novo jogo',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _CheckersStatusBar(
                    turn: _turn,
                    winner: _winner,
                    piecesA: _checkersPieceCount(_board, _CheckersPlayer.a),
                    piecesB: _checkersPieceCount(_board, _CheckersPlayer.b),
                  ),
                  const SizedBox(height: 10),
                  _CheckersScoreBoard(
                    labelA: widget.vsComputer ? 'Você' : 'Jogador 1',
                    labelB: widget.vsComputer ? 'Computador' : 'Jogador 2',
                    winsA: _winsA,
                    winsB: _winsB,
                  ),
                  const SizedBox(height: 16),
                  AspectRatio(
                    aspectRatio: 1,
                    child: _CheckersBoardView(
                      board: _board,
                      selectedRow: _selectedRow,
                      selectedCol: _selectedCol,
                      legalMoves: _legalMoves,
                      onCellTap: _onCellTap,
                      flipped: true,
                    ),
                  ),
                  if (_winner != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _resetGame,
                      icon: const Icon(Icons.replay),
                      label: const Text('Jogar novamente'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckersStatusBar extends StatelessWidget {
  const _CheckersStatusBar({
    required this.turn,
    required this.winner,
    required this.piecesA,
    required this.piecesB,
  });

  final _CheckersPlayer turn;
  final _CheckersPlayer? winner;
  final int piecesA;
  final int piecesB;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0DD)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              winner != null
                  ? '${winner!.label} venceu!'
                  : 'Vez de: ${turn.label}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          _CheckersPieceCountBadge(label: 'Claras', count: piecesA),
          const SizedBox(width: 8),
          _CheckersPieceCountBadge(label: 'Escuras', count: piecesB),
        ],
      ),
    );
  }
}

class _CheckersScoreBoard extends StatelessWidget {
  const _CheckersScoreBoard({
    required this.labelA,
    required this.labelB,
    required this.winsA,
    required this.winsB,
  });

  final String labelA;
  final String labelB;
  final int winsA;
  final int winsB;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0DD)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            color: Color(0xFFB45309),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Placar: $labelA $winsA x $winsB $labelB',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckersPieceCountBadge extends StatelessWidget {
  const _CheckersPieceCountBadge({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1E4D3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $count',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CheckersBoardView extends StatelessWidget {
  const _CheckersBoardView({
    required this.board,
    required this.selectedRow,
    required this.selectedCol,
    required this.legalMoves,
    required this.onCellTap,
    this.flipped = false,
  });

  final _CheckersBoard board;
  final int? selectedRow;
  final int? selectedCol;
  final List<_CheckersMove> legalMoves;
  final void Function(int row, int col) onCellTap;
  final bool flipped;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7A4A24), Color(0xFF54311A), Color(0xFF7A4A24)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Column(
          children: [
            for (var visualRow = 0; visualRow < 8; visualRow++)
              Expanded(
                child: Row(
                  children: [
                    for (var visualCol = 0; visualCol < 8; visualCol++)
                      Expanded(
                        child: _buildCell(
                          flipped ? 7 - visualRow : visualRow,
                          flipped ? 7 - visualCol : visualCol,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    final isDarkSquare = (row + col).isOdd;
    final piece = board[row][col];
    final isSelected = row == selectedRow && col == selectedCol;
    final isLegalTarget = legalMoves.any(
      (m) => m.toRow == row && m.toCol == col,
    );

    return GestureDetector(
      onTap: () => onCellTap(row, col),
      child: Container(
        decoration: BoxDecoration(
          gradient: isDarkSquare
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6B4226), Color(0xFF45290F)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEBCBA3), Color(0xFFD3A56F)],
                ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isSelected)
              Container(
                color: const Color(0xFFFFCA28).withValues(alpha: 0.45),
              ),
            if (isLegalTarget)
              FractionallySizedBox(
                widthFactor: 0.32,
                heightFactor: 0.32,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFCA28).withValues(alpha: 0.8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 3),
                    ],
                  ),
                ),
              ),
            if (piece != null) _buildPiece(piece),
          ],
        ),
      ),
    );
  }

  Widget _buildPiece(_CheckersPiece piece) {
    final isLight = piece.owner == _CheckersPlayer.a;
    return FractionallySizedBox(
      widthFactor: 0.8,
      heightFactor: 0.8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 0.95,
            colors: isLight
                ? const [
                    Color(0xFFF6E3C5),
                    Color(0xFFD8A85E),
                    Color(0xFFA9763F),
                  ]
                : const [
                    Color(0xFF5C4030),
                    Color(0xFF3A2317),
                    Color(0xFF1E120A),
                  ],
          ),
          border: Border.all(
            color: isLight ? const Color(0xFF8B5A2B) : const Color(0xFF0D0805),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: piece.isKing
            ? Icon(
                Icons.star_rounded,
                color: isLight
                    ? const Color(0xFF6B4226)
                    : const Color(0xFFD8A85E),
                size: 18,
              )
            : null,
      ),
    );
  }
}

class _CheckersHomeScreen extends StatelessWidget {
  const _CheckersHomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1E4D3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1E4D3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        title: const Text(
          'Damas',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CheckersMenuButton(
              icon: Icons.computer_outlined,
              label: 'Jogar com o computador',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _CheckersGameScreen(vsComputer: true),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _CheckersMenuButton(
              icon: Icons.people_alt_outlined,
              label: 'Jogar com outro membro',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _CheckersMatchmakingScreen(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _CheckersMenuButton(
              icon: Icons.leaderboard_outlined,
              label: 'Placar global',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _CheckersLeaderboardScreen(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _CheckersMenuButton(
              icon: Icons.history_outlined,
              label: 'Histórico de partidas',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _CheckersHistoryScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckersMenuButton extends StatelessWidget {
  const _CheckersMenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0DD)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1A1A1A)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF6B6B68)),
          ],
        ),
      ),
    );
  }
}

CollectionReference<Map<String, dynamic>> get _checkersRoomsCollection =>
    FirebaseFirestore.instance.collection('checkers_rooms');

CollectionReference<Map<String, dynamic>> get _checkersPlayersCollection =>
    FirebaseFirestore.instance.collection('checkers_players');

CollectionReference<Map<String, dynamic>> get _checkersMatchesCollection =>
    FirebaseFirestore.instance.collection('checkers_matches');

String _checkersDisplayName(String? id) {
  final value = (id ?? '').trim();
  if (value.isEmpty) {
    return 'Desconhecido';
  }
  final namePart = value.split('@').first.replaceAll('.', ' ');
  if (namePart.isEmpty) {
    return value;
  }
  return namePart
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String _checkersSerializeBoard(_CheckersBoard board) {
  final buffer = StringBuffer();
  for (var row = 0; row < 8; row++) {
    for (var col = 0; col < 8; col++) {
      final piece = board[row][col];
      if (piece == null) {
        buffer.write('.');
      } else if (piece.owner == _CheckersPlayer.a) {
        buffer.write(piece.isKing ? 'A' : 'a');
      } else {
        buffer.write(piece.isKing ? 'B' : 'b');
      }
    }
  }
  return buffer.toString();
}

_CheckersBoard _checkersDeserializeBoard(String serialized) {
  final board = List.generate(8, (_) => List<_CheckersPiece?>.filled(8, null));
  for (var i = 0; i < 64 && i < serialized.length; i++) {
    final row = i ~/ 8;
    final col = i % 8;
    final char = serialized[i];
    if (char == '.') {
      continue;
    }
    final owner = (char == 'a' || char == 'A')
        ? _CheckersPlayer.a
        : _CheckersPlayer.b;
    final piece = _CheckersPiece(owner: owner);
    piece.isKing = char == 'A' || char == 'B';
    board[row][col] = piece;
  }
  return board;
}

String _checkersPlayerToCode(_CheckersPlayer player) =>
    player == _CheckersPlayer.a ? 'a' : 'b';

_CheckersPlayer _checkersPlayerFromCode(String code) =>
    code == 'a' ? _CheckersPlayer.a : _CheckersPlayer.b;

String get _checkersLocalUserId =>
    WorkspaceSession.instance.currentProfileId?.trim().toLowerCase() ??
    'desconhecido';

class _CheckersMatchmakingScreen extends StatefulWidget {
  const _CheckersMatchmakingScreen();

  @override
  State<_CheckersMatchmakingScreen> createState() =>
      _CheckersMatchmakingScreenState();
}

class _CheckersMatchmakingScreenState
    extends State<_CheckersMatchmakingScreen> {
  String? _waitingRoomId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  String _statusMessage = 'Procurando uma sala disponível...';
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _findOrCreateRoom();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _deleteWaitingRoomIfAny();
    super.dispose();
  }

  void _deleteWaitingRoomIfAny() {
    final roomId = _waitingRoomId;
    if (roomId == null || _navigated) {
      return;
    }
    _checkersRoomsCollection.doc(roomId).delete().catchError((_) {});
  }

  Future<void> _findOrCreateRoom() async {
    try {
      final waitingRooms = await _checkersRoomsCollection
          .where('status', isEqualTo: 'waiting')
          .limit(10)
          .get();
      final candidates = waitingRooms.docs
          .where((doc) => doc.data()['playerAId'] != _checkersLocalUserId)
          .toList(growable: false);
      for (final candidate in candidates) {
        if (await _tryJoinRoom(candidate.id)) {
          _navigateToGame(candidate.id, _CheckersPlayer.b);
          return;
        }
      }
      await _createRoomAndWait();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _statusMessage = 'Erro ao procurar sala: $error');
    }
  }

  Future<bool> _tryJoinRoom(String roomId) async {
    final docRef = _checkersRoomsCollection.doc(roomId);
    try {
      return await FirebaseFirestore.instance.runTransaction<bool>((
        transaction,
      ) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists || snapshot.data()?['status'] != 'waiting') {
          return false;
        }
        transaction.update(docRef, {
          'playerBId': _checkersLocalUserId,
          'status': 'playing',
          'updatedAt': DateTime.now().toIso8601String(),
        });
        return true;
      });
    } catch (_) {
      return false;
    }
  }

  Future<void> _createRoomAndWait() async {
    final docRef = _checkersRoomsCollection.doc();
    await docRef.set({
      'status': 'waiting',
      'playerAId': _checkersLocalUserId,
      'playerBId': null,
      'turn': 'a',
      'board': _checkersSerializeBoard(_checkersInitialBoard()),
      'winner': null,
      'winsA': 0,
      'winsB': 0,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    if (!mounted) {
      await docRef.delete().catchError((_) {});
      return;
    }
    setState(() {
      _waitingRoomId = docRef.id;
      _statusMessage = 'Sala criada. Aguardando outro membro entrar...';
    });
    _subscription = docRef.snapshots().listen((snapshot) {
      final data = snapshot.data();
      if (data != null && data['status'] == 'playing') {
        _navigateToGame(docRef.id, _CheckersPlayer.a);
      }
    });
  }

  void _navigateToGame(String roomId, _CheckersPlayer localPlayer) {
    if (_navigated || !mounted) {
      return;
    }
    _navigated = true;
    _subscription?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _CheckersOnlineGameScreen(
          roomId: roomId,
          localPlayer: localPlayer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1E4D3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1E4D3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        title: const Text(
          'Procurando oponente',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1A1A1A)),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckersOnlineGameScreen extends StatefulWidget {
  const _CheckersOnlineGameScreen({
    required this.roomId,
    required this.localPlayer,
  });

  final String roomId;
  final _CheckersPlayer localPlayer;

  @override
  State<_CheckersOnlineGameScreen> createState() =>
      _CheckersOnlineGameScreenState();
}

class _CheckersOnlineGameScreenState
    extends State<_CheckersOnlineGameScreen> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  _CheckersBoard _board = _checkersInitialBoard();
  _CheckersPlayer _turn = _CheckersPlayer.a;
  _CheckersPlayer? _winner;
  bool _roomClosed = false;
  int? _selectedRow;
  int? _selectedCol;
  List<_CheckersMove> _legalMoves = const [];
  bool _mustContinueCapture = false;
  int _winsA = 0;
  int _winsB = 0;
  String? _playerAId;
  String? _playerBId;

  DocumentReference<Map<String, dynamic>> get _docRef =>
      _checkersRoomsCollection.doc(widget.roomId);

  @override
  void initState() {
    super.initState();
    _subscription = _docRef.snapshots().listen(_onRoomUpdate);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onRoomUpdate(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!mounted) {
      return;
    }
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      setState(() => _roomClosed = true);
      return;
    }
    setState(() {
      _board = _checkersDeserializeBoard(data['board'] as String);
      _turn = _checkersPlayerFromCode(data['turn'] as String? ?? 'a');
      final winnerCode = data['winner'] as String?;
      _winner = winnerCode == null
          ? null
          : _checkersPlayerFromCode(winnerCode);
      _winsA = (data['winsA'] as num?)?.toInt() ?? 0;
      _winsB = (data['winsB'] as num?)?.toInt() ?? 0;
      _playerAId = data['playerAId'] as String?;
      _playerBId = data['playerBId'] as String?;
      _selectedRow = null;
      _selectedCol = null;
      _legalMoves = const [];
      _mustContinueCapture = false;
    });
  }

  bool get _isMyTurn =>
      !_roomClosed && _winner == null && _turn == widget.localPlayer;

  void _onCellTap(int row, int col) {
    if (!_isMyTurn) {
      return;
    }
    final targetMoves = _legalMoves
        .where((m) => m.toRow == row && m.toCol == col)
        .toList(growable: false);
    if (targetMoves.isNotEmpty) {
      _applyLocalMove(targetMoves.first);
      return;
    }
    if (_mustContinueCapture) {
      return;
    }
    final piece = _board[row][col];
    if (piece == null || piece.owner != widget.localPlayer) {
      return;
    }
    setState(() {
      _selectedRow = row;
      _selectedCol = col;
      _legalMoves = _checkersMovesForPiece(_board, row, col);
    });
  }

  void _applyLocalMove(_CheckersMove move) {
    final piece = _board[move.fromRow][move.fromCol]!;
    setState(() {
      _board[move.fromRow][move.fromCol] = null;
      if (move.isCapture) {
        _board[move.capturedRow!][move.capturedCol!] = null;
      }
      final promotionRow = piece.owner == _CheckersPlayer.a ? 7 : 0;
      if (move.toRow == promotionRow) {
        piece.isKing = true;
      }
      _board[move.toRow][move.toCol] = piece;

      if (move.isCapture) {
        final furtherCaptures = _checkersMovesForPiece(
          _board,
          move.toRow,
          move.toCol,
        ).where((m) => m.isCapture).toList(growable: false);
        if (furtherCaptures.isNotEmpty) {
          _selectedRow = move.toRow;
          _selectedCol = move.toCol;
          _legalMoves = furtherCaptures;
          _mustContinueCapture = true;
          return;
        }
      }
      _selectedRow = null;
      _selectedCol = null;
      _legalMoves = const [];
      _mustContinueCapture = false;
    });

    if (!_mustContinueCapture) {
      _commitTurnToRoom();
    }
  }

  Future<void> _commitTurnToRoom() async {
    final nextPlayer = widget.localPlayer.opponent;
    final opponentHasMoves = _checkersPieceCount(_board, nextPlayer) > 0 &&
        _checkersHasAnyLegalMove(_board, nextPlayer);
    final winner = opponentHasMoves ? null : widget.localPlayer;
    try {
      await _docRef.set({
        'board': _checkersSerializeBoard(_board),
        'turn': _checkersPlayerToCode(nextPlayer),
        'winner': winner == null ? null : _checkersPlayerToCode(winner),
        'updatedAt': DateTime.now().toIso8601String(),
        if (winner != null)
          (winner == _CheckersPlayer.a ? 'winsA' : 'winsB'):
              FieldValue.increment(1),
      }, SetOptions(merge: true));
      if (winner != null) {
        await _recordMatchResult(winner);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar jogada: $error')),
      );
    }
  }

  Future<void> _recordMatchResult(_CheckersPlayer winner) async {
    final winnerId = winner == _CheckersPlayer.a ? _playerAId : _playerBId;
    final loserId = winner == _CheckersPlayer.a ? _playerBId : _playerAId;
    if (winnerId == null || loserId == null) {
      return;
    }
    final batch = FirebaseFirestore.instance.batch();
    batch.set(_checkersMatchesCollection.doc(), {
      'playerAId': _playerAId,
      'playerBId': _playerBId,
      'winnerId': winnerId,
      'loserId': loserId,
      'roomId': widget.roomId,
      'finishedAt': DateTime.now().toIso8601String(),
    });
    batch.set(_checkersPlayersCollection.doc(winnerId), {
      'wins': FieldValue.increment(1),
      'gamesPlayed': FieldValue.increment(1),
    }, SetOptions(merge: true));
    batch.set(_checkersPlayersCollection.doc(loserId), {
      'losses': FieldValue.increment(1),
      'gamesPlayed': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> _requestRematch() async {
    try {
      await _docRef.set({
        'board': _checkersSerializeBoard(_checkersInitialBoard()),
        'turn': 'a',
        'winner': null,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao iniciar revanche: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1E4D3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1E4D3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        title: const Text(
          'Damas',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_roomClosed)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'A sala foi encerrada.',
                        style: TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  _CheckersStatusBar(
                    turn: _turn,
                    winner: _winner,
                    piecesA: _checkersPieceCount(_board, _CheckersPlayer.a),
                    piecesB: _checkersPieceCount(_board, _CheckersPlayer.b),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.localPlayer == _CheckersPlayer.a
                        ? 'Você joga com as claras'
                        : 'Você joga com as escuras',
                    style: const TextStyle(
                      color: Color(0xFF6B6B68),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CheckersScoreBoard(
                    labelA: widget.localPlayer == _CheckersPlayer.a
                        ? 'Você'
                        : 'Oponente',
                    labelB: widget.localPlayer == _CheckersPlayer.b
                        ? 'Você'
                        : 'Oponente',
                    winsA: _winsA,
                    winsB: _winsB,
                  ),
                  const SizedBox(height: 16),
                  AspectRatio(
                    aspectRatio: 1,
                    child: _CheckersBoardView(
                      board: _board,
                      selectedRow: _selectedRow,
                      selectedCol: _selectedCol,
                      legalMoves: _legalMoves,
                      onCellTap: _onCellTap,
                      flipped: widget.localPlayer == _CheckersPlayer.a,
                    ),
                  ),
                  if (_winner != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _requestRematch,
                          icon: const Icon(Icons.replay),
                          label: const Text('Jogar novamente'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.exit_to_app),
                          label: const Text('Sair'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckersLeaderboardScreen extends StatelessWidget {
  const _CheckersLeaderboardScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1E4D3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1E4D3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        title: const Text(
          'Placar global',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _checkersPlayersCollection
            .orderBy('wins', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar placar: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma partida online registrada ainda.',
                style: TextStyle(color: Color(0xFF6B6B68)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final wins = (data['wins'] as num?)?.toInt() ?? 0;
              final losses = (data['losses'] as num?)?.toInt() ?? 0;
              final gamesPlayed = (data['gamesPlayed'] as num?)?.toInt() ?? 0;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E0DD)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1E4D3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _checkersDisplayName(docs[index].id),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '$wins vitórias • $losses derrotas • $gamesPlayed jogos',
                      style: const TextStyle(
                        color: Color(0xFF6B6B68),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CheckersHistoryScreen extends StatelessWidget {
  const _CheckersHistoryScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1E4D3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1E4D3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        title: const Text(
          'Histórico de partidas',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _checkersMatchesCollection
            .orderBy('finishedAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar histórico: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma partida online registrada ainda.',
                style: TextStyle(color: Color(0xFF6B6B68)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final winnerId = data['winnerId'] as String? ?? '';
              final loserId = data['loserId'] as String? ?? '';
              final finishedAt = data['finishedAt'] as String?;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E0DD)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.emoji_events_outlined,
                          color: Color(0xFFB45309),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: _checkersDisplayName(winnerId),
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const TextSpan(text: '  venceu  '),
                                TextSpan(
                                  text: _checkersDisplayName(loserId),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (finishedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        finishedAt,
                        style: const TextStyle(
                          color: Color(0xFF6B6B68),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
