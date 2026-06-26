part of 'erp_danf_app.dart';

const List<String> _garticWordBank = [
  'Cachorro',
  'Gato',
  'Casa',
  'Sol',
  'Lua',
  'Carro',
  'Aviao',
  'Computador',
  'Telefone',
  'Arvore',
  'Flor',
  'Praia',
  'Montanha',
  'Livro',
  'Relogio',
  'Bicicleta',
  'Guitarra',
  'Pizza',
  'Hamburguer',
  'Sorvete',
  'Chuva',
  'Estrela',
  'Coracao',
  'Chapeu',
  'Sapato',
  'Oculos',
  'Cadeira',
  'Mesa',
  'Janela',
  'Porta',
  'Foguete',
  'Robo',
  'Fantasma',
  'Bruxa',
  'Dragao',
  'Castelo',
  'Navio',
  'Peixe',
  'Passaro',
  'Borboleta',
];

const Duration _garticRoundDuration = Duration(seconds: 70);

const List<int> _garticPalette = [
  0xFF1A1A1A,
  0xFFB91C1C,
  0xFF1D4ED8,
  0xFF15803D,
  0xFFB45309,
  0xFF7C3AED,
  0xFFFFFFFF,
];

String _garticNormalize(String value) {
  var result = value.trim().toLowerCase();
  const accents = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c',
  };
  accents.forEach((accented, plain) {
    result = result.replaceAll(accented, plain);
  });
  return result;
}

CollectionReference<Map<String, dynamic>> get _garticRoomsCollection =>
    FirebaseFirestore.instance.collection('gartic_rooms');

CollectionReference<Map<String, dynamic>> _garticPlayersCollection(
  String roomId,
) => _garticRoomsCollection.doc(roomId).collection('players');

CollectionReference<Map<String, dynamic>> _garticGuessesCollection(
  String roomId,
) => _garticRoomsCollection.doc(roomId).collection('guesses');

CollectionReference<Map<String, dynamic>> get _garticGlobalPlayersCollection =>
    FirebaseFirestore.instance.collection('gartic_players');

CollectionReference<Map<String, dynamic>> get _garticMatchesCollection =>
    FirebaseFirestore.instance.collection('gartic_matches');

class _GarticPoint {
  const _GarticPoint(this.dx, this.dy);

  final double dx;
  final double dy;

  Map<String, dynamic> toMap() => {'x': dx, 'y': dy};

  factory _GarticPoint.fromMap(Map<String, dynamic> map) => _GarticPoint(
    (map['x'] as num).toDouble(),
    (map['y'] as num).toDouble(),
  );
}

class _GarticStroke {
  const _GarticStroke({
    required this.points,
    required this.colorValue,
    required this.strokeWidth,
  });

  final List<_GarticPoint> points;
  final int colorValue;
  final double strokeWidth;

  Map<String, dynamic> toMap() => {
    'points': points.map((p) => p.toMap()).toList(),
    'color': colorValue,
    'width': strokeWidth,
  };

  factory _GarticStroke.fromMap(Map<String, dynamic> map) => _GarticStroke(
    points: (map['points'] as List<dynamic>)
        .map((p) => _GarticPoint.fromMap(p as Map<String, dynamic>))
        .toList(growable: false),
    colorValue: (map['color'] as num).toInt(),
    strokeWidth: (map['width'] as num).toDouble(),
  );
}

class _GarticCanvasPainter extends CustomPainter {
  _GarticCanvasPainter(this.strokes);

  final List<_GarticStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = Color(stroke.colorValue)
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (stroke.points.length == 1) {
        final p = stroke.points.first;
        canvas.drawCircle(
          Offset(p.dx * size.width, p.dy * size.height),
          stroke.strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
        continue;
      }
      final path = Path()
        ..moveTo(
          stroke.points.first.dx * size.width,
          stroke.points.first.dy * size.height,
        );
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GarticCanvasPainter oldDelegate) => true;
}

String get _garticLocalUserId =>
    WorkspaceSession.instance.currentProfileId?.trim().toLowerCase() ??
    'desconhecido';

class _GarticHomeScreen extends StatefulWidget {
  const _GarticHomeScreen();

  @override
  State<_GarticHomeScreen> createState() => _GarticHomeScreenState();
}

class _GarticHomeScreenState extends State<_GarticHomeScreen> {
  bool _creating = false;

  Future<void> _createRoom() async {
    if (_creating) {
      return;
    }
    setState(() => _creating = true);
    try {
      final docRef = _garticRoomsCollection.doc();
      final myId = _garticLocalUserId;
      final now = DateTime.now().toIso8601String();
      await docRef.set({
        'status': 'lobby',
        'hostId': myId,
        'currentDrawerId': null,
        'currentWord': null,
        'roundNumber': 0,
        'roundEndsAt': null,
        'strokes': <Map<String, dynamic>>[],
        'playerOrder': [myId],
        'createdAt': now,
        'updatedAt': now,
      });
      await _garticPlayersCollection(docRef.id).doc(myId).set({
        'name': _checkersDisplayName(myId),
        'score': 0,
        'hasGuessedCorrectly': false,
        'joinedAt': now,
      });
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _GarticRoomScreen(roomId: docRef.id),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao criar sala: $error')));
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _joinRoom(String roomId) async {
    final myId = _garticLocalUserId;
    final now = DateTime.now().toIso8601String();
    try {
      await _garticRoomsCollection.doc(roomId).update({
        'playerOrder': FieldValue.arrayUnion([myId]),
        'updatedAt': now,
      });
      await _garticPlayersCollection(roomId).doc(myId).set({
        'name': _checkersDisplayName(myId),
        'score': 0,
        'hasGuessedCorrectly': false,
        'joinedAt': now,
      }, SetOptions(merge: true));
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _GarticRoomScreen(roomId: roomId)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao entrar na sala: $error')));
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
          'Gartic',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _creating ? null : _createRoom,
                  icon: _creating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle_outline),
                  label: const Text('Criar sala'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _GarticLeaderboardScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.leaderboard_outlined),
                  label: const Text('Placar global'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _GarticHistoryScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.history_outlined),
                  label: const Text('Histórico'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _garticRoomsCollection
                  .where('status', isEqualTo: 'lobby')
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhuma sala aberta. Crie uma para começar!',
                      style: TextStyle(color: Color(0xFF6B6B68)),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final hostId = data['hostId'] as String? ?? '';
                    final playerOrder =
                        (data['playerOrder'] as List<dynamic>?) ?? const [];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE0E0DD)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sala de ${_checkersDisplayName(hostId)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${playerOrder.length} jogador(es)',
                                  style: const TextStyle(
                                    color: Color(0xFF6B6B68),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: () => _joinRoom(docs[index].id),
                            child: const Text('Entrar'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GarticPlayer {
  const _GarticPlayer({
    required this.id,
    required this.name,
    required this.score,
    required this.hasGuessedCorrectly,
  });

  final String id;
  final String name;
  final int score;
  final bool hasGuessedCorrectly;
}

class _GarticRoomScreen extends StatefulWidget {
  const _GarticRoomScreen({required this.roomId});

  final String roomId;

  @override
  State<_GarticRoomScreen> createState() => _GarticRoomScreenState();
}

class _GarticRoomScreenState extends State<_GarticRoomScreen> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _playersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _guessesSub;
  Timer? _ticker;

  Map<String, dynamic>? _roomData;
  List<_GarticPlayer> _players = const [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _guesses = const [];
  bool _roomClosed = false;
  Duration _remaining = Duration.zero;

  final List<_GarticStroke> _localStrokes = [];
  List<_GarticPoint> _currentPoints = [];
  int _selectedColor = _garticPalette.first;
  Timer? _strokeWriteDebounce;

  final _guessController = TextEditingController();

  String get _myId => _garticLocalUserId;

  @override
  void initState() {
    super.initState();
    _roomSub = _garticRoomsCollection.doc(widget.roomId).snapshots().listen(
      _onRoomUpdate,
    );
    _playersSub = _garticPlayersCollection(widget.roomId)
        .snapshots()
        .listen(_onPlayersUpdate);
    _guessesSub = _garticGuessesCollection(widget.roomId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;
          setState(() => _guesses = snapshot.docs);
        });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _playersSub?.cancel();
    _guessesSub?.cancel();
    _ticker?.cancel();
    _strokeWriteDebounce?.cancel();
    _guessController.dispose();
    _leaveRoomIfStillInLobby();
    super.dispose();
  }

  void _leaveRoomIfStillInLobby() {
    final data = _roomData;
    if (data == null || data['status'] != 'lobby') {
      return;
    }
    _garticRoomsCollection.doc(widget.roomId).update({
      'playerOrder': FieldValue.arrayRemove([_myId]),
    }).catchError((_) {});
    _garticPlayersCollection(widget.roomId).doc(_myId).delete().catchError(
      (_) {},
    );
  }

  void _onRoomUpdate(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!mounted) {
      return;
    }
    if (!snapshot.exists) {
      setState(() => _roomClosed = true);
      return;
    }
    final data = snapshot.data();
    setState(() {
      _roomData = data;
      final strokesRaw = (data?['strokes'] as List<dynamic>?) ?? const [];
      _localStrokes
        ..clear()
        ..addAll(
          strokesRaw.map(
            (s) => _GarticStroke.fromMap(s as Map<String, dynamic>),
          ),
        );
    });
    _onTick();
  }

  void _onPlayersUpdate(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!mounted) {
      return;
    }
    final players = snapshot.docs.map((doc) {
      final data = doc.data();
      return _GarticPlayer(
        id: doc.id,
        name: (data['name'] as String?) ?? _checkersDisplayName(doc.id),
        score: (data['score'] as num?)?.toInt() ?? 0,
        hasGuessedCorrectly: data['hasGuessedCorrectly'] == true,
      );
    }).toList(growable: false)
      ..sort((a, b) => b.score.compareTo(a.score));
    setState(() => _players = players);
  }

  void _onTick() {
    final data = _roomData;
    if (data == null || data['status'] != 'drawing') {
      return;
    }
    final endsAtRaw = data['roundEndsAt'] as String?;
    if (endsAtRaw == null) {
      return;
    }
    final endsAt = DateTime.tryParse(endsAtRaw);
    if (endsAt == null) {
      return;
    }
    final remaining = endsAt.difference(DateTime.now());
    if (!mounted) {
      return;
    }
    setState(() {
      _remaining = remaining.isNegative ? Duration.zero : remaining;
    });
    if (remaining.isNegative && _isCurrentDrawer) {
      _endRound();
    }
  }

  bool get _isHost => _roomData?['hostId'] == _myId;
  bool get _isCurrentDrawer => _roomData?['currentDrawerId'] == _myId;
  List<String> get _playerOrder =>
      ((_roomData?['playerOrder'] as List<dynamic>?) ?? const [])
          .cast<String>();

  Future<void> _startGame() async {
    if (_playerOrder.isEmpty) {
      return;
    }
    final word = (_garticWordBank.toList()..shuffle()).first;
    final now = DateTime.now();
    final batch = FirebaseFirestore.instance.batch();
    for (final playerId in _playerOrder) {
      batch.set(
        _garticPlayersCollection(widget.roomId).doc(playerId),
        {'hasGuessedCorrectly': false},
        SetOptions(merge: true),
      );
    }
    batch.set(_garticRoomsCollection.doc(widget.roomId), {
      'status': 'drawing',
      'currentDrawerId': _playerOrder.first,
      'currentWord': word,
      'roundNumber': 1,
      'roundEndsAt': now.add(_garticRoundDuration).toIso8601String(),
      'strokes': <Map<String, dynamic>>[],
      'updatedAt': now.toIso8601String(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> _endRound() async {
    try {
      await _garticRoomsCollection.doc(widget.roomId).set({
        'status': 'roundEnd',
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _nextRound() async {
    final order = _playerOrder;
    final currentDrawer = _roomData?['currentDrawerId'] as String? ?? '';
    final currentIndex = order.indexOf(currentDrawer);
    final roundNumber = (_roomData?['roundNumber'] as num?)?.toInt() ?? 1;
    if (roundNumber >= order.length) {
      await _garticRoomsCollection.doc(widget.roomId).set({
        'status': 'finished',
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      await _recordMatchResult();
      return;
    }
    final nextIndex = (currentIndex + 1) % order.length;
    final word = (_garticWordBank.toList()..shuffle()).first;
    final now = DateTime.now();
    final batch = FirebaseFirestore.instance.batch();
    for (final playerId in order) {
      batch.set(
        _garticPlayersCollection(widget.roomId).doc(playerId),
        {'hasGuessedCorrectly': false},
        SetOptions(merge: true),
      );
    }
    batch.set(_garticRoomsCollection.doc(widget.roomId), {
      'status': 'drawing',
      'currentDrawerId': order[nextIndex],
      'currentWord': word,
      'roundNumber': roundNumber + 1,
      'roundEndsAt': now.add(_garticRoundDuration).toIso8601String(),
      'strokes': <Map<String, dynamic>>[],
      'updatedAt': now.toIso8601String(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> _recordMatchResult() async {
    if (_players.isEmpty) {
      return;
    }
    final sorted = List<_GarticPlayer>.from(_players)
      ..sort((a, b) => b.score.compareTo(a.score));
    final winner = sorted.first;
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.set(_garticMatchesCollection.doc(), {
        'roomId': widget.roomId,
        'winnerId': winner.id,
        'players': sorted
            .map((p) => {'id': p.id, 'name': p.name, 'score': p.score})
            .toList(),
        'finishedAt': DateTime.now().toIso8601String(),
      });
      for (final player in sorted) {
        batch.set(_garticGlobalPlayersCollection.doc(player.id), {
          'gamesPlayed': FieldValue.increment(1),
          'totalScore': FieldValue.increment(player.score),
          'wins': FieldValue.increment(player.id == winner.id ? 1 : 0),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (_) {}
  }

  Future<void> _playAgain() async {
    final order = _playerOrder;
    final batch = FirebaseFirestore.instance.batch();
    for (final playerId in order) {
      batch.set(
        _garticPlayersCollection(widget.roomId).doc(playerId),
        {'score': 0, 'hasGuessedCorrectly': false},
        SetOptions(merge: true),
      );
    }
    batch.set(_garticRoomsCollection.doc(widget.roomId), {
      'status': 'lobby',
      'currentDrawerId': null,
      'currentWord': null,
      'roundNumber': 0,
      'roundEndsAt': null,
      'strokes': <Map<String, dynamic>>[],
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  void _addPointToCurrentStroke(Offset localPosition, Size canvasSize) {
    if (canvasSize.width == 0 || canvasSize.height == 0) {
      return;
    }
    setState(() {
      _currentPoints = List.of(_currentPoints)
        ..add(
          _GarticPoint(
            (localPosition.dx / canvasSize.width).clamp(0, 1),
            (localPosition.dy / canvasSize.height).clamp(0, 1),
          ),
        );
    });
    _scheduleStrokeWrite();
  }

  void _scheduleStrokeWrite() {
    _strokeWriteDebounce?.cancel();
    _strokeWriteDebounce = Timer(
      const Duration(milliseconds: 150),
      _writeStrokesToRoom,
    );
  }

  void _commitCurrentStroke() {
    if (_currentPoints.isNotEmpty) {
      _localStrokes.add(
        _GarticStroke(
          points: _currentPoints,
          colorValue: _selectedColor,
          strokeWidth: 5,
        ),
      );
    }
    _currentPoints = [];
    _writeStrokesToRoom();
  }

  Future<void> _writeStrokesToRoom() async {
    final allStrokes = List<_GarticStroke>.from(_localStrokes);
    if (_currentPoints.isNotEmpty) {
      allStrokes.add(
        _GarticStroke(
          points: _currentPoints,
          colorValue: _selectedColor,
          strokeWidth: 5,
        ),
      );
    }
    try {
      await _garticRoomsCollection.doc(widget.roomId).update({
        'strokes': allStrokes.map((s) => s.toMap()).toList(),
      });
    } catch (_) {}
  }

  Future<void> _clearCanvas() async {
    setState(() {
      _localStrokes.clear();
      _currentPoints = [];
    });
    try {
      await _garticRoomsCollection.doc(widget.roomId).update({
        'strokes': <Map<String, dynamic>>[],
      });
    } catch (_) {}
  }

  Future<void> _submitGuess() async {
    final text = _guessController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _guessController.clear();
    final word = _roomData?['currentWord'] as String? ?? '';
    final isCorrect =
        _garticNormalize(text) == _garticNormalize(word) && word.isNotEmpty;
    final drawerId = _roomData?['currentDrawerId'] as String?;
    final myName = _checkersDisplayName(_myId);
    try {
      await _garticGuessesCollection(widget.roomId).add({
        'playerId': _myId,
        'name': myName,
        'text': isCorrect ? 'acertou a palavra!' : text,
        'correct': isCorrect,
        'createdAt': DateTime.now().toIso8601String(),
      });
      if (isCorrect) {
        final batch = FirebaseFirestore.instance.batch();
        batch.set(_garticPlayersCollection(widget.roomId).doc(_myId), {
          'score': FieldValue.increment(10),
          'hasGuessedCorrectly': true,
        }, SetOptions(merge: true));
        if (drawerId != null) {
          batch.set(_garticPlayersCollection(widget.roomId).doc(drawerId), {
            'score': FieldValue.increment(5),
          }, SetOptions(merge: true));
        }
        await batch.commit();
      }
    } catch (_) {}
  }

  bool get _myHasGuessedCorrectly => _players
      .firstWhere(
        (p) => p.id == _myId,
        orElse: () => const _GarticPlayer(
          id: '',
          name: '',
          score: 0,
          hasGuessedCorrectly: false,
        ),
      )
      .hasGuessedCorrectly;

  @override
  Widget build(BuildContext context) {
    final status = _roomData?['status'] as String?;
    return Scaffold(
      backgroundColor: const Color(0xFFF1E4D3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1E4D3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        title: const Text(
          'Gartic',
          style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: _roomClosed
            ? const Center(child: Text('A sala foi encerrada.'))
            : _roomData == null
            ? const Center(child: CircularProgressIndicator())
            : switch (status) {
                'lobby' => _buildLobby(),
                'drawing' => _buildDrawing(),
                'roundEnd' => _buildRoundEnd(),
                'finished' => _buildFinished(),
                _ => const Center(child: CircularProgressIndicator()),
              },
      ),
    );
  }

  Widget _buildLobby() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sala de espera',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              for (final player in _players)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E0DD)),
                    ),
                    child: Text(
                      player.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (_isHost) ...[
                FilledButton.icon(
                  onPressed: _playerOrder.isEmpty ? null : _startGame,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Iniciar jogo'),
                ),
                if (_playerOrder.length < 2) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Modo demonstração: sozinho você pode testar o desenho, '
                    'mas só dá para ver alguém adivinhando com 2+ jogadores na sala.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6B6B68), fontSize: 12),
                  ),
                ],
              ] else
                const Text(
                  'Aguardando o anfitrião iniciar o jogo...',
                  style: TextStyle(color: Color(0xFF6B6B68)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawing() {
    final word = _roomData?['currentWord'] as String? ?? '';
    final isDrawer = _isCurrentDrawer;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final canvasArea = Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _GarticTopBar(
                remaining: _remaining,
                wordOrHint: isDrawer
                    ? word
                    : '_' * word.replaceAll(' ', '').length,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE0E0DD)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isDrawer
                      ? LayoutBuilder(
                          builder: (context, canvasConstraints) {
                            final size = Size(
                              canvasConstraints.maxWidth,
                              canvasConstraints.maxHeight,
                            );
                            return GestureDetector(
                              onPanStart: (details) => _addPointToCurrentStroke(
                                details.localPosition,
                                size,
                              ),
                              onPanUpdate: (details) =>
                                  _addPointToCurrentStroke(
                                    details.localPosition,
                                    size,
                                  ),
                              onPanEnd: (_) => _commitCurrentStroke(),
                              child: CustomPaint(
                                size: size,
                                painter: _GarticCanvasPainter([
                                  ..._localStrokes,
                                  if (_currentPoints.isNotEmpty)
                                    _GarticStroke(
                                      points: _currentPoints,
                                      colorValue: _selectedColor,
                                      strokeWidth: 5,
                                    ),
                                ]),
                              ),
                            );
                          },
                        )
                      : CustomPaint(painter: _GarticCanvasPainter(_localStrokes)),
                ),
              ),
              if (isDrawer) ...[
                const SizedBox(height: 12),
                _GarticDrawerToolbar(
                  selectedColor: _selectedColor,
                  onColorSelected: (color) =>
                      setState(() => _selectedColor = color),
                  onClear: _clearCanvas,
                  onFinishRound: _endRound,
                ),
              ],
            ],
          ),
        );
        final sidePanel = _GarticSidePanel(
          players: _players,
          guesses: _guesses,
          isDrawer: isDrawer,
          hasGuessedCorrectly: _myHasGuessedCorrectly,
          guessController: _guessController,
          onSubmitGuess: _submitGuess,
        );
        if (isWide) {
          return Row(
            children: [
              Expanded(flex: 3, child: canvasArea),
              SizedBox(
                width: 280,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  child: sidePanel,
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: canvasArea),
            SizedBox(
              height: 220,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: sidePanel,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoundEnd() {
    final word = _roomData?['currentWord'] as String? ?? '';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Fim da rodada!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'A palavra era: $word',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _GarticScoreboard(players: _players),
              const SizedBox(height: 16),
              if (_isHost)
                FilledButton.icon(
                  onPressed: _nextRound,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Próxima rodada'),
                )
              else
                const Text(
                  'Aguardando o anfitrião continuar...',
                  style: TextStyle(color: Color(0xFF6B6B68)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinished() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                size: 40,
                color: Color(0xFFB45309),
              ),
              const SizedBox(height: 8),
              const Text(
                'Jogo finalizado!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _GarticScoreboard(players: _players),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isHost)
                    FilledButton.icon(
                      onPressed: _playAgain,
                      icon: const Icon(Icons.replay),
                      label: const Text('Jogar de novo'),
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
          ),
        ),
      ),
    );
  }
}

class _GarticTopBar extends StatelessWidget {
  const _GarticTopBar({required this.remaining, required this.wordOrHint});

  final Duration remaining;
  final String wordOrHint;

  @override
  Widget build(BuildContext context) {
    final seconds = remaining.inSeconds.clamp(0, 999);
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
          Icon(Icons.timer_outlined, color: const Color(0xFF6B6B68), size: 18),
          const SizedBox(width: 6),
          Text(
            '${seconds}s',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              wordOrHint.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GarticDrawerToolbar extends StatelessWidget {
  const _GarticDrawerToolbar({
    required this.selectedColor,
    required this.onColorSelected,
    required this.onClear,
    required this.onFinishRound,
  });

  final int selectedColor;
  final ValueChanged<int> onColorSelected;
  final VoidCallback onClear;
  final VoidCallback onFinishRound;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final colorValue in _garticPalette)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onColorSelected(colorValue),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Color(colorValue),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectedColor == colorValue
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFFE0E0DD),
                    width: selectedColor == colorValue ? 3 : 1,
                  ),
                ),
              ),
            ),
          ),
        const Spacer(),
        IconButton(
          onPressed: onClear,
          icon: const Icon(Icons.layers_clear_outlined),
          tooltip: 'Limpar desenho',
        ),
        OutlinedButton(
          onPressed: onFinishRound,
          child: const Text('Encerrar rodada'),
        ),
      ],
    );
  }
}

class _GarticSidePanel extends StatelessWidget {
  const _GarticSidePanel({
    required this.players,
    required this.guesses,
    required this.isDrawer,
    required this.hasGuessedCorrectly,
    required this.guessController,
    required this.onSubmitGuess,
  });

  final List<_GarticPlayer> players;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> guesses;
  final bool isDrawer;
  final bool hasGuessedCorrectly;
  final TextEditingController guessController;
  final VoidCallback onSubmitGuess;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0E0DD)),
            ),
            child: ListView(
              children: [
                for (final player in players)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            player.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: player.hasGuessedCorrectly
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        Text(
                          '${player.score}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                const Divider(),
                for (final guessDoc in guesses.reversed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${guessDoc.data()['name']}: ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: guessDoc.data()['text'] as String? ?? '',
                            style: TextStyle(
                              color: guessDoc.data()['correct'] == true
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFF1A1A1A),
                              fontWeight: guessDoc.data()['correct'] == true
                                  ? FontWeight.w800
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!isDrawer) ...[
          const SizedBox(height: 8),
          if (hasGuessedCorrectly)
            const Text(
              'Você já acertou! Aguarde a próxima rodada.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF15803D),
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: guessController,
                    decoration: const InputDecoration(
                      hintText: 'Digite seu palpite...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => onSubmitGuess(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onSubmitGuess,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

class _GarticScoreboard extends StatelessWidget {
  const _GarticScoreboard({required this.players});

  final List<_GarticPlayer> players;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < players.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0DD)),
              ),
              child: Row(
                children: [
                  Text(
                    '${i + 1}º',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      players[i].name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${players[i].score} pts',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GarticLeaderboardScreen extends StatelessWidget {
  const _GarticLeaderboardScreen();

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
        stream: _garticGlobalPlayersCollection
            .orderBy('wins', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Erro ao carregar placar: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma partida registrada ainda.',
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
              final gamesPlayed = (data['gamesPlayed'] as num?)?.toInt() ?? 0;
              final totalScore = (data['totalScore'] as num?)?.toInt() ?? 0;
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
                      '$wins vitórias • $gamesPlayed jogos • $totalScore pts',
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

class _GarticHistoryScreen extends StatelessWidget {
  const _GarticHistoryScreen();

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
        stream: _garticMatchesCollection
            .orderBy('finishedAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Erro ao carregar histórico: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma partida registrada ainda.',
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
              final players =
                  (data['players'] as List<dynamic>?) ?? const [];
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
                          child: Text(
                            '${_checkersDisplayName(winnerId)} venceu',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      players
                          .map(
                            (p) =>
                                '${(p as Map<String, dynamic>)['name']}: ${p['score']}',
                          )
                          .join(' • '),
                      style: const TextStyle(
                        color: Color(0xFF6B6B68),
                        fontSize: 12,
                      ),
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
