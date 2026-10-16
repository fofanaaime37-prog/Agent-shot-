import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// Mets true pour activer les pubs (la compilation le fait automatiquement).
const useAds = false;

// IDs de TEST Google (remplaces automatiquement dans la version finale).
const bannerId = 'ca-app-pub-3940256099942544/6300978111';
const interId = 'ca-app-pub-3940256099942544/1033173712';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Save.load();
  if (useAds) {
    try {
      await MobileAds.instance.initialize();
    } catch (_) {}
  }
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: Root()));
}

// ---------- Sauvegarde ----------
class Save {
  static int coins = 0, best = 1, skin = 0;
  static List<int> owned = [0];
  static File? _f;

  static Future<void> load() async {
    try {
      _f = File('${Directory.systemTemp.path}/agentshot_save.txt');
      if (await _f!.exists()) {
        final p = (await _f!.readAsString()).split(',');
        coins = int.parse(p[0]);
        best = int.parse(p[1]);
        skin = int.parse(p[2]);
        owned = p[3].split('|').map(int.parse).toList();
      }
    } catch (_) {}
  }

  static void save() {
    try {
      _f?.writeAsStringSync('$coins,$best,$skin,${owned.join('|')}');
    } catch (_) {}
  }
}

// ---------- Skins ----------
class Skin {
  final String name;
  final int price;
  final Color suit;
  final Color tie;
  final int hat;
  const Skin(this.name, this.price, this.suit, this.tie, this.hat);
}

const skins = <Skin>[
  Skin('Classique', 0, Color(0xFF263238), Color(0xFFE53935), 0),
  Skin('Rouge', 50, Color(0xFFB71C1C), Color(0xFFFFFFFF), 0),
  Skin('Or', 120, Color(0xFFFFB300), Color(0xFF212121), 1),
  Skin('Ninja', 200, Color(0xFF111111), Color(0xFF00E5FF), 2),
  Skin('Espace', 350, Color(0xFF6A1B9A), Color(0xFFFFEB3B), 3),
];

// ---------- Dessin des personnages ----------
void drawAgent(Canvas c, Offset p, Skin s, Offset? aim, double k) {
  final suit = Paint()..color = s.suit;
  c.drawRect(Rect.fromLTWH(p.dx - 12 * k, p.dy + 46 * k, 10 * k, 16 * k), suit);
  c.drawRect(Rect.fromLTWH(p.dx + 2 * k, p.dy + 46 * k, 10 * k, 16 * k), suit);
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: p.translate(0, 30 * k), width: 32 * k, height: 40 * k),
          Radius.circular(6 * k)),
      suit);
  c.drawRect(Rect.fromCenter(center: p.translate(0, 28 * k), width: 6 * k, height: 22 * k),
      Paint()..color = s.tie);
  c.drawCircle(p, 15 * k, Paint()..color = const Color(0xFFFFF3E0));
  c.drawRect(Rect.fromCenter(center: p.translate(0, -1 * k), width: 26 * k, height: 7 * k),
      Paint()..color = Colors.black);
  if (s.hat == 1) {
    c.drawRect(Rect.fromCenter(center: p.translate(0, -22 * k), width: 22 * k, height: 16 * k),
        Paint()..color = Colors.black);
    c.drawRect(Rect.fromCenter(center: p.translate(0, -14 * k), width: 34 * k, height: 4 * k),
        Paint()..color = Colors.black);
  } else if (s.hat == 2) {
    c.drawRect(Rect.fromCenter(center: p.translate(0, -8 * k), width: 31 * k, height: 5 * k),
        Paint()..color = s.tie);
  } else if (s.hat == 3) {
    c.drawArc(Rect.fromCenter(center: p, width: 36 * k, height: 36 * k), pi, pi, true,
        Paint()..color = Colors.white70);
  }
  Offset d = const Offset(0.5, 1);
  if (aim != null && (aim - p).distance > 1) d = aim - p;
  d = d / d.distance;
  final sh = p.translate(0, 22 * k);
  final hand = sh + d * (22 * k);
  c.drawLine(sh, hand,
      Paint()..color = s.suit..strokeWidth = 7 * k..strokeCap = StrokeCap.round);
  c.drawLine(hand, hand + d * (16 * k),
      Paint()..color = const Color(0xFF424242)..strokeWidth = 6 * k..strokeCap = StrokeCap.round);
}

void drawEnemy(Canvas c, Offset m, int type, double flash) {
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: m.translate(0, 23), width: 54, height: 8),
          const Radius.circular(3)),
      Paint()..color = const Color(0xFF8D6E63));
  final body = type == 2 ? const Color(0xFF455A64) : const Color(0xFFC62828);
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: m.translate(0, 6), width: 26, height: 30),
          const Radius.circular(5)),
      Paint()..color = flash > 0 ? Colors.white : body);
  final h = m.translate(0, -16);
  c.drawCircle(h, 12, Paint()..color = const Color(0xFFFFCC80));
  c.drawCircle(h.translate(-4, -1), 2, Paint()..color = Colors.black);
  c.drawCircle(h.translate(4, -1), 2, Paint()..color = Colors.black);
  c.drawLine(h.translate(-8, -6), h.translate(-2, -3),
      Paint()..color = Colors.black..strokeWidth = 2);
  c.drawLine(h.translate(8, -6), h.translate(2, -3),
      Paint()..color = Colors.black..strokeWidth = 2);
  if (type == 2) {
    c.drawArc(Rect.fromCenter(center: h, width: 28, height: 28), pi, pi, true,
        Paint()..color = const Color(0xFF90A4AE));
  }
}

void drawBarrel(Canvas c, Offset p) {
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: p.translate(0, 23), width: 44, height: 8),
          const Radius.circular(3)),
      Paint()..color = const Color(0xFF8D6E63));
  c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 30, height: 38), const Radius.circular(6)),
      Paint()..color = const Color(0xFFE65100));
  c.drawRect(Rect.fromCenter(center: p.translate(0, -9), width: 30, height: 4),
      Paint()..color = const Color(0xFF3E2723));
  c.drawRect(Rect.fromCenter(center: p.translate(0, 9), width: 30, height: 4),
      Paint()..color = const Color(0xFF3E2723));
  c.drawCircle(p, 6, Paint()..color = const Color(0xFFFFEB3B));
}

class _AP extends CustomPainter {
  final Skin s;
  final double k;
  final double y;
  _AP(this.s, this.k, this.y);
  @override
  void paint(Canvas c, Size size) {
    drawAgent(c, Offset(size.width / 2, y), s, null, k);
  }

  @override
  bool shouldRepaint(_) => true;
}

// ---------- Ecran racine (menu, jeu, boutique + pubs) ----------
class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  int screen = 0, gameKey = 0;
  BannerAd? banner;
  bool bannerOk = false;
  InterstitialAd? inter;

  @override
  void initState() {
    super.initState();
    if (useAds) {
      try {
        banner = BannerAd(
          adUnitId: bannerId,
          size: AdSize.banner,
          request: const AdRequest(),
          listener: BannerAdListener(
            onAdLoaded: (_) {
              if (mounted) setState(() => bannerOk = true);
            },
            onAdFailedToLoad: (ad, _) => ad.dispose(),
          ),
        )..load();
        _loadInter();
      } catch (_) {}
    }
  }

  void _loadInter() {
    InterstitialAd.load(
      adUnitId: interId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (a) => inter = a,
        onAdFailedToLoad: (_) {},
      ),
    );
  }

  void _levelDone(int lvl) {
    if (!useAds || lvl % 3 != 0) return;
    final a = inter;
    if (a == null) return;
    a.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInter();
      },
    );
    a.show();
    inter = null;
  }

  @override
  void dispose() {
    banner?.dispose();
    inter?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (screen == 1) {
      body = Game(
          key: ValueKey(gameKey),
          onExit: () => setState(() => screen = 0),
          onLevelDone: _levelDone);
    } else if (screen == 2) {
      body = Shop(onBack: () => setState(() => screen = 0));
    } else {
      body = Menu(
          onPlay: () => setState(() {
                gameKey++;
                screen = 1;
              }),
          onShop: () => setState(() => screen = 2));
    }
    return Scaffold(
      backgroundColor: const Color(0xFF4FC3F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: body),
            if (useAds && bannerOk && banner != null)
              Center(child: SizedBox(width: 320, height: 50, child: AdWidget(ad: banner!))),
          ],
        ),
      ),
    );
  }
}

// ---------- Menu ----------
class Menu extends StatelessWidget {
  final VoidCallback onPlay, onShop;
  const Menu({super.key, required this.onPlay, required this.onShop});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0288D1), Color(0xFF4FC3F7), Color(0xFFFFE0B2)]),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('AGENT SHOT',
                style: TextStyle(
                    color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Niveau max : ${Save.best}   |   Pièces : ${Save.coins}',
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            SizedBox(
                width: 140,
                height: 190,
                child: CustomPaint(painter: _AP(skins[Save.skin], 1.6, 60))),
            ElevatedButton(
                onPressed: onPlay,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14)),
                child: const Text('JOUER', style: TextStyle(fontSize: 22))),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: onShop,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10)),
                child: const Text('BOUTIQUE', style: TextStyle(fontSize: 18))),
          ],
        ),
      ),
    );
  }
}

// ---------- Boutique ----------
class Shop extends StatefulWidget {
  final VoidCallback onBack;
  const Shop({super.key, required this.onBack});
  @override
  State<Shop> createState() => _ShopState();
}

class _ShopState extends State<Shop> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D47A1),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: widget.onBack),
                const Text('Boutique',
                    style: TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${Save.coins} pièces',
                    style: const TextStyle(color: Color(0xFFFFEB3B), fontSize: 18)),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: skins.length,
              itemBuilder: (c, i) {
                final s = skins[i];
                final owned = Save.owned.contains(i);
                final equipped = Save.skin == i;
                Widget action;
                if (equipped) {
                  action = const Text('Équipé',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
                } else if (owned) {
                  action = ElevatedButton(
                      onPressed: () {
                        setState(() => Save.skin = i);
                        Save.save();
                      },
                      child: const Text('Choisir'));
                } else {
                  action = ElevatedButton(
                      onPressed: Save.coins >= s.price
                          ? () {
                              setState(() {
                                Save.coins -= s.price;
                                Save.owned.add(i);
                                Save.skin = i;
                              });
                              Save.save();
                            }
                          : null,
                      child: Text('Acheter ${s.price}'));
                }
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 70,
                            height: 100,
                            child: CustomPaint(painter: _AP(s, 1.0, 30))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(s.name,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold))),
                        action,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

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
     
