// dart
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

// flutter
import 'package:flutter/material.dart';

// 3rd party plugin
void main() => runApp(MaterialApp(home: const _App()));

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: SafeArea(child: SpriteWidget(Scene(size))),
    );
  }
}

class Scene extends NodeWithSize {
  Scene(
    Size size,
  ) : super(size) {
    /// 初期化
    _init();
  }

  /// 2Dのワールドを生成(引数は重力)
  World _world = World(Vector2.zero());

  /// 物体ノード（バブル）の配列
  List<_BubbleNode> _nodes = [];

  /// 物理演算の制御に必要なものとか
  Vector2 get _center => Vector2(size.width / 2, size.height / 2);
  final _centerAreaHeight = 50.0;
  Rect get _centerArea => Rect.fromLTWH(
        _center.x - _centerAreaHeight,
        _center.y - _centerAreaHeight,
        _centerAreaHeight,
        _centerAreaHeight,
      );
  bool _isContainsCenter = false;
  bool _isMoveActive = true;
  bool _isMount = false;

  /// 初期設定
  void _init() async {
    // SpotifyApiを使ってTOPトラック情報を取得する
    final spotify = SpotifyApi(
      SpotifyApiCredentials(
        "*********",
        "*********",
      ),
    );
    final tracks = await spotify.artists.getTopTracks(
      '5yCWuaBlu42BKsnW89brND',
      "JP",
    );

    // バブルを生成
    _createBubbles(tracks);

    // マウントフラグ（updateでの物理実行制御）
    _isMount = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _world.stepDt(dt);

    // 物理演算制御
    if (_isMount && _isMoveActive) {
      _nodes.asMap().forEach((int i, _BubbleNode node) {
        if (!_isContainsCenter) {
          if (_centerArea
              .contains(Offset(node.body.position.x, node.body.position.y))) {
            _isContainsCenter = true;
            return;
          }
          _applyImpulse(node);
        } else {
          if (_isMoveActive &&
              node.isUpdated &&
              node.body.position
                      .distanceTo(Vector2(node.before.dx, node.before.dy)) <
                  0.1) {
            _isMoveActive = false;
            _world.clearForces();
          }
        }
      });
    }
  }

  /// 物体に衝撃を与える
  void _applyImpulse(_BubbleNode node) {
    final a = _center.x + node.body.position.x * -1.0;
    final b = _center.y + node.body.position.y * -1.0;
    node.body.applyLinearImpulse(Vector2(a, b) * node.body.mass);
  }

  /// バブルをトラック数分生成する
  void _createBubbles(Iterable<Track> tracks) async {
    tracks.forEach(
      (track) async {
        final radius = 30.0 + (20.0 * _getRandPercent());
        final image = await _loadImageURL(track.album.images.first.url,
            radius.toInt() * 2, radius.toInt() * 2);
        _nodes.add(
          _createBubble(
            Offset(size.width * _getRandPercent(), size.height + 50.0),
            radius: radius,
            image: image,
          ),
        );
      },
    );
  }

  /// バブル生成（物理関連のデータをセット）
  _BubbleNode _createBubble(
    Offset position, {
    double radius = 30.0,
    double friction = 0, // 摩擦係数
    double restitution = 0, // 反発係数
    double linearDamping = 10.0, // 移動速度の減衰率
    ui.Image image,
  }) {
    // 物体固有データ
    final FixtureDef fixtureDef = FixtureDef(CircleShape()..radius = radius);
    fixtureDef.friction = friction;
    fixtureDef.restitution = restitution;
    fixtureDef.density = 0; // 密度

    // 物体データ
    final BodyDef bodyDef = BodyDef();
    bodyDef.position = Vector2(position.dx, position.dy);
    bodyDef.type = BodyType.dynamic;
    bodyDef.linearDamping = linearDamping;

    // ワールドへ追加
    final Body body = _world.createBody(bodyDef);
    body.createFixture(fixtureDef);

    // アルバムの画像の物体を生成
    final _BubbleNode node = _BubbleNode(
      body,
      image,
      radius: radius,
    )..position = position;
    addChild(node);
    return node;
  }

  /// ネットワークURLからui.Image生成
  Future<ui.Image> _loadImageURL(String imageUrl, int height, int width) async {
    final http.Response response = await http.get(imageUrl);
    final image.Image baseSizeImage =
        image.decodeImage(response.bodyBytes.buffer.asUint8List());
    final image.Image resizeImage =
        image.copyResize(baseSizeImage, height: height, width: width);
    final ui.Codec codec =
        await ui.instantiateImageCodec(image.encodePng(resizeImage));
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  /// ランダム値生成
  double _getRandPercent({int max = 100}) {
    return Random().nextInt(max + 1) * 0.01;
  }
}

/// バブルノード
class _BubbleNode extends Node {
  _BubbleNode(
    this.body,
    this.image, {
    this.radius = 30,
  });
  final Body body;
  final double radius;
  final ui.Image image;
  Offset before;

  bool get isUpdated => before != null;

  @override
  void update(double dt) {
    super.update(dt);
    before = position;
    position = Offset(body.position.x, body.position.y);
  }

  @override
  void paint(Canvas canvas) {
    final Paint paintBorder = Paint()..color = Colors.white;
    canvas.drawCircle(Offset.zero, radius, paintBorder);
    final Path path = Path()
      ..addOval(Rect.fromLTWH(-radius, -radius, radius * 2, radius * 2));
    canvas.clipPath(path);
    canvas.drawImage(image, Offset(-radius, -radius), paintBorder);
  }
}