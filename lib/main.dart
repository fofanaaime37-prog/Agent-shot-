import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

part 'ui.dart';
part 'game.dart';

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
