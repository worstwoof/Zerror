import 'dart:math' as math;

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
  static const int _lastStep = 4;
  static const String _allSubjects = '全部学科';

  int _step = 0;
  int _selectedPurpose = 0;
  int _questionCount = 12;
  String _selectedSubject = _allSubjects;
  final Set<String> _selectedTopics = <String>{};
  final Set<String> _selectedTypeTags = <String>{};

  static const Color _panel = Colors.white;
  static const Color _panelSoft = Color(0xFFF6F9FF);
  static const Color _accent = Color(0xFF38558F);
  static const Color _accentSoft = Color(0xFFE7ECF6);
  static const Color _mint = Color(0xFF3E8F7A);
  static const Color _mintSoft = Color(0xFFE5F6F1);
  static const Color _coral = Color(0xFFC86D63);
  static const Color _coralSoft = Color(0xFFFFEFEC);
  static const Color _violet = Color(0xFF7662B8);
  static const Color _violetSoft = Color(0xFFF0ECFF);
  static const Color _bottomBar = Color(0xFFF8FBFF);
  static const Color _actionButton = Color(0xFFE7F3FF);

  static const List<({String title, String subtitle, IconData icon})>
      _purposes = [
    (
      title: '错题回炉卷',
      subtitle: '只整理你自己的错题，题量范围由筛选结果决定',
      icon: Icons.history_edu_rounded,
    ),
    (
      title: '同类强化卷',
      subtitle: '根据错题生成同类新题，可自定义题量',
      icon: Icons.auto_awesome_rounded,
    ),
    (
      title: '混合提升卷',
      subtitle: '用原错题作参照，再生成迁移训练题',
      icon: Icons.hub_rounded,
    ),
  ];

  bool get _isSourceOnly => _selectedPurpose == 0;

  void _goNext(AppStore store) {
    if (_step < _lastStep) {
      setState(() => _step += 1);
      return;
    }
    _startGenerate(store);
  }

  void _goBack() {
    if (_step == 0) return;
    setState(() => _step -= 1);
  }

  void _startGenerate(AppStore store) {
    final sourceErrors = _filteredErrors(store);
    if (sourceErrors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前筛选范围没有可用于组卷的错题')),
      );
      return;
    }

    final count = _effectiveQuestionCount(sourceErrors.length);
    store.enqueuePracticePaperTask(
      sourceErrors: sourceErrors,
      questionCount: count,
      selectedSubjects: _selectedSubject == _allSubjects
          ? [_allSubjects]
          : [_selectedSubject],
      selectedTopics: _selectedTopics.toList(growable: false),
      selectedTypeTags: _selectedTypeTags.toList(growable: false),
      strategyLabel: _purposes[_selectedPurpose].title,
      generationMode: _purposes[_selectedPurpose].title,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('智能组卷已放到后台，回首页右上角查看进度')),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final sourceCount = _filteredErrors(store).length;
    final canGenerate = sourceCount > 0;

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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _progressHeader(),
              const SizedBox(height: 18),
              _stepContent(store),
              const SizedBox(height: 24),
              _summaryStrip(sourceCount),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _bottomActions(store, canGenerate),
    );
  }

  Widget _progressHeader() {
    return AppPanel(
      color: _panel,
      padding: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Row(
        children: List.generate(_lastStep + 1, (index) {
          final active = index <= _step;
          return Expanded(
            child: Container(
              height: 6,
              margin: EdgeInsets.only(right: index == _lastStep ? 0 : 6),
              decoration: BoxDecoration(
                color: active ? _accent : _accentSoft,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _stepContent(AppStore store) {
    switch (_step) {
      case 0:
        return _purposeStep();
      case 1:
        return _subjectStep(store);
      case 2:
        return _topicStep(store);
      case 3:
        return _typeStep(store);
      default:
        return _countStep(store);
    }
  }

  Widget _purposeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionTitle(
          title: '复习目的',
          subtitle: '先决定这份卷子要解决什么问题',
          icon: Icons.flag_rounded,
          iconBackgroundColor: _accentSoft,
          iconColor: _accent,
        ),
        const SizedBox(height: 14),
        ...List.generate(_purposes.length, (index) {
          final item = _purposes[index];
          final selected = _selectedPurpose == index;
          return Padding(
            padding:
                EdgeInsets.only(bottom: index == _purposes.length - 1 ? 0 : 12),
            child: _choiceTile(
              title: item.title,
              subtitle: item.subtitle,
              icon: item.icon,
              selected: selected,
              tint: _purposeTint(index),
              softTint: _purposeSoftTint(index),
              onTap: () => setState(() {
                _selectedPurpose = index;
                _questionCount = _isSourceOnly ? 8 : 12;
              }),
            ),
          );
        }),
      ],
    );
  }

  Widget _subjectStep(AppStore store) {
    final options = _subjectOptions(store);
    return _optionStep(
      title: '选择学科',
      subtitle: '后面的知识点和题型会跟着学科变化',
      icon: Icons.category_rounded,
      tint: _mint,
      softTint: _mintSoft,
      children: options.map((option) {
        return _statTile(
          label: option.label,
          count: option.count,
          selected: _selectedSubject == option.label,
          tint: _mint,
          onTap: () => setState(() {
            _selectedSubject = option.label;
            _selectedTopics.clear();
            _selectedTypeTags.clear();
          }),
        );
      }).toList(growable: false),
    );
  }

  Widget _topicStep(AppStore store) {
    final options = _topicOptions(store);
    return _optionStep(
      title: '选择知识点',
      subtitle: '不选则覆盖当前学科下的全部知识点',
      icon: Icons.account_tree_rounded,
      tint: _violet,
      softTint: _violetSoft,
      trailing: _miniTextButton(
        label: _selectedTopics.isEmpty ? '已选全部' : '清空',
        onTap: () => setState(_selectedTopics.clear),
      ),
      children: options.map((option) {
        return _statTile(
          label: option.label,
          count: option.count,
          selected: _selectedTopics.contains(option.label),
          tint: _violet,
          onTap: () => setState(() {
            if (!_selectedTopics.add(option.label)) {
              _selectedTopics.remove(option.label);
            }
            _selectedTypeTags.clear();
          }),
        );
      }).toList(growable: false),
      emptyText: '当前范围还没有明确知识点，会按全部错题继续。',
    );
  }

  Widget _typeStep(AppStore store) {
    final options = _typeOptions(store);
    return _optionStep(
      title: '选择题型',
      subtitle: '这里展示的是当前错题里真实出现过的题型',
      icon: Icons.schema_rounded,
      tint: _coral,
      softTint: _coralSoft,
      trailing: _miniTextButton(
        label: _selectedTypeTags.isEmpty ? '已选全部' : '清空',
        onTap: () => setState(_selectedTypeTags.clear),
      ),
      children: options.map((option) {
        return _statTile(
          label: option.label,
          count: option.count,
          selected: _selectedTypeTags.contains(option.label),
          tint: _coral,
          onTap: () => setState(() {
            if (!_selectedTypeTags.add(option.label)) {
              _selectedTypeTags.remove(option.label);
            }
          }),
        );
      }).toList(growable: false),
      emptyText: '当前范围暂无题型标签，会按知识点整体组卷。',
    );
  }

  Widget _countStep(AppStore store) {
    final sourceCount = _filteredErrors(store).length;
    final minCount = _isSourceOnly ? 1 : 3;
    final maxCount = _isSourceOnly ? math.max(1, sourceCount) : 50;
    final value = _effectiveQuestionCount(sourceCount).toDouble();
    final divisions = maxCount > minCount ? maxCount - minCount : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionTitle(
          title: '题量确认',
          subtitle: '最后确认生成范围和练习强度',
          icon: Icons.tune_rounded,
          iconBackgroundColor: _accentSoft,
          iconColor: _accent,
        ),
        const SizedBox(height: 14),
        AppPanel(
          color: _panel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isSourceOnly ? '原错题范围' : '生成题量',
                    style: const TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${value.toInt()} 题',
                    style: const TextStyle(
                      color: _accent,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _isSourceOnly
                    ? '当前筛选出 $sourceCount 道错题，可生成 $minCount-$maxCount 道。'
                    : '当前筛选出 $sourceCount 道参考错题，可生成 3-50 道同类训练。',
                style: const TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 12,
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _accent,
                  inactiveTrackColor: _accentSoft,
                  thumbColor: _accent,
                  overlayColor: _accent.withValues(alpha: 0.10),
                  valueIndicatorColor: _accent,
                ),
                child: Slider(
                  value: value,
                  min: minCount.toDouble(),
                  max: maxCount.toDouble(),
                  divisions: divisions,
                  label: '${value.toInt()}',
                  onChanged: sourceCount == 0
                      ? null
                      : (next) => setState(
                            () => _questionCount = next.round(),
                          ),
                ),
              ),
              if (_isSourceOnly && sourceCount > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: _miniTextButton(
                    label: '使用全部 $sourceCount 道',
                    onTap: () => setState(() => _questionCount = sourceCount),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _optionStep({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color tint,
    required Color softTint,
    required List<Widget> children,
    Widget? trailing,
    String emptyText = '当前没有可选项。',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppSectionTitle(
                title: title,
                subtitle: subtitle,
                icon: icon,
                iconBackgroundColor: softTint,
                iconColor: tint,
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 14),
        if (children.isEmpty)
          AppPanel(
            color: _panel,
            child: Text(
              emptyText,
              style: const TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: children,
          ),
      ],
    );
  }

  Widget _choiceTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required Color tint,
    required Color softTint,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? softTint : _panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? tint.withValues(alpha: 0.32)
                : AppPalette.inkBlue.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? tint : softTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: selected ? Colors.white : tint),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
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
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected
                  ? tint
                  : AppPalette.textSecondary.withValues(alpha: 0.34),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile({
    required String label,
    required int count,
    required bool selected,
    required Color tint,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? tint.withValues(alpha: 0.11) : _panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? tint.withValues(alpha: 0.34)
                : AppPalette.inkBlue.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              size: 18,
              color: selected
                  ? tint
                  : AppPalette.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? tint : AppPalette.textPrimary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              '$count',
              style: const TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniTextButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: _accent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _summaryStrip(int sourceCount) {
    final topics =
        _selectedTopics.isEmpty ? '全部知识点' : _selectedTopics.join(' / ');
    final types =
        _selectedTypeTags.isEmpty ? '全部题型' : _selectedTypeTags.join(' / ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.inkBlue.withValues(alpha: 0.06)),
      ),
      child: Text(
        '${_purposes[_selectedPurpose].title} · $_selectedSubject · $topics · $types · $sourceCount 道参考错题',
        style: const TextStyle(
          color: AppPalette.textSecondary,
          fontSize: 12,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _bottomActions(AppStore store, bool canGenerate) {
    final isLast = _step == _lastStep;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: _bottomBar,
        border: Border(
          top: BorderSide(color: AppPalette.inkBlue.withValues(alpha: 0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.inkBlue.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            IconButton(
              onPressed: _goBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: _accent,
              tooltip: '上一步',
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isLast && !canGenerate ? null : () => _goNext(store),
              icon: Icon(
                isLast
                    ? Icons.auto_awesome_rounded
                    : Icons.arrow_forward_rounded,
                color: _accent,
              ),
              label: Text(
                isLast ? '开始生成专属试卷' : '下一步',
                style: const TextStyle(
                  color: _accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _actionButton,
                foregroundColor: _accent,
                disabledBackgroundColor:
                    AppPalette.textSecondary.withValues(alpha: 0.10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                side: BorderSide(color: _accent.withValues(alpha: 0.16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<ErrorRecord> _baseErrors(AppStore store) {
    return store.pendingReviewErrors.isNotEmpty
        ? store.pendingReviewErrors
        : store.errors.toList(growable: false);
  }

  List<ErrorRecord> _filteredErrors(AppStore store) {
    var items = _baseErrors(store);
    if (_selectedSubject != _allSubjects) {
      items = items
          .where((item) => item.subject == _selectedSubject)
          .toList(growable: false);
    }
    if (_selectedTopics.isNotEmpty) {
      items = items
          .where((item) => _selectedTopics.contains(item.topic))
          .toList(growable: false);
    }
    if (_selectedTypeTags.isNotEmpty) {
      items = items
          .where((item) =>
              _selectedTypeTags.intersection(_typeLabels(item)).isNotEmpty)
          .toList(growable: false);
    }
    return items;
  }

  List<_CountedOption> _subjectOptions(AppStore store) {
    final items = _baseErrors(store);
    final counts = _countBy(
        items, (item) => item.subject.trim().isEmpty ? '未分类' : item.subject);
    return [
      _CountedOption(_allSubjects, items.length),
      ..._sortedOptions(counts),
    ];
  }

  List<_CountedOption> _topicOptions(AppStore store) {
    var items = _baseErrors(store);
    if (_selectedSubject != _allSubjects) {
      items = items
          .where((item) => item.subject == _selectedSubject)
          .toList(growable: false);
    }
    final counts = _countBy(
        items, (item) => item.topic.trim().isEmpty ? '未分类知识点' : item.topic);
    return _sortedOptions(counts);
  }

  List<_CountedOption> _typeOptions(AppStore store) {
    var items = _baseErrors(store);
    if (_selectedSubject != _allSubjects) {
      items = items
          .where((item) => item.subject == _selectedSubject)
          .toList(growable: false);
    }
    if (_selectedTopics.isNotEmpty) {
      items = items
          .where((item) => _selectedTopics.contains(item.topic))
          .toList(growable: false);
    }
    final counts = <String, int>{};
    for (final item in items) {
      final labels = _typeLabels(item);
      for (final label in labels) {
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }
    return _sortedOptions(counts);
  }

  Set<String> _typeLabels(ErrorRecord item) {
    final labels = <String>{
      ...item.effectiveTypeTags,
      if (item.effectiveQuestionFormat.trim().isNotEmpty)
        item.effectiveQuestionFormat,
    };
    labels.removeWhere((item) => item.trim().isEmpty);
    return labels;
  }

  Map<String, int> _countBy(
    Iterable<ErrorRecord> items,
    String Function(ErrorRecord item) keyOf,
  ) {
    final result = <String, int>{};
    for (final item in items) {
      final key = keyOf(item).trim();
      if (key.isEmpty) continue;
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }

  List<_CountedOption> _sortedOptions(Map<String, int> counts) {
    final entries = counts.entries.toList(growable: false)
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return a.key.compareTo(b.key);
      });
    return entries
        .map((entry) => _CountedOption(entry.key, entry.value))
        .toList(growable: false);
  }

  int _effectiveQuestionCount(int sourceCount) {
    if (_isSourceOnly) {
      return _questionCount.clamp(1, math.max(1, sourceCount)).toInt();
    }
    return _questionCount.clamp(3, 50).toInt();
  }

  Color _purposeTint(int index) {
    return const [_accent, _coral, _violet][index % 3];
  }

  Color _purposeSoftTint(int index) {
    return const [_accentSoft, _coralSoft, _violetSoft][index % 3];
  }
}

class _CountedOption {
  const _CountedOption(this.label, this.count);

  final String label;
  final int count;
}
