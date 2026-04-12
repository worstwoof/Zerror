import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/theme.dart';
import 'learning_plan_screen.dart';

class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({
    super.key,
    required this.totalQuestions,
    required this.answeredCount,
    required this.timeSpent,
    required this.questions,
    required this.userAnswers,
    required this.strategyLabel,
  });

  final int totalQuestions;
  final int answeredCount;
  final String timeSpent;
  final List<Map<String, dynamic>> questions;
  final Map<int, dynamic> userAnswers;
  final String strategyLabel;

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final wrongQuestions = _buildWrongQuestions();
    final correctCount = totalQuestions - wrongQuestions.length;
    final score = totalQuestions == 0
        ? 0
        : ((correctCount / totalQuestions) * 100).round();

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          '测验报告',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: AppSurface(
        padding: const EdgeInsets.fromLTRB(20, 72, 20, 12),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _scoreBoard(score, timeSpent, correctCount, wrongQuestions.length),
              const SizedBox(height: 20),
              AppPanel(
                color: AppPalette.matchaMist.withValues(alpha: 0.08),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.psychology_rounded,
                      color: AppPalette.almondCream,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI 学情诊断',
                            style: TextStyle(
                              color: AppPalette.almondCream,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _buildInsight(store, wrongQuestions.length),
                            style: const TextStyle(
                              color: AppPalette.textPrimary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  wrongQuestions.isEmpty ? '本次没有新增错题' : '本次错题摘取',
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (wrongQuestions.isEmpty)
                const AppPanel(
                  child: Text(
                    '这次组卷练习已经全部答对，可以直接回到学习计划继续下一轮任务。',
                    style: TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                )
              else
                ...wrongQuestions.map(_wrongQuestionCard),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: AppPalette.night.withValues(alpha: 0.94),
          border: Border(
            top: BorderSide(
              color: AppPalette.pastelGrey.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                    color: AppPalette.pastelGrey.withValues(alpha: 0.14),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  '返回上一页',
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppPrimaryButton(
                label: wrongQuestions.isEmpty ? '去学习计划' : '一键回流档案',
                icon: wrongQuestions.isEmpty
                    ? Icons.event_note_rounded
                    : Icons.archive_rounded,
                onPressed: () => _archiveMistakes(context, wrongQuestions),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildInsight(AppStore store, int wrongCount) {
    if (wrongCount == 0) {
      return '这轮 $strategyLabel 练习已经稳定通过，建议回到学习计划继续推进「${store.weakestSubject}」之外的后续任务。';
    }
    return '这次 $strategyLabel 暴露出了 $wrongCount 道需要回收的题目。建议先把它们收入错题档案，再围绕「${store.weakestSubject}」继续做针对性复习。';
  }

  List<Map<String, dynamic>> _buildWrongQuestions() {
    final wrong = <Map<String, dynamic>>[];

    for (var index = 0; index < questions.length; index++) {
      final question = questions[index];
      final userAnswer = userAnswers[index];
      final isCorrect = _isQuestionCorrect(question, userAnswer);
      if (isCorrect) continue;

      wrong.add({
        ...question,
        'userAnswer': userAnswer,
      });
    }

    return wrong;
  }

  bool _isQuestionCorrect(Map<String, dynamic> question, dynamic userAnswer) {
    if (userAnswer == null) return false;

    if (question['answerType'] == 'choice') {
      return userAnswer == question['correctIndex'];
    }

    final answerText = userAnswer.toString().trim().toLowerCase();
    final keywords = (question['keywords'] as List<dynamic>? ?? const [])
        .cast<String>()
        .map((item) => item.toLowerCase())
        .toList();

    if (answerText.isEmpty) return false;
    if (keywords.isEmpty) return true;

    var matched = 0;
    for (final keyword in keywords) {
      if (answerText.contains(keyword)) {
        matched++;
      }
    }
    return matched >= 1;
  }

  void _archiveMistakes(
    BuildContext context,
    List<Map<String, dynamic>> wrongQuestions,
  ) {
    if (wrongQuestions.isNotEmpty) {
      final store = AppStateScope.of(context);
      final drafts = wrongQuestions.map((item) {
        final userAnswer = item['userAnswer'];
        final answerText = userAnswer == null
            ? '本次组卷中暂未作答。'
            : item['answerType'] == 'choice'
                ? '本次选择：${item['options'][userAnswer as int]}'
                : '本次作答：$userAnswer';

        return NewErrorDraft(
          subject: item['subject'] as String,
          topic: item['topic'] as String? ?? '组卷回流错题',
          question: item['content'] as String,
          reason: item['reasonHint'] as String? ?? '组卷练习中暴露出薄弱点',
          tags: [
            item['subject'] as String,
            item['topic'] as String? ?? '组卷回流错题',
            '组卷回流',
          ],
          myAnswer: answerText,
          aiAnalysis: item['analysisHint'] as String? ??
              '这道题来自智能组卷，建议先回到错题档案做一轮复盘，再进入后续训练。',
        );
      }).toList(growable: false);

      store.addErrorRecords(drafts);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已将 ${drafts.length} 道错题回流到档案')),
      );
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LearningPlanScreen()),
      (route) => route.isFirst,
    );
  }

  Widget _scoreBoard(int score, String timeSpent, int correct, int wrong) {
    return AppPanel(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  color: AppPalette.matchaMist,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                children: [
                  Text(
                    '$score',
                    style: const TextStyle(
                      color: AppPalette.almondCream,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const Text(
                    '综合得分',
                    style: TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('答对', '$correct 题', AppPalette.matchaMist),
              Container(
                width: 1,
                height: 30,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              _statItem('答错', '$wrong 题', const Color(0xFFE17D6B)),
              Container(
                width: 1,
                height: 30,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              _statItem('用时', timeSpent, AppPalette.honeyOrange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppPalette.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _wrongQuestionCard(Map<String, dynamic> q) {
    final userAnswer = q['userAnswer'];
    final displayedUserAnswer = userAnswer == null
        ? '未作答'
        : q['answerType'] == 'choice'
            ? (q['options'] as List<dynamic>)[userAnswer as int].toString()
            : userAnswer.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x22E17D6B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '答错',
                    style: TextStyle(
                      color: Color(0xFFE17D6B),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${q['subject']} · ${q['type']}',
                    style: const TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              q['content'] as String,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '你的作答: ',
                        style: TextStyle(
                          color: AppPalette.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          displayedUserAnswer,
                          style: const TextStyle(
                            color: Color(0xFFE17D6B),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '正确方向: ',
                        style: TextStyle(
                          color: AppPalette.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          q['correctAnswer'] as String? ?? '回到档案复盘这道题',
                          style: const TextStyle(
                            color: AppPalette.matchaMist,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
