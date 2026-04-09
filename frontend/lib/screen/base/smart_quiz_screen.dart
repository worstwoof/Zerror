import 'package:flutter/material.dart';
import 'quiz_paper_screen.dart'; // 🌟 引入刚写的试卷页
class SmartQuizScreen extends StatefulWidget {
  const SmartQuizScreen({super.key});

  @override
  State<SmartQuizScreen> createState() => _SmartQuizScreenState();
}

class _SmartQuizScreenState extends State<SmartQuizScreen> {
  final Color primaryGreen = const Color(0xFF70A88D);

  // 组卷配置状态
  final List<String> _subjects = ['全部学科', '线性代数', 'Java', '数据结构', '考研政治'];
  final List<String> _selectedSubjects = ['线性代数']; // 默认选中

  int _questionCount = 15; // 默认 15 题
  int _selectedStrategy = 0; // 0: 艾宾浩斯, 1: 薄弱点突击, 2: 综合模拟

  bool _isGenerating = false; // 控制 AI 生成动画状态

  // 模拟 AI 组卷过程
  Future<void> _startGenerate() async {
    setState(() => _isGenerating = true);

    // 模拟等待 2.5 秒
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;
    setState(() => _isGenerating = false);

    // 🌟 修改：组卷成功后，直接用 pushReplacement 跳入试卷页
    // (用 Replacement 是因为通常做题时按返回键不应该回到“生成中”的页面)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuizPaperScreen(questionCount: _questionCount),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1E2823) : const Color(0xFFF0F4F2);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2C362F);
    final cardColor = isDarkMode ? Colors.white12 : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
        title: Text('AI 智能组卷', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: _isGenerating
          ? _buildGeneratingState(textColor)
          : _buildConfigForm(textColor, cardColor),

      // 底部生成按钮
      bottomNavigationBar: _isGenerating ? null : Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bgColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: ElevatedButton.icon(
          onPressed: _startGenerate,
          icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          label: const Text('开始生成专属试卷', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  // ============== 状态 1：AI 组卷加载中 ==============
  Widget _buildGeneratingState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryGreen),
          const SizedBox(height: 24),
          Text('AI 正在调取错题档案...', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('正在根据你的遗忘曲线匹配最佳题目', style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 13)),
        ],
      ),
    );
  }

  // ============== 状态 2：配置表单 ==============
  Widget _buildConfigForm(Color textColor, Color cardColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 模块 1：题量配置 ---
          Text('组卷题量', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('练习强度', style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 14)),
                    Text('$_questionCount 题', style: TextStyle(color: primaryGreen, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: primaryGreen,
                    inactiveTrackColor: primaryGreen.withOpacity(0.2),
                    thumbColor: primaryGreen,
                    overlayColor: primaryGreen.withOpacity(0.1),
                    valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                  ),
                  child: Slider(
                    value: _questionCount.toDouble(),
                    min: 5,
                    max: 50,
                    divisions: 9,
                    label: '$_questionCount',
                    onChanged: (value) => setState(() => _questionCount = value.toInt()),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('快速测验', style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 12)),
                    Text('深度模拟', style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // --- 模块 2：选择学科 ---
          Text('选择范围 (可多选)', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _subjects.map((subject) {
              final isSelected = _selectedSubjects.contains(subject);
              return FilterChip(
                label: Text(subject),
                selected: isSelected,
                selectedColor: primaryGreen.withOpacity(0.2),
                backgroundColor: cardColor,
                checkmarkColor: primaryGreen,
                labelStyle: TextStyle(color: isSelected ? primaryGreen : textColor.withOpacity(0.7)),
                side: BorderSide(color: isSelected ? primaryGreen.withOpacity(0.5) : Colors.transparent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (selected) {
                  setState(() {
                    if (subject == '全部学科') {
                      selected ? _selectedSubjects.replaceRange(0, _selectedSubjects.length, ['全部学科']) : _selectedSubjects.clear();
                    } else {
                      _selectedSubjects.remove('全部学科');
                      selected ? _selectedSubjects.add(subject) : _selectedSubjects.remove(subject);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // --- 模块 3：AI 组卷策略 ---
          Text('AI 抽题策略', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildStrategyCard(
            index: 0,
            title: '艾宾浩斯抗遗忘',
            subtitle: '优先抽取处于“遗忘临界点”的历史错题',
            icon: Icons.timeline_rounded,
            textColor: textColor,
            cardColor: cardColor,
          ),
          const SizedBox(height: 12),
          _buildStrategyCard(
            index: 1,
            title: '高频薄弱点突击',
            subtitle: '集中突破你近期错误率最高的知识点',
            icon: Icons.psychology_rounded,
            textColor: textColor,
            cardColor: cardColor,
          ),
          const SizedBox(height: 12),
          _buildStrategyCard(
            index: 2,
            title: '举一反三拓展',
            subtitle: 'AI 自动生成现有错题的变形题进行考核',
            icon: Icons.hub_rounded,
            textColor: textColor,
            cardColor: cardColor,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 构建单选的策略卡片
  Widget _buildStrategyCard({
    required int index, required String title, required String subtitle,
    required IconData icon, required Color textColor, required Color cardColor,
  }) {
    final bool isSelected = _selectedStrategy == index;

    return InkWell(
      onTap: () => setState(() => _selectedStrategy = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen.withOpacity(0.1) : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? primaryGreen : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? primaryGreen : textColor.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : textColor.withOpacity(0.5), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12, height: 1.3)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: primaryGreen, size: 24)
            else
              Icon(Icons.circle_outlined, color: textColor.withOpacity(0.2), size: 24),
          ],
        ),
      ),
    );
  }
}