import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hydra_client/hydra_client.dart';

import 'fixtures/commit_sample_fixture.dart';
import 'services/snake_hydra_submit.dart';

enum _Dir { up, down, left, right }

class SnakeGameTab extends StatefulWidget {
  const SnakeGameTab({
    super.key,
    required this.currentSlot,
    this.hydraConfig,
    required this.isActive,
  });

  final int? currentSlot;
  final HydraClientConfig? hydraConfig;
  final bool isActive;

  @override
  State<SnakeGameTab> createState() => _SnakeGameTabState();
}

class _SnakeGameTabState extends State<SnakeGameTab> {
  static const _cols = 16;
  static const _rows = 22;
  static const _tick = Duration(milliseconds: 140);

  final _mnemonicCtrl = TextEditingController();
  final _rng = Random();
  final _focusNode = FocusNode(debugLabel: 'snake');

  Timer? _timer;
  bool _running = false;
  bool _busySubmit = false;
  String? _lastSubmit;
  String? _status;
  String _sessionId = 'init';
  int _stepIndex = 0;
  final List<_SnakeEvent> _queue = <_SnakeEvent>[];
  bool _draining = false;

  _Dir _dir = _Dir.right;
  _Dir _queuedDir = _Dir.right;
  final List<Point<int>> _snake = [];
  Point<int> _fruit = const Point(8, 10);
  int _score = 0;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _mnemonicCtrl.text = kSampleBip39Mnemonic;
    }
    _resetInternal();
  }

  @override
  void didUpdateWidget(covariant SnakeGameTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      // Tab got hidden (IndexedStack keeps it alive). Stop the timer so it
      // can't "die in the background" and show game-over immediately later.
      if (_running) _pause();
    }
    if (!oldWidget.isActive && widget.isActive) {
      // When returning to the tab, clear any previous game-over state.
      if (!_running && (_status?.startsWith('Game over:') ?? false)) {
        _resetInternal();
        if (mounted) setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mnemonicCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _resetInternal() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _busySubmit = false;
    _queue.clear();
    _draining = false;
    _lastSubmit = null;
    _status = null;
    _stepIndex = 0;
    _dir = _Dir.right;
    _queuedDir = _Dir.right;
    _snake
      ..clear()
      ..addAll([
        const Point(5, 10),
        const Point(4, 10),
        const Point(3, 10),
      ]);
    _score = 0;
    _spawnFruit();
  }

  void _reset() {
    _resetInternal();
    setState(() {});
  }

  void _startNew() {
    // Always start from a clean board.
    _resetInternal();
    _sessionId = _newSessionId();
    // Ensure keyboard shortcuts go to the game, not the TextField/IME.
    FocusManager.instance.primaryFocus?.unfocus();
    _focusNode.requestFocus();
    _running = true;
    _timer = Timer.periodic(_tick, (_) => _step());
    setState(() {});
  }

  String _newSessionId() {
    final a = DateTime.now().millisecondsSinceEpoch;
    final b = _rng.nextInt(1 << 32);
    return '${a.toRadixString(16)}-${b.toRadixString(16)}';
  }

  String _dirString(_Dir d) => switch (d) {
        _Dir.up => 'U',
        _Dir.down => 'D',
        _Dir.left => 'L',
        _Dir.right => 'R',
      };

  void _enqueue(_SnakeEvent e) {
    _queue.add(e);
    if (_queue.length > 2000) {
      // Avoid unbounded memory growth if the head/node can't keep up.
      _queue.removeRange(0, _queue.length - 2000);
    }
    if (!_draining) {
      _draining = true;
      unawaited(_drainQueue());
    }
  }

  Future<void> _drainQueue() async {
    while (mounted && _queue.isNotEmpty) {
      final cfg = widget.hydraConfig;
      final slot = widget.currentSlot;
      final mnemonic = _mnemonicCtrl.text.trim();
      if (cfg == null || slot == null || mnemonic.isEmpty) {
        // Can't submit right now; stop draining.
        break;
      }
      final e = _queue.removeAt(0);
      try {
        final ttl = slot + 50000;
        final res = await SnakeHydraSubmit.submitSnakeEvent(
          config: cfg,
          mnemonic: mnemonic,
          ttlSlot: ttl,
          sessionId: e.sessionId,
          step: e.step,
          eventType: e.type,
          x: e.x,
          y: e.y,
          dir: e.dir,
          score: e.score,
          length: e.length,
          reason: e.reason,
        );
        if (!mounted) return;
        setState(() => _lastSubmit = 'OK: $res');
      } catch (err) {
        if (!mounted) return;
        setState(() => _lastSubmit = 'Error: $err');
        // Keep draining; next events might still succeed.
      }
    }
    _draining = false;
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _busySubmit = false;
    setState(() {});
  }

  void _queueDir(_Dir next) {
    final cur = _queuedDir;
    if ((cur == _Dir.up && next == _Dir.down) ||
        (cur == _Dir.down && next == _Dir.up) ||
        (cur == _Dir.left && next == _Dir.right) ||
        (cur == _Dir.right && next == _Dir.left)) {
      return;
    }
    _queuedDir = next;
  }

  void _spawnFruit() {
    Point<int> p;
    do {
      p = Point(_rng.nextInt(_cols), _rng.nextInt(_rows));
    } while (_snake.contains(p));
    _fruit = p;
  }

  void _gameOver(String reason) {
    _pause();
    setState(() => _status = 'Game over: $reason');
    final head = _snake.isEmpty ? const Point(0, 0) : _snake.first;
    _enqueue(
      _SnakeEvent(
        sessionId: _sessionId,
        step: _stepIndex,
        type: 'game_over',
        x: head.x,
        y: head.y,
        dir: _dirString(_dir),
        score: _score,
        length: _snake.length,
        reason: reason,
      ),
    );
  }

  void _step() {
    _dir = _queuedDir;
    final head = _snake.first;
    final next = switch (_dir) {
      _Dir.up => Point(head.x, head.y - 1),
      _Dir.down => Point(head.x, head.y + 1),
      _Dir.left => Point(head.x - 1, head.y),
      _Dir.right => Point(head.x + 1, head.y),
    };

    if (next.x < 0 || next.x >= _cols || next.y < 0 || next.y >= _rows) {
      _gameOver('hit wall');
      return;
    }

    final willEat = next == _fruit;
    final tail = _snake.last;
    final bodyHit = _snake.contains(next) && !(next == tail && !willEat);
    if (bodyHit) {
      _gameOver('hit self');
      return;
    }

    _snake.insert(0, next);
    if (!willEat) {
      _snake.removeLast();
    } else {
      _score += 1;
      _spawnFruit();
    }
    _stepIndex += 1;
    _enqueue(
      _SnakeEvent(
        sessionId: _sessionId,
        step: _stepIndex,
        type: willEat ? 'fruit' : 'move',
        x: next.x,
        y: next.y,
        dir: _dirString(_dir),
        score: _score,
        length: _snake.length,
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.hydraConfig;
    final connected = cfg != null;
    final slotOk = widget.currentSlot != null;
    final canSubmit = connected && slotOk && _mnemonicCtrl.text.trim().isNotEmpty;
    final pending = _queue.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Snake (L2 tx on fruit)')),
      body: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowUp): _SnakeDirIntent(_Dir.up),
          SingleActivator(LogicalKeyboardKey.keyW): _SnakeDirIntent(_Dir.up),
          SingleActivator(LogicalKeyboardKey.arrowDown): _SnakeDirIntent(_Dir.down),
          SingleActivator(LogicalKeyboardKey.keyS): _SnakeDirIntent(_Dir.down),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _SnakeDirIntent(_Dir.left),
          SingleActivator(LogicalKeyboardKey.keyA): _SnakeDirIntent(_Dir.left),
          SingleActivator(LogicalKeyboardKey.arrowRight): _SnakeDirIntent(_Dir.right),
          SingleActivator(LogicalKeyboardKey.keyD): _SnakeDirIntent(_Dir.right),
          SingleActivator(LogicalKeyboardKey.space): _SnakeToggleIntent(),
          SingleActivator(LogicalKeyboardKey.enter): _SnakeToggleIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _SnakeDirIntent: CallbackAction<_SnakeDirIntent>(
              onInvoke: (i) {
                _queueDir(i.dir);
                return null;
              },
            ),
            _SnakeToggleIntent: CallbackAction<_SnakeToggleIntent>(
              onInvoke: (_) {
                if (_running) {
                  _pause();
                } else {
                  _startNew();
                }
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            focusNode: _focusNode,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
          TextField(
            controller: _mnemonicCtrl,
            decoration: const InputDecoration(
              labelText: 'BIP39 mnemonic',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _focusNode.requestFocus(),
            child: _SnakeBoard(cols: _cols, rows: _rows, snake: _snake, fruit: _fruit),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _running ? _pause : _startNew,
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                  label: Text(_running ? 'Pause' : 'Start'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(onPressed: () => _queueDir(_Dir.left), icon: const Icon(Icons.arrow_left)),
              Column(
                children: [
                  IconButton(onPressed: () => _queueDir(_Dir.up), icon: const Icon(Icons.arrow_drop_up)),
                  IconButton(onPressed: () => _queueDir(_Dir.down), icon: const Icon(Icons.arrow_drop_down)),
                ],
              ),
              IconButton(onPressed: () => _queueDir(_Dir.right), icon: const Icon(Icons.arrow_right)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Score: $_score  ·  Length: ${_snake.length}'),
          Text('Hydra: ${connected ? '${cfg.host}:${cfg.port}' : 'not connected'} · slot: ${widget.currentSlot ?? '?'}'),
          Text('Session: $_sessionId · step: $_stepIndex · queued: $pending'),
          if (!canSubmit) ...[
            const SizedBox(height: 6),
            Text(
              connected ? (slotOk ? 'Enter mnemonic to enable submissions.' : 'Waiting for Greetings slot…') : 'Connect on Hydra tab first.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_status != null) ...[
            const SizedBox(height: 6),
            Text(_status!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_busySubmit) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          if (_lastSubmit != null) ...[
            const SizedBox(height: 10),
            SelectableText(_lastSubmit!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SnakeDirIntent extends Intent {
  const _SnakeDirIntent(this.dir);

  final _Dir dir;
}

class _SnakeToggleIntent extends Intent {
  const _SnakeToggleIntent();
}

class _SnakeBoard extends StatelessWidget {
  const _SnakeBoard({required this.cols, required this.rows, required this.snake, required this.fruit});

  final int cols;
  final int rows;
  final List<Point<int>> snake;
  final Point<int> fruit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: cols / rows,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: CustomPaint(
          painter: _SnakePainter(
            cols: cols,
            rows: rows,
            snake: snake,
            fruit: fruit,
            snakeColor: cs.primary,
            fruitColor: cs.tertiary,
            gridColor: cs.outlineVariant.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}

class _SnakePainter extends CustomPainter {
  _SnakePainter({
    required this.cols,
    required this.rows,
    required this.snake,
    required this.fruit,
    required this.snakeColor,
    required this.fruitColor,
    required this.gridColor,
  });

  final int cols;
  final int rows;
  final List<Point<int>> snake;
  final Point<int> fruit;
  final Color snakeColor;
  final Color fruitColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var x = 0; x <= cols; x++) {
      final dx = x * cellW;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
    }
    for (var y = 0; y <= rows; y++) {
      final dy = y * cellH;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    Rect rectFor(Point<int> p) => Rect.fromLTWH(p.x * cellW, p.y * cellH, cellW, cellH)
        .deflate(min(cellW, cellH) * 0.12);

    final fruitPaint = Paint()..color = fruitColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rectFor(fruit), Radius.circular(min(cellW, cellH) * 0.25)),
      fruitPaint,
    );

    final snakePaint = Paint()..color = snakeColor;
    for (var i = 0; i < snake.length; i++) {
      final r = rectFor(snake[i]);
      final rad = (i == 0 ? 0.35 : 0.2) * min(cellW, cellH);
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(rad)), snakePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnakePainter old) {
    // `snake` is mutated in-place each tick; list identity stays the same.
    // Repaint unconditionally for a smooth game.
    return true;
  }
}

class _SnakeEvent {
  _SnakeEvent({
    required this.sessionId,
    required this.step,
    required this.type,
    required this.x,
    required this.y,
    required this.dir,
    required this.score,
    required this.length,
    this.reason,
  });

  final String sessionId;
  final int step;
  final String type;
  final int x;
  final int y;
  final String dir;
  final int score;
  final int length;
  final String? reason;
}

