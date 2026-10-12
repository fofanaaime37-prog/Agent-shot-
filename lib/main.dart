import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// Mets true pour activer les pubs (apres le test sans pubs).
const useAds = false;

// IDs de TEST Google. Remplace-les par tes vrais IDs AdMob avant publication.
const bannerId = 'ca-app-pub-3940256099942544/6300978111';
const interId = 'ca-app-pub-3940256099942544/1033173712';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (useAds) {
    try {
      await MobileAds.instance.initialize();
    } catch (_) {}
  }
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: Game()));
}

class Bullet {
  Offset p, v;
  Bullet(this.p, this.v);
}

class Game extends StatefulWidget {
  const Game({super.key});
  @override
  State<Game> createState() => _GameState();
}

class _GameState extends State<Game> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Size sz = Size.zero;
  double px = 0.5;
  int dir = 1, level = 1, ammo = 0;
  Offset? aim;
  List<Offset> enemies = [];
  List<Bullet> bullets = [];
  BannerAd? banner;
  bool bannerLoaded = false;
  InterstitialAd? inter;
  final rnd = Random();

  Offset get player => Offset(sz.width * px, sz.height * 0.28);

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
            onAdLoaded: (_) => setState(() => bannerLoaded = true),
            onAdFailedToLoad: (ad, _) => ad.dispose(),
          ),
        )..load();
        _loadInter();
      } catch (_) {}
    }
    _ticker = createTicker(_tick)..start();
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

  void _showInter() {
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

  void _spawn() {
    final n = min(2 + level, 8);
    enemies = List.generate(
        n,
        (_) => Offset(sz.width * (0.1 + rnd.nextDouble() * 0.8),
            sz.height * (0.5 + rnd.nextDouble() * 0.35)));
    ammo = n + 2;
    bullets.clear();
  }

  void _tick(Duration t) {
    final dt = _last == Duration.zero ? 0.0 : (t - _last).inMicroseconds / 1e6;
    _last = t;
    if (sz == Size.zero) return;
    if (enemies.isEmpty && ammo == 0) _spawn();
    final slow = aim != null ? 0.15 : 1.0;
    px += dir * 0.25 * dt * slow;
    if (px > 0.85) dir = -1;
    if (px < 0.15) dir = 1;
    for (final b in bullets) {
      b.p += b.v * dt;
    }
    for (final b in bullets) {
      enemies.removeWhere((e) => (e - b.p).distance < 22);
    }
    bullets.removeWhere((b) =>
        b.p.dx < 0 || b.p.dx > sz.width || b.p.dy < 0 || b.p.dy > sz.height);
    if (enemies.isEmpty && bullets.isEmpty && ammo > 0) {
      level++;
      if (useAds && level % 3 == 1) _showInter();
      _spawn();
    } else if (ammo == 0 && bullets.isEmpty && enemies.isNotEmpty) {
      _spawn();
    }
    setState(() {});
  }

  void _fire() {
    final a = aim;
    aim = null;
    if (a == null || ammo <= 0) return;
    final d = a - player;
    if (d.distance < 5) return;
    bullets.add(Bullet(player, d / d.distance * 900));
    ammo--;
  }

  @override
  void dispose() {
    _ticker.dispose();
    banner?.dispose();
    inter?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (c, box) {
        sz = Size(box.maxWidth, box.maxHeight);
        return Stack(children: [
          Listener(
            onPointerDown: (e) => aim = e.localPosition,
            onPointerMove: (e) => aim = e.localPosition,
            onPointerUp: (_) => _fire(),
            child: CustomPaint(size: sz, painter: _P(this)),
          ),
          Positioned(
              top: 40,
              left: 16,
              child: Text('Niveau $level   Balles: $ammo',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold))),
          if (banner != null && bannerLoaded)
            Positioned(
                bottom: 0,
                left: (sz.width - 320) / 2,
                child: SizedBox(
                    width: 320, height: 50, child: AdWidget(ad: banner!))),
        ]);
      }),
    );
  }
}

class _P extends CustomPainter {
  final _GameState g;
  _P(this.g);
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF2E9BFF));
    final p = g.player;
    c.drawLine(Offset(0, p.dy + 20), Offset(s.width, p.dy + 20),
        Paint()..color = Colors.white..strokeWidth = 3);
    if (g.aim != null) {
      c.drawLine(p, g.aim!, Paint()..color = Colors.redAccent..strokeWidth = 2);
    }
    c.drawCircle(p, 16, Paint()..color = Colors.white);
    c.drawRect(Rect.fromCenter(center: p.translate(0, -2), width: 22, height: 6),
        Paint()..color = Colors.black);
    for (final e in g.enemies) {
      c.drawCircle(e, 18, Paint()..color = const Color(0xFFE53935));
    }
    for (final b in g.bullets) {
      c.drawCircle(b.p, 4, Paint()..color = Colors.yellow);
    }
  }

  @override
  bool shouldRepaint(_) => true;
}
