import 'dart:async';
import 'package:flutter/material.dart';
import 'quiz_result_screen.dart'; // 🌟 引入刚写的测验报告页
class QuizPaperScreen extends StatefulWidget {
  final int questionCount; // 接收生成的题量

  const QuizPaperScreen({super.key, this.questionCount = 15});

  @override
  State<QuizPaperScreen> createState() => _QuizPaperScreenState();
}

class _QuizPaperScreenState extends State<QuizPaperScreen> {
  final Color primaryGreen = const Color(0xFF70A88D);

  late PageController _pageController;
  int _currentIndex = 0;

  // 计时器相关
  Timer? _timer;
  int _secondsElapsed = 0;

  // 用户答题数据状态
  final Map<int, dynamic> _userAnswers = {}; // 存储每题的答案
  final Set<int> _markedQuestions = {}; // 存储被“标记存疑”的题号

  // 模拟 AI 生成的考卷数据
  late List<Map<String, dynamic>> _mockQuestions;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();

    // 初始化模拟试卷数据 (包含选择题和简答题)
    _mockQuestions = [
      {
        'type': '单选题', 'subject': '线性代数',
        'content': '设矩阵 A 的特征值为 λ1, λ2, λ3，且 A 可逆。A 的伴随矩阵 A* 的特征值是？',
        'options': ['λ1, λ2, λ3', '1/λ1, 1/λ2, 1/λ3', '|A|/λ1, |A|/λ2, |A|/λ3', '|A|λ1, |A|λ2, |A|λ3'],
        'answerType': 'choice'
      },
      {
        'type': '简答题', 'subject': '数据结构',
        'content': '在 C++ 中编写 KMP 模式匹配算法时，请简述 next 数组的作用，以及当发生失配时，模式串指针 j 的回溯逻辑是什么？',
        'answerType': 'text'
      },
      {
        'type': '代码题', 'subject': 'Java',
        'content': '在 3D 彩票模拟系统中，如何使用 Interface（接口）实现不同的抽奖策略？请写出核心接口和实现类的结构设计。',
        'answerType': 'text'
      },
      // 模拟凑够传入的题量
      ...List.generate(widget.questionCount - 3, (index) => {
        'type': '判断题', 'subject': '综合考察',
        'content': '这是 AI 生成的第 ${index + 4} 道拓展变形题，用于巩固你的薄弱环节。',
        'options': ['正确', '错误'],
        'answerType': 'choice'
      })
    ];
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  String _formatTime(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

// 提交交卷
  void _submitPaper() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E2823) : Colors.white,
        title: const Text('确认交卷？'),
        content: Text('你已作答 ${_userAnswers.length}/${_mockQuestions.length} 题，耗时 ${_formatTime(_secondsElapsed)}。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('继续答题', style: TextStyle(color: primaryGreen))
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // 1. 关闭这个确认弹窗

              // 🌟 2. 核心修改：将当前的“试卷页”替换为“成绩报告页”，并把数据传过去
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => QuizResultScreen(
                    totalQuestions: _mockQuestions.length,
                    answeredCount: _userAnswers.length,
                    timeSpent: _formatTime(_secondsElapsed),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
            child: const Text('确认交卷'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF161E1A) : const Color(0xFFF8FAF9);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2C362F);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
        title: Column(
          children: [
            Text('智能组卷测验', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(_formatTime(_secondsElapsed), style: TextStyle(color: primaryGreen, fontSize: 13, fontFamily: 'monospace')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _submitPaper,
            child: Text('交卷', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部答题卡进度条
          _buildQuestionNavigator(textColor),

          // 核心答题区 (支持左右滑动)
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _mockQuestions.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return _buildQuestionCard(_mockQuestions[index], index, textColor, isDarkMode);
              },
            ),
          ),

          // 底部控制栏
          _buildBottomBar(textColor, isDarkMode),
        ],
      ),
    );
  }

  // ================= 组件：顶部答题导航 =================
  Widget _buildQuestionNavigator(Color textColor) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _mockQuestions.length,
        itemBuilder: (context, index) {
          final isCurrent = _currentIndex == index;
          final isAnswered = _userAnswers.containsKey(index);
          final isMarked = _markedQuestions.contains(index);

          Color bubbleColor = Colors.transparent;
          Color txtColor = textColor.withValues(alpha: 0.5);
          Border? border = Border.all(color: textColor.withValues(alpha: 0.1));

          if (isCurrent) {
            bubbleColor = primaryGreen;
            txtColor = Colors.white;
            border = null;
          } else if (isMarked) {
            bubbleColor = Colors.orange.withValues(alpha: 0.2);
            txtColor = Colors.orange;
            border = Border.all(color: Colors.orange);
          } else if (isAnswered) {
            bubbleColor = primaryGreen.withValues(alpha: 0.2);
            txtColor = primaryGreen;
            border = Border.all(color: primaryGreen.withValues(alpha: 0.5));
          }

          return GestureDetector(
            onTap: () => _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
            child: Container(
              width: 40,
              margin: const EdgeInsets.only(right: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bubbleColor, shape: BoxShape.circle, border: border),
              child: Text('${index + 1}', style: TextStyle(color: txtColor, fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
    );
  }

  // ================= 组件：单道题的渲染卡片 =================
  Widget _buildQuestionCard(Map<String, dynamic> question, int index, Color textColor, bool isDarkMode) {
    final cardColor = isDarkMode ? const Color(0xFF1E2823) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 题目标签
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(6)),
                  child: Text(question['type'], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Text(question['subject'], style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 13)),
              ],
            ),
            const SizedBox(height: 24),

            // 题目正文
            Text(question['content'], style: TextStyle(color: textColor, fontSize: 17, height: 1.6, fontWeight: FontWeight.w500)),
            const SizedBox(height: 32),

            // 答题区 (根据题目类型动态渲染)
            if (question['answerType'] == 'choice')
              ...List.generate((question['options'] as List).length, (optIndex) {
                final optionText = question['options'][optIndex];
                final isSelected = _userAnswers[index] == optIndex;
                final prefixes = ['A', 'B', 'C', 'D'];

                return InkWell(
                  onTap: () => setState(() => _userAnswers[index] = optIndex),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryGreen.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? primaryGreen : textColor.withValues(alpha: 0.1), width: isSelected ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Text('${prefixes[optIndex]}.  ', style: TextStyle(color: isSelected ? primaryGreen : textColor.withValues(alpha: 0.5), fontSize: 16, fontWeight: FontWeight.bold)),
                        Expanded(child: Text(optionText, style: TextStyle(color: textColor, fontSize: 15))),
                      ],
                    ),
                  ),
                );
              })
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
                controller: TextEditingController(text: _userAnswers[index] ?? ''),
                style: TextStyle(color: textColor, fontSize: 15, height: 1.5),
                decoration: InputDecoration(
                  hintText: '点击此处输入你的推导过程或笔记 (支持 LaTeX 语法)...\n例如: f(x) = \\int_{0}^{x} t dt',
                  hintStyle: TextStyle(color: textColor.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ================= 组件：底部控制栏 =================
  Widget _buildBottomBar(Color textColor, bool isDarkMode) {
    final bool isMarked = _markedQuestions.contains(_currentIndex);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E2823) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 上一题
            IconButton(
              onPressed: _currentIndex > 0 ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut) : null,
              icon: Icon(Icons.arrow_back_ios_rounded, color: _currentIndex > 0 ? textColor : textColor.withValues(alpha: 0.2)),
            ),

            // 标记存疑按钮
            TextButton.icon(
              onPressed: () {
                setState(() {
                  isMarked ? _markedQuestions.remove(_currentIndex) : _markedQuestions.add(_currentIndex);
                });
              },
              icon: Icon(isMarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: isMarked ? Colors.orange : textColor.withValues(alpha: 0.5)),
              label: Text(isMarked ? '已存疑' : '标记存疑', style: TextStyle(color: isMarked ? Colors.orange : textColor.withValues(alpha: 0.5))),
            ),

            // 下一题
            IconButton(
              onPressed: _currentIndex < _mockQuestions.length - 1 ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut) : null,
              icon: Icon(Icons.arrow_forward_ios_rounded, color: _currentIndex < _mockQuestions.length - 1 ? textColor : textColor.withValues(alpha: 0.2)),
            ),
          ],
        ),
      ),
    );
  }
}