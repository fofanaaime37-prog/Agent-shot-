part of 'main.dart';

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
  RewardedAd? rewarded;

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
        _loadRewarded();
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

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: rewardId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (a) => rewarded = a,
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

  void _watch(VoidCallback grant) {
    final a = rewarded;
    if (a == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pub indisponible, réessaie dans un instant.')));
      _loadRewarded();
      return;
    }
    a.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewarded();
      },
    );
    rewarded = null;
    a.show(onUserEarnedReward: (ad, reward) => grant());
  }

  @override
  void dispose() {
    banner?.dispose();
    inter?.dispose();
    rewarded?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (screen == 1) {
      body = Game(
          key: ValueKey(gameKey),
          onExit: () => setState(() => screen = 0),
          onLevelDone: _levelDone,
          onWatch: _watch);
    } else if (screen == 2) {
      body = Shop(onBack: () => setState(() => screen = 0), onWatch: _watch);
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
class Menu extends StatefulWidget {
  final VoidCallback onPlay, onShop;
  const Menu({super.key, required this.onPlay, required this.onShop});
  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0288D1), Color(0xFF4FC3F7), Color(0xFFFFE0B2)]),
      ),
      child: Stack(
        children: [
          Center(
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
                    onPressed: () {
                      Sfx.play('click');
                      widget.onPlay();
                    },
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14)),
                    child: const Text('JOUER', style: TextStyle(fontSize: 22))),
                const SizedBox(height: 12),
                ElevatedButton(
                    onPressed: () {
                      Sfx.play('click');
                      widget.onShop();
                    },
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10)),
                    child: const Text('BOUTIQUE', style: TextStyle(fontSize: 18))),
              ],
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: Icon(Save.sound ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white, size: 30),
              onPressed: () {
                setState(() => Save.sound = !Save.sound);
                Save.save();
                Sfx.play('click');
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Boutique ----------
class Shop extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(VoidCallback grant) onWatch;
  const Shop({super.key, required this.onBack, required this.onWatch});
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
          if (useAds)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_circle_fill),
                label: const Text('Gagner 25 pièces (pub vidéo)'),
                onPressed: () => widget.onWatch(() {
                  if (!mounted) return;
                  setState(() => Save.coins += 25);
                  Save.save();
                  Sfx.play('coin');
                }),
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
                        Sfx.play('click');
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
                              Sfx.play('coin');
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
