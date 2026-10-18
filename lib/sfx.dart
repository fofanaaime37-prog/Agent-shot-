part of 'main.dart';

// ---------- Sons (generes par le code, aucun fichier audio) ----------
class Sfx {
  static final Map<String, Uint8List> _w = {};
  static final List<AudioPlayer> _pool = [];
  static int _i = 0;
  static bool ready = false;

  static void init() {
    try {
      _w['shoot'] = _wav(_tone(900, 200, 0.12, noise: 0.5));
      _w['kill'] = _wav(_tone(300, 700, 0.15, vol: 0.5));
      _w['boom'] = _wav(_tone(90, 30, 0.55, noise: 0.8, vol: 0.9));
      _w['coin'] = _wav(_tone(1200, 1600, 0.12, vol: 0.4));
      _w['lose'] = _wav(_tone(400, 120, 0.5));
      _w['click'] = _wav(_tone(600, 600, 0.04, vol: 0.4));
      _w['win'] = _wav([
        ..._tone(523, 523, 0.15),
        ..._tone(659, 659, 0.15),
        ..._tone(784, 784, 0.3),
      ]);
      for (int i = 0; i < 4; i++) {
        _pool.add(AudioPlayer());
      }
      ready = true;
    } catch (_) {}
  }

  static void play(String name, {double vol = 0.8}) {
    if (!Save.sound || !ready) return;
    try {
      final p = _pool[_i];
      _i = (_i + 1) % _pool.length;
      p.play(BytesSource(_w[name]!), volume: vol).catchError((Object e) {});
    } catch (_) {}
  }

  static List<double> _tone(double f0, double f1, double dur,
      {double noise = 0, double vol = 0.6}) {
    const rate = 22050;
    final n = (rate * dur).toInt();
    final r = Random(5);
    double ph = 0;
    return List<double>.generate(n, (i) {
      final t = i / n;
      final f = f0 + (f1 - f0) * t;
      ph += 2 * pi * f / rate;
      final env = pow(1 - t, 2).toDouble();
      final nz = r.nextDouble() * 2 - 1;
      return (sin(ph) * (1 - noise) + nz * noise) * env * vol;
    });
  }

  static Uint8List _wav(List<double> s) {
    const rate = 22050;
    final n = s.length;
    final b = ByteData(44 + n * 2);
    void str(int o, String t) {
      for (int i = 0; i < t.length; i++) {
        b.setUint8(o + i, t.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    b.setUint32(4, 36 + n * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little);
    b.setUint16(22, 1, Endian.little);
    b.setUint32(24, rate, Endian.little);
    b.setUint32(28, rate * 2, Endian.little);
    b.setUint16(32, 2, Endian.little);
    b.setUint16(34, 16, Endian.little);
    str(36, 'data');
    b.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = (s[i].clamp(-1.0, 1.0) * 32767).toInt();
      b.setInt16(44 + i * 2, v, Endian.little);
    }
    return b.buffer.asUint8List();
  }
}
// FIN
// FIN
// FIN
// FIN
// FIN
// FIN
// FIN
// FIN
