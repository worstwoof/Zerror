import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../capture/html_artifact_preview_screen.dart';
import 'quiz_result_screen.dart';

class QuizPaperScreen extends StatefulWidget {
  const QuizPaperScreen({
    super.key,
    this.questionCount = 15,
    this.selectedSubjects = const [],
    this.strategyLabel = '抗遗忘复习',
    this.generatedQuestions,
    this.generatedTitle,
    this.printableTitle,
    this.printableHtml,
  });

  final int questionCount;
  final List<String> selectedSubjects;
  final String strategyLabel;
  final List<Map<String, dynamic>>? generatedQuestions;
  final String? generatedTitle;
  final String? printableTitle;
  final String? printableHtml;

  @override
  State<QuizPaperScreen> createState() => _QuizPaperScreenState();
}

class _QuizPaperScreenState extends State<QuizPaperScreen> {
  late final PageController _pageController;
  final Map<int, dynamic> _userAnswers = {};
  final Set<int> _markedQuestions = {};

  Timer? _timer;
  int _currentIndex = 0;
  int _secondsElapsed = 0;
  late List<Map<String, dynamic>> _questions;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _questions = _buildQuestions();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _buildQuestions() {
    final generated = widget.generatedQuestions;
    if (generated != null && generated.isNotEmpty) {
      return generated;
    }

    final selected = widget.selectedSubjects.where((item) => item != '全部学科').toList();
    final primarySubject = selected.isNotEmpty ? selected.first : '线性代数';

    final base = <Map<String, dynamic>>[
      {
        'type': '单选题',
        'subject': primarySubject,
        'topic': '矩阵特征值与相似对角化',
        'content': '设矩阵 A 的特征值为 λ1、λ2、λ3，且 A 可逆。A 的伴随矩阵 A* 的特征值应为哪一组？',
        'options': ['λ1, λ2, λ3', '1/λ1, 1/λ2, 1/λ3', '|A|/λ1, |A|/λ2, |A|/λ3', '|A|λ1, |A|λ2, |A|λ3'],
        'correctIndex': 2,
        'correctAnswer': '|A|/λ1, |A|/λ2, |A|/λ3',
        'reasonHint': '伴随矩阵与逆矩阵关系没串起来',
        'analysisHint': '先写出 A* = |A|A^-1，再把 A^-1 的特征值 1/λi 代进去。',
        'answerType': 'choice',
      },
      {
        'type': '简答题',
        'subject': '数据结构',
        'topic': 'KMP next 数组构造',
        'content': '在 KMP 算法中，next 数组的作用是什么？失配后为什么能直接跳转？',
        'correctAnswer': 'next 数组记录最长相等前后缀长度，失配后跳到对应前缀位置继续比较。',
        'keywords': ['前后缀', '跳转', 'next'],
        'reasonHint': '边界条件和跳转逻辑不够稳',
        'analysisHint': '记住 next 的本质是最长相等前后缀长度，跳转不是凭空跳，而是利用已知相等部分。',
        'answerType': 'text',
      },
      {
        'type': '代码题',
        'subject': 'Java',
        'topic': '策略模式与接口抽象',
        'content': '如何用接口把不同业务策略统一调度，避免 if-else 分支不断膨胀？',
        'correctAnswer': '抽象策略接口，由具体实现承载不同规则，上下文只依赖接口完成调用。',
        'keywords': ['接口', '策略', '上下文'],
        'reasonHint': '抽象层次和职责边界不够清晰',
        'analysisHint': '重点不是写出某个类名，而是先拆出策略接口，再让调用方只依赖接口。',
        'answerType': 'text',
      },
    ];

    final extras = List.generate(
      (widget.questionCount - base.length).clamp(0, 100),
      (index) => <String, dynamic>{
        'type': '判断题',
        'subject': selected.isNotEmpty ? selected[index % selected.length] : '综合考察',
        'topic': '错题迁移训练',
        'content': '这是基于「${widget.strategyLabel}」自动生成的第 ${index + 4} 道变式练习，用来继续回收你的薄弱点。',
        'options': ['正确', '错误'],
        'correctIndex': index.isEven ? 0 : 1,
        'correctAnswer': index.isEven ? '正确' : '错误',
        'reasonHint': '对变式题的判断还不够稳定',
        'analysisHint': '这类题重点看你能不能把原错题中的结论迁移到新表述里。',
        'answerType': 'choice',
      },
    );

    return [...base, ...extras];
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remain = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remain.toString().padLeft(2, '0')}';
  }

  void _submitPaper() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppPalette.kombuGreen,
        title: const Text(
          '确认交卷？',
          style: TextStyle(color: AppPalette.textPrimary),
        ),
        content: Text(
          '你已作答 ${_userAnswers.length}/${_questions.length} 题，用时 ${_formatTime(_secondsElapsed)}。',
          style: const TextStyle(color: AppPalette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              '继续答题',
              style: TextStyle(color: AppPalette.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => QuizResultScreen(
                    totalQuestions: _questions.length,
                    answeredCount: _userAnswers.length,
                    timeSpent: _formatTime(_secondsElapsed),
                    questions: _questions,
                    userAnswers: Map<int, dynamic>.from(_userAnswers),
                    strategyLabel: widget.strategyLabel,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.almondCream,
              foregroundColor: AppPalette.night,
            ),
            child: const Text('确认交卷'),
          ),
        ],
      ),
    );
  }

  void _openPrintableHandout() {
    final html = widget.printableHtml;
    if (html == null || html.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前试卷没有可预览的打印讲义')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HtmlArtifactPreviewScreen(
          title: widget.printableTitle ?? '打印讲义',
          htmlContent: html,
          infoTitle: 'A4 打印讲义预览',
          infoNote: '这份讲义由组卷接口生成，包含题目区、作答留白和参考答案。可在支持打印的 WebView 或浏览器中按 A4 版式输出。',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.night,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppPalette.textPrimary),
        title: Column(
          children: [
            const Text(
              '智能组卷测验',
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.generatedTitle ?? _formatTime(_secondsElapsed),
              style: const TextStyle(
                color: AppPalette.almondCream,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (widget.printableHtml?.trim().isNotEmpty == true)
            IconButton(
              tooltip: '预览打印讲义',
              onPressed: _openPrintableHandout,
              icon: const Icon(
                Icons.description_outlined,
                color: AppPalette.almondCream,
              ),
            ),
          TextButton(
            onPressed: _submitPaper,
            child: const Text(
              '交卷',
              style: TextStyle(
                color: AppPalette.almondCream,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppPalette.appBackground),
            ),
          ),
          Positioned.fill(
            child: Image.asset('assets/images/auth_bg.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: AppPalette.night.withValues(alpha: 0.72)),
          ),
          Column(
            children: [
              _buildQuestionNavigator(),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _questions.length,
                  onPageChanged: (index) => setState(() => _currentIndex = index),
                  itemBuilder: (context, index) {
                    return _buildQuestionCard(_questions[index], index);
                  },
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionNavigator() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _questions.length,
        itemBuilder: (context, index) {
          final isCurrent = _currentIndex == index;
          final isAnswered = _userAnswers.containsKey(index);
          final isMarked = _markedQuestions.contains(index);

          Color bubbleColor = Colors.transparent;
          Color textColor = AppPalette.textSecondary;
          Border? border = Border.all(
            color: Colors.white.withValues(alpha: 0.10),
          );

          if (isCurrent) {
            bubbleColor = AppPalette.matchaMist;
            textColor = AppPalette.night;
            border = null;
          } else if (isMarked) {
            bubbleColor = AppPalette.honeyOrange.withValues(alpha: 0.20);
            textColor = AppPalette.honeyOrange;
            border = Border.all(color: AppPalette.honeyOrange);
          } else if (isAnswered) {
            bubbleColor = AppPalette.matchaMist.withValues(alpha: 0.18);
            textColor = AppPalette.matchaMist;
            border = Border.all(
              color: AppPalette.matchaMist.withValues(alpha: 0.40),
            );
          }

          return GestureDetector(
            onTap: () => _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
            child: Container(
              width: 40,
              margin: const EdgeInsets.only(right: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bubbleColor,
                shape: BoxShape.circle,
                border: border,
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int index) {
    final cardColor = AppPalette.kombuGreen.withValues(alpha: 0.88);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppPalette.pastelGrey.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.matchaMist,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    question['type'] as String,
                    style: const TextStyle(
                      color: AppPalette.night,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${question['subject']} · ${question['topic']}',
                    style: const TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              question['content'] as String,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 17,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            if (question['answerType'] == 'choice')
              ..._buildChoiceOptions(question, index)
            else
              TextField(
                maxLines: 8,
                onChanged: (text) {
                  setState(() {
                    if (text.trim().isEmpty) {
                      _userAnswers.remove(index);
                    } else {
                      _userAnswers[index] = text;
                    }
                  });
                },
                style: const TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 15,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: '点击此处输入你的推导过程或笔记...',
                  hintStyle: TextStyle(
                    color: AppPalette.textSecondary.withValues(alpha: 0.50),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChoiceOptions(Map<String, dynamic> question, int index) {
    final options = (question['options'] as List<dynamic>).cast<String>();
    const prefixes = ['A', 'B', 'C', 'D', 'E', 'F'];

    return List.generate(options.length, (optIndex) {
      final optionText = options[optIndex];
      final isSelected = _userAnswers[index] == optIndex;

      return InkWell(
        onTap: () => setState(() => _userAnswers[index] = optIndex),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppPalette.matchaMist.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppPalette.matchaMist
                  : Colors.white.withValues(alpha: 0.10),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                '${optIndex < prefixes.length ? prefixes[optIndex] : optIndex + 1}.  ',
                style: TextStyle(
                  color: isSelected
                      ? AppPalette.matchaMist
                      : AppPalette.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  optionText,
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildBottomBar() {
    final isMarked = _markedQuestions.contains(_currentIndex);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppPalette.night.withValues(alpha: 0.94),
        border: Border(
          top: BorderSide(
            color: AppPalette.pastelGrey.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: _currentIndex > 0
                  ? () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      )
                  : null,
              icon: Icon(
                Icons.arrow_back_ios_rounded,
                color: _currentIndex > 0
                    ? AppPalette.textPrimary
                    : AppPalette.textSecondary.withValues(alpha: 0.3),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  if (isMarked) {
                    _markedQuestions.remove(_currentIndex);
                  } else {
                    _markedQuestions.add(_currentIndex);
                  }
                });
              },
              icon: Icon(
                isMarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: isMarked ? AppPalette.honeyOrange : AppPalette.textSecondary,
              ),
              label: Text(
                isMarked ? '已存疑' : '标记存疑',
                style: TextStyle(
                  color: isMarked ? AppPalette.honeyOrange : AppPalette.textSecondary,
                ),
              ),
            ),
            IconButton(
              onPressed: _currentIndex < _questions.length - 1
                  ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      )
                  : null,
              icon: Icon(
                Icons.arrow_forward_ios_rounded,
                color: _currentIndex < _questions.length - 1
                    ? AppPalette.textPrimary
                    : AppPalette.textSecondary.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
