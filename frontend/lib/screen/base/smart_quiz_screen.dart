import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/rose_three_loader.dart';
import '../../core/theme.dart';
import 'quiz_paper_screen.dart';

class SmartQuizScreen extends StatefulWidget {
  const SmartQuizScreen({super.key});

  @override
  State<SmartQuizScreen> createState() => _SmartQuizScreenState();
}

class _SmartQuizScreenState extends State<SmartQuizScreen> {
  final List<String> _selectedSubjects = ['全部学科'];

  int _questionCount = 15;
  int _selectedStrategy = 0;
  bool _isGenerating = false;

  static const List<(String, String, IconData)> _strategies = [
    ('抗遗忘复习', '优先抓取处于临界遗忘点的历史错题', Icons.timeline_rounded),
    ('薄弱点突破', '集中攻克近期错误率最高的知识点', Icons.flash_on_rounded),
    ('举一反三拓展', '围绕已有错题自动生成变式训练', Icons.hub_rounded),
  ];

  Future<void> _startGenerate() async {
    setState(() => _isGenerating = true);
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    setState(() => _isGenerating = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizPaperScreen(
          questionCount: _questionCount,
          selectedSubjects: List<String>.from(_selectedSubjects),
          strategyLabel: _strategies[_selectedStrategy].$1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final subjects = [
      '全部学科',
      ...store.subjectOptions.where((item) => item != '全部')
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppPalette.textPrimary),
        title: const Text(
          'AI 智能组卷',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: AppSurface(
        padding: const EdgeInsets.fromLTRB(20, 72, 20, 12),
        child: _isGenerating
            ? _buildGeneratingState()
            : _buildConfigForm(subjects),
      ),
      bottomNavigationBar: _isGenerating
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: BoxDecoration(
                color: AppPalette.night.withValues(alpha: 0.94),
                border: Border(
                  top: BorderSide(
                    color: AppPalette.pastelGrey.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: AppPrimaryButton(
                  label: '开始生成专属试卷',
                  icon: Icons.auto_awesome,
                  onPressed: _startGenerate,
                ),
              ),
            ),
    );
  }

  Widget _buildGeneratingState() {
    return Center(
      child: AppPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            RoseThreeLoader(size: 156),
            SizedBox(height: 24),
            Text(
              'AI 正在调取错题档案...',
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '正在根据你的复习节奏和薄弱点匹配最合适的题目',
              style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigForm(List<String> subjects) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle(
            title: '组卷题量',
            subtitle: '控制练习强度和完成时长',
            icon: Icons.tune_rounded,
          ),
          const SizedBox(height: 16),
          AppPanel(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '练习强度',
                      style: TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$_questionCount 题',
                      style: const TextStyle(
                        color: AppPalette.almondCream,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _questionCount.toDouble(),
                  min: 5,
                  max: 50,
                  divisions: 9,
                  activeColor: AppPalette.matchaMist,
                  inactiveColor: AppPalette.matchaMist.withValues(alpha: 0.2),
                  label: '$_questionCount',
                  onChanged: (value) {
                    setState(() => _questionCount = value.toInt());
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const AppSectionTitle(
            title: '选择范围',
            subtitle: '可以多选，也可以直接覆盖全部学科',
            icon: Icons.category_rounded,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: subjects.map((subject) {
              final isSelected = _selectedSubjects.contains(subject);
              return FilterChip(
                label: Text(subject),
                selected: isSelected,
                selectedColor: AppPalette.matchaMist.withValues(alpha: 0.18),
                backgroundColor: AppPalette.pastelGrey.withValues(alpha: 0.08),
                checkmarkColor: AppPalette.matchaMist,
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppPalette.matchaMist
                      : AppPalette.textSecondary,
                ),
                side: BorderSide(
                  color: isSelected
                      ? AppPalette.matchaMist.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
                onSelected: (selected) {
                  setState(() {
                    if (subject == '全部学科') {
                      if (selected) {
                        _selectedSubjects
                          ..clear()
                          ..add('全部学科');
                      } else {
                        _selectedSubjects.clear();
                      }
                      return;
                    }

                    _selectedSubjects.remove('全部学科');
                    if (selected) {
                      _selectedSubjects.add(subject);
                    } else {
                      _selectedSubjects.remove(subject);
                    }

                    if (_selectedSubjects.isEmpty) {
                      _selectedSubjects.add('全部学科');
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          const AppSectionTitle(
            title: 'AI 抽题策略',
            subtitle: '选一个更符合当前状态的出题方式',
            icon: Icons.psychology_rounded,
          ),
          const SizedBox(height: 16),
          ...List.generate(_strategies.length, (index) {
            final item = _strategies[index];
            return Padding(
              padding: EdgeInsets.only(
                  bottom: index == _strategies.length - 1 ? 0 : 12),
              child: _strategyCard(index, item.$1, item.$2, item.$3),
            );
          }),
        ],
      ),
    );
  }

  Widget _strategyCard(
      int index, String title, String subtitle, IconData icon) {
    final isSelected = _selectedStrategy == index;
    return InkWell(
      onTap: () => setState(() => _selectedStrategy = index),
      borderRadius: BorderRadius.circular(22),
      child: AppPanel(
        color: isSelected
            ? AppPalette.matchaMist.withValues(alpha: 0.10)
            : AppPalette.pastelGrey.withValues(alpha: 0.07),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppPalette.matchaMist
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppPalette.night : AppPalette.textSecondary,
              ),
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
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected
                  ? AppPalette.matchaMist
                  : AppPalette.textSecondary.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
