import 'package:flutter/material.dart';

import '../models/club.dart';
import 'club_identity.dart';
import 'player_banner.dart';

/// 対戦カード。両クラブの色を左右から差し込み、真ん中で切り替わる。
///
/// 次節カードは一番よく見る場所なのに、エンブレムが 34px で名前は文字だけ、
/// **「vs」の周りが白かった**。テレビの対戦カードと同じ形——左右にそれぞれの
/// クラブの色、真ん中に節（試合中はスコア）——にすると、読まなくても
/// 「誰と、どっちが自分か」が分かる。
///
/// 描くのは判定に効いているものだけ、という規約はここでも守る。
/// 色と形はクラブのIDから決まる `ClubIdentity`、並びはホーム/アウェイ。
class FixtureBanner extends StatelessWidget {
  const FixtureBanner({
    super.key,
    required this.club,
    required this.opponent,
    required this.home,
    required this.centre,
    this.caption,
    this.progress,
    this.height = 68,
  });

  /// シーズンの進み（0〜1）。帯の下端に細く引く。
  ///
  /// 別の行に置くと次節カードが伸び、スマホの高さで「今の状態」が
  /// 画面の外に出る（`ui_test` が実際に落ちた）。行を増やさず、帯の中に入れる。
  final double? progress;

  final Club club;
  final Club opponent;
  final bool home;

  /// 真ん中に置くもの。次節なら「第9節」、試合中なら「0 - 1」。
  final Widget centre;

  /// 真ん中の下に添える小さな文字（「ホーム」「先発」など）。
  final String? caption;

  final double height;

  @override
  Widget build(BuildContext context) {
    final left = home ? club : opponent;
    final right = home ? opponent : club;
    final leftId = ClubIdentity.of(left);
    final rightId = ClubIdentity.of(right);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: _BannerPainter(
            left: leftId,
            right: rightId,
            progress: progress,
          ),
          child: Row(
            children: [
              Expanded(
                child: _Team(
                  club: left,
                  identity: leftId,
                  mine: left == club,
                  alignEnd: true,
                ),
              ),
              // 真ん中は幅を止める。添え書きが長いと左右のクラブが
              // エンブレムの幅より狭くなり、2.5px はみ出して落ちた。
              // 試合中はスコアが大きいので、帯の高さに入り切らなければ縮める。
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 108),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      centre,
                      if (caption != null)
                        Text(
                          caption!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: const Color(0xFF14140F)
                                    .withValues(alpha: 0.7),
                              ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _Team(
                  club: right,
                  identity: rightId,
                  mine: right == club,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Team extends StatelessWidget {
  const _Team({
    required this.club,
    required this.identity,
    required this.mine,
    this.alignEnd = false,
  });

  final Club club;
  final ClubIdentity identity;
  final bool mine;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = readableOn(identity.primary);
    final crest = ClubCrest(club: club, size: 38);
    final name = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 96),
      child: Text(
        club.name,
        style: theme.textTheme.titleSmall?.copyWith(
          color: on,
          // 自分のクラブだけ濃く出す。どちらが自分か迷わせない。
          fontWeight: mine ? FontWeight.w800 : FontWeight.w500,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      ),
    );
    return Padding(
      padding: EdgeInsets.only(
        left: alignEnd ? 4 : 10,
        right: alignEnd ? 10 : 4,
      ),
      // 狭い幅ではエンブレムごと縮める。はみ出すよりは小さいほうがいい。
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: alignEnd
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: alignEnd
              ? [name, const SizedBox(width: 6), crest]
              : [crest, const SizedBox(width: 6), name],
        ),
      ),
    );
  }
}

/// 左右からクラブの色を差し込む。真ん中は生成りで、節やスコアを載せる。
class _BannerPainter extends CustomPainter {
  const _BannerPainter({
    required this.left,
    required this.right,
    this.progress,
  });

  final ClubIdentity left;
  final ClubIdentity right;
  final double? progress;

  static const Color _paper = Color(0xFFF4F1E8);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = _paper);

    // 斜めに切った帯。まっすぐに割ると表に見える。
    const slant = 14.0;
    final leftPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.40 + slant, 0)
      ..lineTo(w * 0.40 - slant, h)
      ..lineTo(0, h)
      ..close();
    final rightPath = Path()
      ..moveTo(w, 0)
      ..lineTo(w * 0.60 - slant, 0)
      ..lineTo(w * 0.60 + slant, h)
      ..lineTo(w, h)
      ..close();
    _band(canvas, leftPath, left, size);
    _band(canvas, rightPath, right, size);

    final p = progress;
    if (p != null) {
      const bar = 3.0;
      canvas.drawRect(
        Rect.fromLTWH(0, h - bar, w, bar),
        Paint()..color = const Color(0x33000000),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, h - bar, w * p.clamp(0.0, 1.0), bar),
        Paint()..color = const Color(0xFFF4F1E8),
      );
    }
  }

  void _band(Canvas canvas, Path path, ClubIdentity id, Size size) {
    canvas.drawPath(path, Paint()..color = id.primary);
    if (id.striped) {
      canvas.save();
      canvas.clipPath(path);
      final stripe = Paint()..color = id.secondary.withValues(alpha: 0.22);
      const width = 10.0;
      for (var x = -size.height; x < size.width + size.height; x += width * 2) {
        canvas.drawPath(
          Path()
            ..moveTo(x, 0)
            ..lineTo(x + width, 0)
            ..lineTo(x + width + size.height * 0.4, size.height)
            ..lineTo(x + size.height * 0.4, size.height)
            ..close(),
          stripe,
        );
      }
      canvas.restore();
    }
    // 縁に細く差し色。帯がただの塗りに見えないように。
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = id.secondary.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_BannerPainter old) =>
      old.left.primary != left.primary ||
      old.right.primary != right.primary ||
      old.progress != progress;
}
