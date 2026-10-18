part of 'main.dart';

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
// FIN
// FIN
// FIN
// FIN
// FIN
// FIN
// FIN
// FIN
