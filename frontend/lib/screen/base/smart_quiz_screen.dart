import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/theme.dart';

class SmartQuizScreen extends StatefulWidget {
  const SmartQuizScreen({super.key});

  @override
  State<SmartQuizScreen> createState() => _SmartQuizScreenState();
}

class _SmartQuizScreenState extends State<SmartQuizScreen> {
  final List<String> _selectedSubjects = ['全部学科'];

  int _questionCount = 15;
  int _selectedStrategy = 0;

  static const Color _quizPanel = Colors.white;
  static const Color _quizPanelSoft = Color(0xFFF6F9FF);
  static const Color _quizAccent = Color(0xFF38558F);
  static const Color _quizAccentSoft = Color(0xFFE7ECF6);
  static const Color _quizMint = Color(0xFF3E8F7A);
  static const Color _quizMintSoft = Color(0xFFE5F6F1);
  static const Color _quizCoral = Color(0xFFC86D63);
  static const Color _quizCoralSoft = Color(0xFFFFEFEC);
  static const Color _quizViolet = Color(0xFF7662B8);
  static const Color _quizVioletSoft = Color(0xFFF0ECFF);
  static const Color _quizBottomBar = Color(0xFFF8FBFF);
  static const Color _quizActionButton = Color(0xFFE7F3FF);

  static const List<Color> _subjectTints = [
    _quizAccent,
    _quizMint,
    _quizCoral,
    _quizViolet,
  ];

  static const List<Color> _subjectSoftTints = [
    _quizAccentSoft,
    _quizMintSoft,
    _quizCoralSoft,
    _quizVioletSoft,
  ];

  static const List<Color> _strategyTints = [
    _quizAccent,
    _quizCoral,
    _quizViolet,
  ];

  static const List<Color> _strategySoftTints = [
    _quizAccentSoft,
    _quizCoralSoft,
    _quizVioletSoft,
  ];

  static const List<(String, String, IconData)> _strategies = [
    ('抗遗忘复习', '优先抓取处于临界遗忘点的历史错题', Icons.timeline_rounded),
    ('薄弱点突破', '集中攻克近期错误率最高的知识点', Icons.flash_on_rounded),
    ('举一反三拓展', '围绕已有错题自动生成变式训练', Icons.hub_rounded),
  ];

  void _startGenerate() {
    final store = AppStateScope.of(context);
    final sourceErrors = _selectedErrors(store);
    if (sourceErrors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先录入错题，AI 才能生成针对性练习讲义')),
      );
      return;
    }

    store.enqueuePracticePaperTask(
      sourceErrors: sourceErrors,
      questionCount: _questionCount,
      selectedSubjects: List<String>.from(_selectedSubjects),
      strategyLabel: _strategies[_selectedStrategy].$1,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('智能组卷已放到后台，回首页右上角查看进度')),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  List<ErrorRecord> _selectedErrors(AppStore store) {
    final selected = _selectedSubjects
        .where((item) => item != '全部学科' && item != '全部')
        .toSet();
    if (selected.isEmpty) {
      return store.pendingReviewErrors.isNotEmpty
          ? store.pendingReviewErrors
          : store.errors.toList(growable: false);
    }
    final filtered = store.errors
        .where((item) => selected.contains(item.subject))
        .toList(growable: false);
    return filtered.isNotEmpty
        ? filtered
        : store.errors.toList(growable: false);
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
        child: _buildConfigForm(subjects),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: _quizBottomBar,
          border: Border(
            top: BorderSide(
              color: AppPalette.inkBlue.withOpacity(0.08),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppPalette.inkBlue.withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startGenerate,
            icon: const Icon(Icons.auto_awesome, color: _quizAccent),
            label: const Text(
              '开始生成专属试卷',
              style: TextStyle(
                color: _quizAccent,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _quizActionButton,
              foregroundColor: _quizAccent,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              side: BorderSide(color: _quizAccent.withOpacity(0.16)),
              elevation: 0,
            ),
          ),
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
            iconBackgroundColor: _quizAccentSoft,
            iconColor: _quizAccent,
          ),
          const SizedBox(height: 16),
          AppPanel(
            color: _quizPanel,
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
                        color: _quizAccent,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _quizAccent,
                    inactiveTrackColor: _quizAccentSoft,
                    thumbColor: _quizAccent,
                    overlayColor: _quizAccent.withOpacity(0.10),
                    valueIndicatorColor: _quizAccent,
                  ),
                  child: Slider(
                    value: _questionCount.toDouble(),
                    min: 5,
                    max: 50,
                    divisions: 9,
                    label: '$_questionCount',
                    onChanged: (value) {
                      setState(() => _questionCount = value.toInt());
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const AppSectionTitle(
            title: '选择范围',
            subtitle: '可以多选，也可以直接覆盖全部学科',
            icon: Icons.category_rounded,
            iconBackgroundColor: _quizMintSoft,
            iconColor: _quizMint,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: subjects.asMap().entries.map((entry) {
              final subjectIndex = entry.key;
              final subject = entry.value;
              final isSelected = _selectedSubjects.contains(subject);
              final tint = _subjectTint(subjectIndex);
              final softTint = _subjectSoftTint(subjectIndex);
              return FilterChip(
                label: Text(subject),
                selected: isSelected,
                selectedColor: softTint,
                backgroundColor:
                    subjectIndex.isEven ? _quizPanelSoft : softTint,
                checkmarkColor: tint,
                labelStyle: TextStyle(
                  color: isSelected ? tint : AppPalette.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                side: BorderSide(
                  color: isSelected
                      ? tint.withOpacity(0.26)
                      : AppPalette.inkBlue.withOpacity(0.08),
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
            iconBackgroundColor: _quizVioletSoft,
            iconColor: _quizViolet,
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
    final tint = _strategyTint(index);
    final softTint = _strategySoftTint(index);
    return InkWell(
      onTap: () => setState(() => _selectedStrategy = index),
      borderRadius: BorderRadius.circular(22),
      child: AppPanel(
        color: isSelected ? softTint : _quizPanel,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? tint : softTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : tint,
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
              color:
                  isSelected ? tint : AppPalette.textSecondary.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  Color _subjectTint(int index) {
    return _subjectTints[index % _subjectTints.length];
  }

  Color _subjectSoftTint(int index) {
    return _subjectSoftTints[index % _subjectSoftTints.length];
  }

  Color _strategyTint(int index) {
    return _strategyTints[index % _strategyTints.length];
  }

  Color _strategySoftTint(int index) {
    return _strategySoftTints[index % _strategySoftTints.length];
  }
}
