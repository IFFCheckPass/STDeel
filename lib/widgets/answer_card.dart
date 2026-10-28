/// 答案卡片 - 思谛 STDeel
///
/// 液态玻璃卡片。左侧竖向 5 个按钮：
///   - 重答（蓝）
///   - 疑问（黄）
///   - 部分错误（橙，大题多小题部分答错）
///   - 错误（红）
///   - 正确（绿）
/// 右侧：题目 + 知识点标签 + 答案 + 解答过程（Markdown / LaTeX 渲染）
library;

import 'package:flutter/material.dart';

import '../models/solve_result.dart';
import 'glass.dart';
import 'latex_renderer.dart';

class AnswerCard extends StatelessWidget {
  const AnswerCard({
    super.key,
    required this.question,
    required this.modelName,
    required this.onRetry,
    required this.onAskDetailed,
    required this.onMarkCorrect,
    required this.onMarkWrong,
    required this.onMarkPartial,
    this.feedback = 'none',
    this.isLoading = false,
  });

  final QuestionResult question;
  final String modelName;
  final VoidCallback onRetry;
  final VoidCallback onAskDetailed;
  final VoidCallback onMarkCorrect;
  final VoidCallback onMarkWrong;

  /// 部分错误（大题含多小题，部分小题答错）
  final VoidCallback onMarkPartial;
  final String feedback; // none | correct | partial | wrong
  final bool isLoading;

  static const _colorRetry = G.accent;
  static const _colorQuestion = G.amber;
  static const _colorPartial = Color(0xFFFF9F43); // 橙：部分错误
  static const _colorWrong = G.coral;
  static const _colorCorrect = G.mint;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      radius: 20,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左侧 4 个竖向按钮
            _buildButtonColumn(),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: G.glassBorder,
            ),
            // 右侧内容
            Expanded(
              child: _buildContent(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonColumn() {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          _actionButton(
            label: '重答',
            color: _colorRetry,
            icon: Icons.refresh_rounded,
            onTap: onRetry,
          ),
          const SizedBox(height: 8),
          _actionButton(
            label: '疑问',
            color: _colorQuestion,
            icon: Icons.help_outline_rounded,
            onTap: onAskDetailed,
          ),
          const SizedBox(height: 8),
          _actionButton(
            label: '部分错误',
            color: _colorPartial,
            icon: Icons.remove_circle_outline_rounded,
            selected: feedback == 'partial',
            onTap: onMarkPartial,
          ),
          const SizedBox(height: 8),
          _actionButton(
            label: '错误',
            color: _colorWrong,
            icon: Icons.close_rounded,
            selected: feedback == 'wrong',
            onTap: onMarkWrong,
          ),
          const SizedBox(height: 8),
          _actionButton(
            label: '正确',
            color: _colorCorrect,
            icon: Icons.check_rounded,
            selected: feedback == 'correct',
            onTap: onMarkCorrect,
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? color : color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : color.withOpacity(0.4),
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: selected ? Colors.white : color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final hasSessionNo = question.sessionNo > 0;
    final showInternalId = question.id > 0 && question.id != question.sessionNo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部：当次解题题号醒目标识 + 右上角内部全局序号(#x)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [G.accent.withOpacity(0.25), G.accentDeep.withOpacity(0.25)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: G.accent.withOpacity(0.6)),
              ),
              child: Text(
                hasSessionNo ? '第 ${question.sessionNo} 题' : '题目',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: G.accentFg,
                ),
              ),
            ),
            const Spacer(),
            if (showInternalId)
              Text(
                '记录 #${question.id}',
                style: TextStyle(fontSize: 11, color: G.textFaint),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LatexRenderer(text: question.content),
        const SizedBox(height: 8),
        // 知识点标签
        if (question.knowledgePoints.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: question.knowledgePoints
                .map((kp) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: G.accentDeep.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: G.accentDeep.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        kp,
                        style: TextStyle(
                            fontSize: 11, color: G.textPrimary),
                      ),
                    ))
                .toList(),
          ),
        Divider(height: 20, color: G.glassBorder.withOpacity(0.6)),
        // 答案
        const Text(
          '答案',
          style: TextStyle(
              fontSize: 12, color: G.mint, fontWeight: FontWeight.w600),
        ),
        LatexRenderer(text: question.answer),
        const SizedBox(height: 8),
        // 解答过程
        const Text(
          '解答过程',
          style: TextStyle(
              fontSize: 12, color: G.accent, fontWeight: FontWeight.w600),
        ),
        LatexRenderer(text: question.solution),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 4),
        Text(
          '由 $modelName 提供  ·  置信度 ${(question.confidence * 100).toStringAsFixed(0)}%',
          style: TextStyle(fontSize: 11, color: G.textFaint),
        ),
      ],
    );
  }
}
