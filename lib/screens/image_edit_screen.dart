/// 图片编辑页（裁切 + 旋转）- 思谛 STDeel
///
/// 拍照/选图后进入本页：
///   - 背景图片固定铺满（不随手势移动，便于稳定取景）
///   - 中央裁切框**自由比例**可调：拖动四角/四边缩放、拖动框内移动
///   - 可选比例锁定（1:1 / 3:4 / 4:3 / 16:9 / 9:16），默认"自由"
///   - 左右旋转 90°
///   - 确认后在 isolate 中完成解码→旋转→裁切→JPEG 编码
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../widgets/glass.dart';

class ImageEditScreen extends StatefulWidget {
  const ImageEditScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<ImageEditScreen> createState() => _ImageEditScreenState();
}

/// 拖动模式：裁切框可整体移动，或从四角/四边缩放
enum _DragMode {
  none,
  move,
  resizeTL,
  resizeTR,
  resizeBL,
  resizeBR,
  resizeL,
  resizeR,
  resizeT,
  resizeB,
}

class _ImageEditScreenState extends State<ImageEditScreen> {
  ui.Size _imageSize = ui.Size.zero;
  bool _loading = true;
  bool _processing = false;
  String? _error;

  int _quarterTurns = 0;

  // 视口尺寸（LayoutBuilder 捕获）
  Size _viewportSize = Size.zero;

  // 背景图片的放置参数：rotated 图片以 (dx, dy) 为左上角、统一缩放 scale
  double _fitScale = 1;
  Offset _fitOffset = Offset.zero;

  // 裁切框（视口坐标），由用户手势自由调整
  Rect _crop = Rect.zero;

  // 比例锁定（w/h；null = 自由）
  double? _lockRatio;

  // 拖动状态
  _DragMode _dragMode = _DragMode.none;
  Offset _dragStart = Offset.zero;
  Rect _cropStart = Rect.zero;

  Uint8List? _bytes;

  static const double _kHandleHit = 26; // 手柄命中半径（逻辑像素）
  static const double _kMinCrop = 56; // 裁切框最小边长

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final decoded = await compute(_decodeSize, bytes);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _imageSize = decoded;
        _loading = false;
      });
      _scheduleFit();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '图片加载失败：$e';
        _loading = false;
      });
    }
  }

  /// 旋转后的图片尺寸（逻辑坐标系，即渲染后的旋转图片尺寸）
  Size get _rotatedSize {
    final w = _imageSize.width;
    final h = _imageSize.height;
    return _quarterTurns % 2 == 0 ? Size(w, h) : Size(h, w);
  }

  /// 计算背景图片的放置（contain 到视口并留白），并初始化裁切框
  void _fitLayout() {
    if (_viewportSize == Size.zero || _imageSize == ui.Size.zero) return;
    final rs = _rotatedSize;
    if (rs.width <= 0 || rs.height <= 0) return;
    final vw = _viewportSize.width;
    final vh = _viewportSize.height;
    final scale =
        math.min(vw / rs.width, vh / rs.height) * 0.98;
    _fitScale = scale;
    _fitOffset = Offset(
      (vw - rs.width * scale) / 2,
      (vh - rs.height * scale) / 2,
    );
    _initCrop();
  }

  /// 初始化/重置裁切框：视口内居中，覆盖约 86% 宽 × 80% 高
  void _initCrop() {
    final vw = _viewportSize.width;
    final vh = _viewportSize.height;
    if (vw <= 0 || vh <= 0) return;
    final w = vw * 0.86;
    final h = vh * 0.8;
    _crop = Rect.fromLTWH((vw - w) / 2, (vh - h) / 2, w, h);
  }

  void _scheduleFit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(_fitLayout);
    });
  }

  void _rotate({required bool clockwise}) {
    setState(() {
      _quarterTurns = ((_quarterTurns + (clockwise ? 1 : 3)) % 4);
    });
    _scheduleFit();
  }

  /// 重置旋转与裁切框
  void _reset() {
    setState(() {
      _quarterTurns = 0;
      _lockRatio = null;
    });
    _scheduleFit();
  }

  // ---------- 裁切框手势 ----------

  /// 命中测试：优先四角 → 四边 → 框内移动 → 无操作
  _DragMode _hitTest(Offset p) {
    final r = _crop;
    if (r == Rect.zero || r.isEmpty) return _DragMode.none;
    bool near(double a, double b) => (a - b).abs() <= _kHandleHit;
    if (near(p.dx, r.left) && near(p.dy, r.top)) return _DragMode.resizeTL;
    if (near(p.dx, r.right) && near(p.dy, r.top)) return _DragMode.resizeTR;
    if (near(p.dx, r.left) && near(p.dy, r.bottom)) return _DragMode.resizeBL;
    if (near(p.dx, r.right) && near(p.dy, r.bottom)) return _DragMode.resizeBR;
    if (near(p.dx, r.left)) return _DragMode.resizeL;
    if (near(p.dx, r.right)) return _DragMode.resizeR;
    if (near(p.dy, r.top)) return _DragMode.resizeT;
    if (near(p.dy, r.bottom)) return _DragMode.resizeB;
    if (r.deflate(8).contains(p)) return _DragMode.move;
    return _DragMode.none;
  }

  void _onPanStart(DragStartDetails d) {
    _dragMode = _hitTest(d.localPosition);
    _dragStart = d.localPosition;
    _cropStart = _crop;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dragMode == _DragMode.none) return;
    setState(() {
      _crop = _applyDrag(_cropStart, _dragStart, d.localPosition);
    });
  }

  void _onPanEnd() {
    setState(() => _dragMode = _DragMode.none);
  }

  /// 根据拖动模式计算新的裁切框（视口坐标，约束在视口内、不小于最小尺寸）
  Rect _applyDrag(Rect start, Offset startPos, Offset cur) {
    final dx = cur.dx - startPos.dx;
    final dy = cur.dy - startPos.dy;
    final vw = _viewportSize.width;
    final vh = _viewportSize.height;
    final ratio = _lockRatio;
    final m = _dragMode;

    if (m == _DragMode.move) {
      var r = start.shift(Offset(dx, dy));
      if (r.left < 0) r = r.translate(-r.left, 0);
      if (r.top < 0) r = r.translate(0, -r.top);
      if (r.right > vw) r = r.translate(vw - r.right, 0);
      if (r.bottom > vh) r = r.translate(0, vh - r.bottom);
      return r;
    }

    // 自由模式：直接拖动对应边/角
    final leftMove = switch (m) {
      _DragMode.resizeL || _DragMode.resizeTL || _DragMode.resizeBL => dx,
      _ => 0.0,
    };
    final rightMove = switch (m) {
      _DragMode.resizeR || _DragMode.resizeTR || _DragMode.resizeBR => dx,
      _ => 0.0,
    };
    final topMove = switch (m) {
      _DragMode.resizeT || _DragMode.resizeTL || _DragMode.resizeTR => dy,
      _ => 0.0,
    };
    final bottomMove = switch (m) {
      _DragMode.resizeB || _DragMode.resizeBL || _DragMode.resizeBR => dy,
      _ => 0.0,
    };
    var r = Rect.fromLTRB(
      start.left + leftMove,
      start.top + topMove,
      start.right + rightMove,
      start.bottom + bottomMove,
    );

    // 比例锁定：以拖动主轴为准推导尺寸；角点锚定对角，边拖动锚定垂直中心
    if (ratio != null && ratio > 0 && r.width > 0 && r.height > 0) {
      final isCorner = switch (m) {
        _DragMode.resizeTL ||
        _DragMode.resizeTR ||
        _DragMode.resizeBL ||
        _DragMode.resizeBR => true,
        _ => false,
      };
      if (isCorner) {
        // 锚定对角
        final ax = (m == _DragMode.resizeTL || m == _DragMode.resizeBL)
            ? start.right
            : start.left;
        final ay = (m == _DragMode.resizeTR || m == _DragMode.resizeBL)
            ? start.bottom
            : start.top;
        final nx = (m == _DragMode.resizeTL || m == _DragMode.resizeBL)
            ? r.left
            : r.right;
        final ny = (m == _DragMode.resizeTL || m == _DragMode.resizeTR)
            ? r.top
            : r.bottom;
        final dw = (nx - ax).abs();
        final dh = (ny - ay).abs();
        final w = math.max(dw, dh * ratio);
        final h = w / ratio;
        final l = nx >= ax ? ax : ax - w;
        final t = ny >= ay ? ay : ay - h;
        r = Rect.fromLTWH(l, t, w, h);
      } else if (m == _DragMode.resizeT || m == _DragMode.resizeB) {
        final h = r.height;
        final w = h * ratio;
        r = Rect.fromCenter(center: r.center, width: w, height: h);
      } else {
        // 左右边：宽驱动，垂直方向锚定中心
        final w = r.width;
        final h = w / ratio;
        r = Rect.fromCenter(center: r.center, width: w, height: h);
      }
    }

    // 约束到视口内
    if (r.left < 0) r = r.translate(-r.left, 0);
    if (r.top < 0) r = r.translate(0, -r.top);
    if (r.right > vw) r = r.translate(vw - r.right, 0);
    if (r.bottom > vh) r = r.translate(0, vh - r.bottom);

    // 最小尺寸（围绕中心扩展）
    if (r.width < _kMinCrop) r = r.inflate((_kMinCrop - r.width) / 2);
    if (r.height < _kMinCrop) r = r.inflate((_kMinCrop - r.height) / 2);
    if (r.left < 0) r = r.translate(-r.left, 0);
    if (r.top < 0) r = r.translate(0, -r.top);
    if (r.right > vw) r = r.translate(vw - r.right, 0);
    if (r.bottom > vh) r = r.translate(0, vh - r.bottom);

    return r;
  }

  /// 选择比例后把裁切框贴合到该比例（保持中心、不超视口）
  void _fitCropToRatio(double ratio) {
    final cur = _crop;
    if (cur == Rect.zero || ratio <= 0) return;
    final vw = _viewportSize.width;
    final vh = _viewportSize.height;
    double w;
    double h;
    if (cur.width / cur.height > ratio) {
      h = cur.height;
      w = h * ratio;
    } else {
      w = cur.width;
      h = w / ratio;
    }
    var r = Rect.fromCenter(center: cur.center, width: w, height: h);
    if (r.left < 0) r = r.translate(-r.left, 0);
    if (r.top < 0) r = r.translate(0, -r.top);
    if (r.right > vw) r = r.translate(vw - r.right, 0);
    if (r.bottom > vh) r = r.translate(0, vh - r.bottom);
    _crop = r;
  }

  void _selectRatio(double? ratio) {
    setState(() {
      _lockRatio = ratio;
      if (ratio != null) _fitCropToRatio(ratio);
    });
  }

  // ---------- 确认裁切 ----------

  Future<void> _confirm() async {
    if (_processing || _bytes == null) return;
    setState(() => _processing = true);

    try {
      final s = _fitScale;
      final o = _fitOffset;
      if (s <= 0) throw '图片尚未就绪';

      // 视口坐标 → 旋转后图片像素坐标
      final c = _crop;
      var childRect = Rect.fromLTWH(
        (c.left - o.dx) / s,
        (c.top - o.dy) / s,
        c.width / s,
        c.height / s,
      );

      // 与图片 bounds 求交集
      final rs = _rotatedSize;
      final bounds = Rect.fromLTWH(0, 0, rs.width, rs.height);
      childRect = childRect.intersect(bounds);
      if (childRect.width < 8 || childRect.height < 8) {
        childRect = bounds;
      }

      // 极小/损坏图片：clamp 下界会大于上界抛 ArgumentError，先拦截
      final imgW = rs.width.round();
      final imgH = rs.height.round();
      if (imgW < 1 || imgH < 1) {
        setState(() => _processing = false);
        showGlassSnackBar(context, '图片尺寸过小，无法裁切', error: true);
        return;
      }

      final crop = (
        bytes: _bytes!,
        quarterTurns: _quarterTurns,
        x: childRect.left.round().clamp(0, imgW - 1),
        y: childRect.top.round().clamp(0, imgH - 1),
        w: childRect.width.round().clamp(1, imgW),
        h: childRect.height.round().clamp(1, imgH),
      );

      final outBytes = await compute(_cropAndEncode, crop);

      final dir = await getTemporaryDirectory();
      final outFile = File(
        '${dir.path}/stdeel_crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await outFile.writeAsBytes(outBytes);

      if (!mounted) return;
      Navigator.of(context).pop(outFile.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      showGlassSnackBar(context, '裁切失败：$e', error: true);
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('调整图片'),
        actions: [
          IconButton(
            tooltip: '重置',
            icon: const Icon(Icons.restart_alt),
            onPressed: _reset,
          ),
        ],
      ),
      body: _loading || _error != null
          ? _buildPlaceholder()
          : Column(
              children: [
                Expanded(child: _buildViewer()),
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildPlaceholder() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: G.coral)),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildViewer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final newSize = constraints.biggest;
        if (newSize != _viewportSize) {
          _viewportSize = newSize;
          if (!_loading && _bytes != null) {
            // 视口尺寸变化（如屏幕旋转）时重排背景并重置裁切框
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(_fitLayout);
            });
          }
        }
        // 背景图片固定：双指缩放/拖动不再移动图片，取景稳定
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: (_) => _onPanEnd(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(
                child: Transform(
                  transform: Matrix4.identity()
                    ..translate(_fitOffset.dx, _fitOffset.dy)
                    ..scale(_fitScale),
                  alignment: Alignment.topLeft,
                  child: RotatedBox(
                    quarterTurns: _quarterTurns,
                    child: Image.memory(_bytes!, gaplessPlayback: true),
                  ),
                ),
              ),
              // 裁切框遮罩 + 手柄
              CustomPaint(
                painter: _CropOverlayPainter(rect: _crop),
                size: Size.infinite,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: GlassCard(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        radius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 比例选择（默认自由）
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _ratioChip('自由', null),
                  _ratioChip('1:1', 1),
                  _ratioChip('3:4', 3 / 4),
                  _ratioChip('4:3', 4 / 3),
                  _ratioChip('9:16', 9 / 16),
                  _ratioChip('16:9', 16 / 9),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 旋转控制 + 跳过 + 完成
            Row(
              children: [
                // 左旋
                _roundIconBtn(
                  icon: Icons.rotate_left_rounded,
                  onTap: () => _rotate(clockwise: false),
                ),
                const SizedBox(width: 8),
                // 右旋
                _roundIconBtn(
                  icon: Icons.rotate_right_rounded,
                  onTap: () => _rotate(clockwise: true),
                ),
                const Spacer(),
                // 使用原图
                TextButton(
                  onPressed: () => Navigator.of(context).pop(widget.imagePath),
                  child: const Text('跳过'),
                ),
                const SizedBox(width: 8),
                // 确认
                _processing
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : GlassPrimaryButton(
                        icon: Icons.check_rounded,
                        label: '完成',
                        height: 48,
                        onPressed: _confirm,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratioChip(String label, double? ratio) {
    final selected = _lockRatio == ratio;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _selectRatio(ratio),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? G.accent : G.glassFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? G.accent : G.glassBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? G.accentFg : G.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundIconBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: G.glassFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: G.glassBorder),
        ),
        child: Icon(icon, color: G.textPrimary, size: 22),
      ),
    );
  }
}

/// 裁切框绘制：外部暗化 + 边框 + 三分线 + 四角/四边手柄
class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({required this.rect});

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    if (rect == Rect.zero || rect.isEmpty) return;

    // 暗化裁切框外部
    final overlay = Paint()..color = Colors.black.withOpacity(0.55);
    final outer = Path()..addRect(Offset.zero & size);
    final inner = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)));
    final diff = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(diff, overlay);

    // 边框
    final border = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      border,
    );

    // 三分线
    final grid = Paint()
      ..color = Colors.white.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var i = 1; i <= 2; i++) {
      final dx = rect.left + rect.width * i / 3;
      canvas.drawLine(Offset(dx, rect.top), Offset(dx, rect.bottom), grid);
      final dy = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(rect.left, dy), Offset(rect.right, dy), grid);
    }

    // 手柄：四角圆点 + 四边中点圆点（提示可拖动缩放）
    final handleFill = Paint()..color = Colors.white;
    final handleStroke = Paint()
      ..color = Colors.black.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const r = 4.5;
    void dot(Offset c) {
      canvas.drawCircle(c, r, handleFill);
      canvas.drawCircle(c, r, handleStroke);
    }

    final RRect rr = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    dot(Offset(rr.left, rr.top));
    dot(Offset(rr.right, rr.top));
    dot(Offset(rr.left, rr.bottom));
    dot(Offset(rr.right, rr.bottom));
    dot(Offset(rr.center.dx, rr.top));
    dot(Offset(rr.center.dx, rr.bottom));
    dot(Offset(rr.left, rr.center.dy));
    dot(Offset(rr.right, rr.center.dy));
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter old) => old.rect != rect;
}

// ---------- Isolate 任务 ----------

/// 解码获取尺寸（避免阻塞 UI）
ui.Size _decodeSize(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) throw '无法解码图片';
  return ui.Size(image.width.toDouble(), image.height.toDouble());
}

/// 裁切参数（isolate 传递）
typedef _CropArgs = ({
  Uint8List bytes,
  int quarterTurns,
  int x,
  int y,
  int w,
  int h,
});

/// 旋转 → 裁切 → JPEG 编码（isolate 中执行）
Uint8List _cropAndEncode(_CropArgs args) {
  final src = img.decodeImage(args.bytes);
  if (src == null) throw '无法解码图片';

  var rotated = src;
  if (args.quarterTurns > 0) {
    rotated = img.copyRotate(src, angle: args.quarterTurns * 90);
  }

  // clamp 裁切区域
  final x = args.x.clamp(0, rotated.width - 1);
  final y = args.y.clamp(0, rotated.height - 1);
  final w = args.w.clamp(1, rotated.width - x);
  final h = args.h.clamp(1, rotated.height - y);

  final cropped = img.copyCrop(
    rotated,
    x: x,
    y: y,
    width: w,
    height: h,
  );
  final jpg = img.encodeJpg(cropped, quality: 90);
  return Uint8List.fromList(jpg);
}
