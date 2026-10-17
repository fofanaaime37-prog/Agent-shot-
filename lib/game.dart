part of 'main.dart';

// ---------- Jeu ----------
class En {
  double bx, y, ph, amp;
  int type, hp;
  double x = 0, flash = 0;
  En(this.bx, this.y, this.type, this.hp, this.ph, this.amp) {
    x = bx;
  }
}

class Bar {
  Offset p;
  Bar(this.p);
}

class Bul {
  double x, y, vx, vy;
  double ox = 0, oy = 0;
  int bounces = 0;
  Bul(this.x, this.y, this.vx, this.vy) {
    ox = x;
    oy = y;
  }
}

class Pt {
  Offset p, v;
  double life;
  Color col;
  Pt(this.p, this.v, this.life, this.col);
}

class Game extends StatefulWidget {
  final VoidCallback onExit;
  final void Function(int level) onLevelDone;
  const Game({super.key, required this.onExit, required this.onLevelDone});
  @override
  State<Game> createState() => _GameState();
}

class _GameState extends State<Game> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Size sz = Size.zero;
  final rnd = Random();
  int level = Save.best;
  double px = 0.5, gt = 0, shake = 0;
  int dir = 1, ammo = 0, earned = 0, phase = 0; // 0 jeu, 1 gagne, 2 perdu
  bool needBuild = true;
  Offset? aim;
  List<En> enemies = [];
  List<Bar> bars = [];
  List<Rect> walls = [];
  List<Bul> bullets = [];
  List<Pt> parts = [];

  Offset get player => Offset(sz.width * px, sz.height * 0.22);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double _cl(double v, double a, double b) => v < a ? a : (v > b ? b : v);

  void _build() {
    final r = Random(level * 7919 + 13);
    final w = sz.width, h = sz.height;
    enemies = [];
    bars = [];
    walls = [];
    bullets = [];
    parts = [];
    earned = 0;
    phase = 0;

    bool free(Offset c, double d) {
      for (final e in enemies) {
        if ((Offset(e.bx, e.y) - c).distance < d) return false;
      }
      for (final b in bars) {
        if ((b.p - c).distance < d) return false;
      }
      return true;
    }

    Offset spot(double d) {
      Offset c = Offset(w * 0.5, h * 0.6);
      for (int i = 0; i < 40; i++) {
        c = Offset(45 + r.nextDouble() * (w - 90), h * 0.45 + r.nextDouble() * (h * 0.4));
        if (free(c, d)) break;
      }
      return c;
    }

    final n = min(3 + level ~/ 2, 9);
    for (int i = 0; i < n; i++) {
      final c = spot(70);
      int type = 0, hp = 1;
      double amp = 0;
      if (level >= 3 && r.nextDouble() < 0.35) {
        type = 1;
        amp = 35;
      } else if (level >= 5 && r.nextDouble() < 0.3) {
        type = 2;
        hp = 2;
      }
      enemies.add(En(c.dx, c.dy, type, hp, r.nextDouble() * 6, amp));
    }
    if (level >= 2) {
      final nb = min(1 + level ~/ 4, 3);
      for (int i = 0; i < nb; i++) {
        final t = enemies[r.nextInt(enemies.length)];
        final side = r.nextBool() ? 1 : -1;
        final c = Offset(
            _cl(t.bx + side * (55 + r.nextDouble() * 25), 30, w - 30),
            _cl(t.y + (r.nextDouble() - 0.5) * 30, h * 0.45, h * 0.85));
        if (free(c, 45)) bars.add(Bar(c));
      }
    }
    if (level >= 4) {
      final nw = min(level ~/ 4, 3);
      for (int i = 0; i < nw; i++) {
        final ww = 70 + r.nextDouble() * 60;
        final rect = Rect.fromLTWH(
            20 + r.nextDouble() * (w - 40 - ww), h * 0.36 + r.nextDouble() * h * 0.22, ww, 14);
        bool bad = false;
        for (final e in enemies) {
          if (rect.inflate(30).contains(Offset(e.bx, e.y))) bad = true;
        }
        for (final b in bars) {
          if (rect.inflate(25).contains(b.p)) bad = true;
        }
        if (!bad) walls.add(rect);
      }
    }
    ammo = n + 3 + enemies.where((e) => e.hp > 1).length;
  }

  void _burst(Offset p, Color col, int n) {
    for (int i = 0; i < n; i++) {
      final a = rnd.nextDouble() * 2 * pi;
      final sp = 80 + rnd.nextDouble() * 180;
      parts.add(Pt(p, Offset(cos(a) * sp, sin(a) * sp - 80), 1, col));
    }
  }

  void _kill(En e) {
    if (!enemies.remove(e)) return;
    earned++;
    _burst(Offset(e.x, e.y), const Color(0xFFE53935), 12);
    HapticFeedback.mediumImpact();
  }

  void _explode(Bar b0) {
    final q = <Bar>[b0];
    while (q.isNotEmpty) {
      final b = q.removeLast();
      if (!bars.remove(b)) continue;
      _burst(b.p, const Color(0xFFFF9800), 26);
      shake = 14;
      for (final e in List<En>.from(enemies)) {
        if ((Offset(e.x, e.y) - b.p).distance < 95) _kill(e);
      }
      for (final o in List<Bar>.from(bars)) {
        if ((o.p - b.p).distance < 95) q.add(o);
      }
    }
    HapticFeedback.heavyImpact();
  }

  void _moveBullets(double dt) {
    final dead = <Bul>[];
    for (final b in bullets) {
      b.ox = b.x;
      b.oy = b.y;
      final sp = sqrt(b.vx * b.vx + b.vy * b.vy);
      final steps = max(1, (sp * dt / 5).ceil());
      var sx = b.vx * dt / steps, sy = b.vy * dt / steps;
      for (int i = 0; i < steps; i++) {
        final nx = b.x + sx, ny = b.y + sy;
        bool hitWall = false;
        for (final wl in walls) {
          if (wl.contains(Offset(nx, ny))) {
            if (b.x < wl.left || b.x > wl.right) {
              b.vx = -b.vx;
            } else {
              b.vy = -b.vy;
            }
            hitWall = true;
            break;
          }
        }
        if (hitWall) {
          b.bounces++;
          if (b.bounces > 3) dead.add(b);
          HapticFeedback.selectionClick();
          break;
        }
        b.x = nx;
        b.y = ny;
        if (b.x < 0 || b.x > sz.width) {
          b.vx = -b.vx;
          b.x = b.x < 0 ? 0 : sz.width;
          sx = b.vx * dt / steps;
          b.bounces++;
          if (b.bounces > 3) {
            dead.add(b);
            break;
          }
        }
        if (b.y < 0 || b.y > sz.height) {
          dead.add(b);
          break;
        }
        En? he;
        for (final e in enemies) {
          if ((Offset(e.x, e.y) - Offset(b.x, b.y)).distance < 22) {
            he = e;
            break;
          }
        }
        if (he != null) {
          he.hp--;
          he.flash = 1;
          if (he.hp <= 0) {
            _kill(he);
          } else {
            HapticFeedback.lightImpact();
          }
          dead.add(b);
          break;
        }
        Bar? hb;
        for (final o in bars) {
          if ((o.p - Offset(b.x, b.y)).distance < 20) {
            hb = o;
            break;
          }
        }
        if (hb != null) {
          _explode(hb);
          dead.add(b);
          break;
        }
        sy = b.vy * dt / steps;
      }
    }
    bullets.removeWhere((b) => dead.contains(b));
  }

  void _tick(Duration t) {
    var dt = _last == Duration.zero ? 0.0 : (t - _last).inMicroseconds / 1e6;
    _last = t;
    if (dt > 0.05) dt = 0.05;
    if (sz == Size.zero) return;
    if (needBuild) {
      _build();
      needBuild = false;
    }
    final slow = (aim != null && phase == 0) ? 0.2 : 1.0;
    final sdt = dt * slow;
    gt += sdt;
    if (phase == 0) {
      px += dir * 0.2 * sdt;
      if (px > 0.85) {
        px = 0.85;
        dir = -1;
      }
      if (px < 0.15) {
        px = 0.15;
        dir = 1;
      }
    }
    for (final e in enemies) {
      e.x = e.type == 1 ? e.bx + sin(gt * 1.6 + e.ph) * e.amp : e.bx;
      if (e.flash > 0) e.flash -= dt * 4;
    }
    _moveBullets(dt);
    for (final q in parts) {
      q.p += q.v * dt;
      q.v = Offset(q.v.dx, q.v.dy + 500 * dt);
      q.life -= dt * 1.6;
    }
    parts.removeWhere((q) => q.life <= 0);
    if (shake > 0) shake = max(0.0, shake - dt * 30);
    if (phase == 0) {
      if (enemies.isEmpty) {
        _win();
      } else if (ammo == 0 && bullets.isEmpty) {
        phase = 2;
      }
    }
    setState(() {});
  }

  void _win() {
    phase = 1;
    Save.coins += earned + 5;
    if (level + 1 > Save.best) Save.best = level + 1;
    Save.save();
    HapticFeedback.vibrate();
    widget.onLevelDone(level);
  }

  void _fire() {
    final a = aim;
    aim = null;
    if (a == null || phase != 0 || ammo <= 0) return;
    final p = player;
    final d = a - p;
    if (d.distance < 8) return;
    final n = d / d.distance;
    bullets.add(Bul(p.dx + n.dx * 40, p.dy + 22 + n.dy * 40, n.dx * 950, n.dy * 950));
    ammo--;
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
  }

  Widget _overlay() {
    const big = TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900);
    final List<Widget> kids;
    if (phase == 1) {
      kids = [
        Text('Niveau $level terminé !', style: big),
        const SizedBox(height: 8),
        Text('+${earned + 5} pièces',
            style: const TextStyle(color: Color(0xFFFFEB3B), fontSize: 22)),
        const SizedBox(height: 20),
        ElevatedButton(
            onPressed: () {
              level++;
              needBuild = true;
            },
            child: const Text('Niveau suivant', style: TextStyle(fontSize: 20))),
        const SizedBox(height: 10),
        TextButton(
            onPressed: widget.onExit,
            child: const Text('Menu', style: TextStyle(color: Colors.white, fontSize: 18))),
      ];
    } else {
      kids = [
        const Text('Raté !', style: big),
        const SizedBox(height: 20),
        ElevatedButton(
            onPressed: () => needBuild = true,
            child: const Text('Réessayer', style: TextStyle(fontSize: 20))),
        const SizedBox(height: 10),
        TextButton(
            onPressed: widget.onExit,
            child: const Text('Menu', style: TextStyle(color: Colors.white, fontSize: 18))),
      ];
    }
    return Container(
      color: Colors.black54,
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: kids)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (c, box) {
      sz = Size(box.maxWidth, box.maxHeight);
      return Stack(children: [
        Positioned.fill(
          child: Listener(
            onPointerDown: (e) {
              if (phase == 0) aim = e.localPosition;
            },
            onPointerMove: (e) {
              if (phase == 0 && aim != null) aim = e.localPosition;
            },
            onPointerUp: (_) => _fire(),
            onPointerCancel: (_) => aim = null,
            child: CustomPaint(painter: _GP(this)),
          ),
        ),
        Positioned(
          top: 8,
          left: 12,
          right: 56,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Niveau $level',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              Text('Pièces : ${Save.coins}',
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 3,
                children: List.generate(
                    ammo, (i) => const Icon(Icons.circle, size: 11, color: Color(0xFFFFEB3B))),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: widget.onExit),
        ),
        if (phase != 0) Positioned.fill(child: _overlay()),
      ]);
    });
  }
}

class _GP extends CustomPainter {
  final _GameState g;
  _GP(this.g);

  @override
  void paint(Canvas c, Size s) {
    c.save();
    if (g.shake > 0) {
      c.translate((g.rnd.nextDouble() - 0.5) * g.shake, (g.rnd.nextDouble() - 0.5) * g.shake);
    }
    final rect = Offset.zero & s;
    c.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF4FC3F7), Color(0xFFB3E5FC), Color(0xFFFFE0B2)])
              .createShader(rect));
    c.drawCircle(Offset(s.width * 0.82, s.height * 0.1), 34, Paint()..color = const Color(0xFFFFF59D));
    for (int i = 0; i < 3; i++) {
      final cx = ((g.gt * 8 + i * s.width / 3) % (s.width + 160)) - 80;
      final cy = s.height * (0.08 + 0.1 * i);
      final pc = Paint()..color = Colors.white.withAlpha(200);
      c.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: 90, height: 32), pc);
      c.drawOval(Rect.fromCenter(center: Offset(cx + 25, cy - 12), width: 60, height: 30), pc);
    }

    final p = g.player;
    final rope = Paint()..color = const Color(0xFF5D4037)..strokeWidth = 3;
    final py = p.dy + 66;
    c.drawLine(Offset(p.dx - 40, 0), Offset(p.dx - 40, py), rope);
    c.drawLine(Offset(p.dx + 40, 0), Offset(p.dx + 40, py), rope);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(p.dx, py + 4), width: 96, height: 10),
            const Radius.circular(4)),
        Paint()..color = const Color(0xFF795548));

    for (final w in g.walls) {
      c.drawRRect(RRect.fromRectAndRadius(w, const Radius.circular(4)),
          Paint()..color = const Color(0xFF455A64));
      c.drawRect(Rect.fromLTWH(w.left, w.top, w.width, 4), Paint()..color = const Color(0xFF90A4AE));
    }
    for (final e in g.enemies) {
      drawEnemy(c, Offset(e.x, e.y), e.type, e.flash);
    }
    for (final b in g.bars) {
      drawBarrel(c, b.p);
    }
    if (g.aim != null && g.phase == 0) {
      final d = g.aim! - p;
      if (d.distance > 8) {
        final n = d / d.distance;
        for (int i = 1; i <= 10; i++) {
          c.drawCircle(p.translate(0, 22) + n * (40.0 + i * 14), 2.5, Paint()..color = Colors.white);
        }
      }
    }
    drawAgent(c, p, skins[Save.skin], g.aim, 1.0);
    for (final b in g.bullets) {
      c.drawLine(Offset(b.ox, b.oy), Offset(b.x, b.y),
          Paint()..color = const Color(0xFFFFEE58)..strokeWidth = 3);
      c.drawCircle(Offset(b.x, b.y), 4, Paint()..color = Colors.white);
    }
    for (final q in g.parts) {
      final a = (q.life.clamp(0.0, 1.0) * 255).toInt();
      c.drawCircle(q.p, 3.5, Paint()..color = q.col.withAlpha(a));
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_) => true;
}
