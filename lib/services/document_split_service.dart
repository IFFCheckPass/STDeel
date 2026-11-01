/// 答案库文档导入 + AI 拆分服务 - 思谛 STDeel
///
/// 把一份 PDF / Word（.doc/.docx）里的题目与答案，交给支持多模态的 AI（或
/// 任一可用模型）自动拆分成结构化条目，供答案库批量入库。
///
/// 处理策略：
///   - PDF：逐页渲染为图片，交给多模态模型读图（同时兼容文本型与扫描件）。
///   - .docx：解压提取 `word/document.xml` 文本，作为纯文本发给模型。
///   - .doc：OLE2 旧格式，尽力提取可读 ASCII 文本（可能不够干净）。
///
/// 拆分结果复用 [QuestionResult]（content / answer / solution / knowledge_points）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:pdfx/pdfx.dart';

import '../config/ai_config.dart';
import '../models/solve_result.dart';
import '../utils/latex_commands.dart';
import 'ai_service.dart';

/// 文档拆分结果
class DocumentSplitResult {
  const DocumentSplitResult({
    required this.questions,
    required this.usedModel,
    required this.usedImage,
    required this.pageCount,
  });

  final List<QuestionResult> questions;

  /// 实际命中的模型名
  final String usedModel;

  /// 是否以"读图/多模态"方式识别（true=页面图片；false=纯文本）
  final bool usedImage;

  /// 发送的页面图片数
  final int pageCount;
}

/// 一份文档解析出的可发送内容：文本 与/或 页面图片（data URL）
class _DocContent {
  const _DocContent({this.text = '', this.images = const []});

  final String text;
  final List<String> images;

  bool get hasImage => images.isNotEmpty;
}

class DocumentSplitService {
  DocumentSplitService({required AiService aiService}) : _ai = aiService;

  final AiService _ai;

  /// 解析文件内容（页图片：上限控制，避免超长请求）
  static const int _maxPages = 12;

  /// 逐个模型尝试拆分（多模态优先，由调用方 buildModelChain 已保证排序）。
  /// 成功返回结果；全部失败抛异常（含原因）。
  Future<DocumentSplitResult> split({
    required String path,
    required List<AiModelConfig> models,
  }) async {
    if (models.isEmpty) {
      throw '未配置可用的 AI 模型，请到「设置 → AI 模型组合」填写 API Key';
    }

    final content = await _extract(path);

    String? lastErr;
    // 优先多模态模型；buildModelChain 已把多模态排在前，这里再稳定排一次保险。
    final ordered = [...models]
      ..sort((a, b) {
        if (a.multimodal == b.multimodal) return 0;
        return a.multimodal ? -1 : 1;
      });

    for (final model in ordered) {
      try {
        final raw = await _ai.generateRaw(
          model: model,
          userText: _buildUserText(content),
          imageDataUrls: content.images,
          source: 'AI 调用 · 答案库文档拆分',
        );
        final questions = _parse(raw);
        if (questions.isEmpty) {
          lastErr = '${model.name} 未从文档中解析出题目';
          continue;
        }
        return DocumentSplitResult(
          questions: questions,
          usedModel: model.name,
          usedImage: content.hasImage,
          pageCount: content.images.length,
        );
      } catch (e) {
        lastErr = e.toString();
      }
    }
    throw Exception(lastErr ?? '所有模型均拆分失败');
  }

  String _buildUserText(_DocContent content) {
    if (content.hasImage) {
      return '请识别下面的文档页面图片，把其中每一道题目与答案逐题拆分，'
          '按标准答案条目输出。';
    }
    return '以下是文档中的文本内容，请逐题拆分并整理为标准答案条目：\n\n'
        '${content.text}';
  }

  /// 依据扩展名解析文档为 文本/图片
  Future<_DocContent> _extract(String path) async {
    final lower = path.toLowerCase();
    final ext = lower.substring(lower.lastIndexOf('.') + 1);
    final bytes = File(path).readAsBytesSync();

    switch (ext) {
      case 'pdf':
        final images = await _renderPdf(path);
        if (images.isEmpty) {
          throw 'PDF 渲染失败：无法读取页面（文件可能损坏）';
        }
        return _DocContent(images: images);
      case 'docx':
        final text = _docxText(bytes).trim();
        if (text.isEmpty) {
          throw 'Word 文档中未提取到文本（可能为空文档）';
        }
        return _DocContent(text: text);
      case 'doc':
        final text = _docRawText(bytes).trim();
        if (text.length < 10) {
          throw '旧版 .doc 无法可靠提取文本，请另存为 .docx 或 .pdf 后重试';
        }
        return _DocContent(text: text);
      default:
        throw '不支持的文件格式：.$ext（支持 .pdf / .doc / .docx）';
    }
  }

  /// PDF 逐页渲染为 PNG data URL（走多模态识别）
  Future<List<String>> _renderPdf(String path) async {
    // pdfx 是原生实现，networking/内存异常需隔离，逐页关闭释放资源。
    late final PdfDocument doc;
    try {
      doc = await PdfDocument.openFile(path);
    } catch (e) {
      throw '打开 PDF 失败：$e';
    }
    final count = doc.pagesCount;
    final images = <String>[];
    try {
      final n = count > _maxPages ? _maxPages : count;
      for (var i = 0; i < n; i++) {
        PdfPage? page;
        try {
          page = await doc.getPage(i + 1);
          // 按目标宽度保持纵横比渲染，用 JPEG 压缩控制体积（发给多模态识别）
          final targetW = 1000.0;
          final targetH = page.height * targetW / page.width;
          final image = await page.render(
            width: targetW,
            height: targetH,
            format: PdfPageImageFormat.jpeg,
            quality: 80,
          );
          if (image != null) {
            images.add('data:image/jpeg;base64,'
                '${base64Encode(image.bytes)}');
          }
        } catch (_) {
          // 单页失败跳过，避免整文档失败
        } finally {
          await page?.close();
        }
      }
    } finally {
      await doc.close();
    }
    return images;
  }

  /// 解压 docx，提取 <w:t> 文本
  String _docxText(List<int> bytes) {
    String xml;
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final entry = archive.findFile('word/document.xml');
      if (entry == null) return '';
      xml = utf8.decode(entry.content as List<int>);
    } catch (_) {
      return '';
    }
    final buffer = StringBuffer();
    final re = RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true);
    for (final m in re.allMatches(xml)) {
      buffer.write(m.group(1));
    }
    return buffer.toString();
  }

  /// 旧 .doc（OLE2 二进制）尽力提取可读 ASCII 文本
  String _docRawText(List<int> bytes) {
    final sb = StringBuffer();
    final cur = StringBuffer();
    for (final b in bytes) {
      final ch = String.fromCharCode(b);
      final readable =
          (b >= 32 && b < 127) || b == 10 || b == 13 || b == 9;
      if (readable) {
        cur.write(ch);
      } else {
        if (cur.length >= 3) {
          sb.write('${cur.toString().trim()}\n');
        }
        cur.clear();
      }
    }
    if (cur.length >= 3) sb.write(cur.toString().trim());
    return sb.toString();
  }

  /// 解析 AI 返回的 JSON（兼容 markdown 围栏；`{\"questions\":[...]}` 或单题/数组）
  List<QuestionResult> _parse(String rawText) {
    var text = rawText.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceAll(RegExp(r'^```(?:json)?'), '')
          .replaceAll(RegExp(r'```$'), '')
          .trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (text.startsWith('[') && (start < 0 || end < 0)) {
      final a = text.indexOf('[');
      final z = text.lastIndexOf(']');
      if (a >= 0 && z > a) {
        try {
          final list = jsonDecode(
            repairLatexEscapesInJson(text.substring(a, z + 1)),
          ) as List<dynamic>;
          return list
              .map((e) => QuestionResult.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (_) {
          return [];
        }
      }
    }
    if (start < 0 || end < 0 || end <= start) return [];
    try {
      final decoded = jsonDecode(
        repairLatexEscapesInJson(text.substring(start, end + 1)),
      ) as Map<String, dynamic>;
      final list = decoded['questions'] as List<dynamic>?;
      if (list != null) {
        return list
            .map((e) => QuestionResult.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (decoded['content'] != null || decoded['answer'] != null) {
        return [QuestionResult.fromJson(decoded)];
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}