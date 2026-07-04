import 'package:flutter/material.dart';

import '../../core/app_ui.dart';
import '../../core/theme.dart';
import '../../data/ai_api_client.dart';
import '../capture/html_artifact_preview_screen.dart';
import 'quiz_paper_screen.dart';

class PracticePaperEntryScreen extends StatelessWidget {
  const PracticePaperEntryScreen({
    super.key,
    required this.paper,
    required this.selectedSubjects,
    required this.strategyLabel,
  });

  static const Color _entryAccent = Color(0xFF38558F);
  static const Color _practiceAccent = Color(0xFF557A1F);
  static const Color _handoutAccent = Color(0xFF9A5E00);
  static const Color _cardBorder = Color(0x1F111A3A);
  static const Color _cardShadow = Color(0x14111A3A);

  final PracticePaperResult paper;
  final List<String> selectedSubjects;
  final String strategyLabel;

  void _openTimedPractice(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizPaperScreen(
          questionCount: paper.questions.length,
          selectedSubjects: selectedSubjects,
          strategyLabel:
              paper.strategyLabel.isEmpty ? strategyLabel : paper.strategyLabel,
          generatedQuestions: paper.questions
              .map((item) => item.toQuizMap())
              .toList(growable: false),
          generatedTitle: paper.title,
          printableTitle: paper.title,
          printableHtml: paper.printableHtml,
          showPrintableAction: false,
        ),
      ),
    );
  }

  void _openHandout(BuildContext context) {
    final html = paper.printableHtml.trim();
    if (html.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前试卷没有可预览的打印讲义')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HtmlArtifactPreviewScreen(
          title: paper.title.isEmpty ? '打印讲义' : paper.title,
          htmlContent: html,
          infoTitle: 'A4 打印讲义预览',
          infoNote: '这份讲义由组卷接口生成，包含专题梳理、例题讲解、练习区和参考答案。',
          scrollable: true,
          exportable: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topics = paper.topicFocus.isEmpty
        ? '围绕错题薄弱点生成'
        : paper.topicFocus.take(3).join(' / ');
    final subjects = paper.subjectFocus.isEmpty
        ? selectedSubjects.where((item) => item != '全部学科').join(' / ')
        : paper.subjectFocus.take(3).join(' / ');

    return Scaffold(
      backgroundColor: AppPalette.night,
      appBar: AppBar(
        backgroundColor: AppPalette.night,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '智能组卷',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: AppSurface(
        topSafe: false,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: ListView(
          children: [
            const SizedBox(height: 8),
            Text(
              paper.title.isEmpty ? '专题针对性练习' : paper.title,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 23,
                fontWeight: FontWeight.w800,
                height: 1.22,
              ),
            ),
            if (paper.subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                paper.subtitle,
                style: const TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  icon: Icons.quiz_rounded,
                  label: '${paper.questions.length} 题',
                ),
                _MetaChip(
                  icon: Icons.timer_outlined,
                  label: '约 ${paper.estimatedMinutes} 分钟',
                ),
                if (subjects.trim().isNotEmpty)
                  _MetaChip(icon: Icons.category_rounded, label: subjects),
              ],
            ),
            const SizedBox(height: 22),
            AppPanel(
              padding: const EdgeInsets.all(18),
              color: Colors.white,
              borderRadius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '本次重点',
                    style: TextStyle(
                      color: _entryAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    topics,
                    style: const TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                  if (paper.handoutOverview.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      paper.handoutOverview,
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            _EntryCard(
              icon: Icons.speed_rounded,
              title: '计时练习',
              subtitle: '进入答题模式，记录用时、作答进度和存疑题。',
              actionLabel: '开始练习',
              accentColor: _practiceAccent,
              onTap: () => _openTimedPractice(context),
            ),
            const SizedBox(height: 14),
            _EntryCard(
              icon: Icons.description_outlined,
              title: '专题讲义',
              subtitle: '查看 A4 版式内容，适合复盘、批注和打印。',
              actionLabel: '查看讲义',
              accentColor: _handoutAccent,
              onTap: () => _openHandout(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PracticePaperEntryScreen._cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: PracticePaperEntryScreen._entryAccent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: PracticePaperEntryScreen._cardBorder),
            boxShadow: const [
              BoxShadow(
                color: PracticePaperEntryScreen._cardShadow,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: accentColor.withValues(alpha: 0.20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_forward_rounded, color: accentColor),
                    const SizedBox(height: 4),
                    Text(
                      actionLabel,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
