import 'package:flutter/material.dart';

import '../../core/app_ui.dart';
import '../../core/theme.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['全部', '线性代数', '数据结构', 'Java', '考研政治'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppPalette.textPrimary),
        title: const Text('错题回收站', style: TextStyle(color: AppPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.delete_sweep_rounded, color: AppPalette.textPrimary), onPressed: () {}),
        ],
      ),
      body: AppSurface(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionTitle(
              title: '临时回收区',
              subtitle: '筛选近期移出的题目，必要时恢复训练',
              icon: Icons.restore_from_trash_rounded,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_filters.length, (index) {
                  final isSelected = _selectedFilterIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ChoiceChip(
                      label: Text(_filters[index]),
                      selected: isSelected,
                      selectedColor: AppPalette.matchaMist,
                      backgroundColor: AppPalette.pastelGrey.withValues(alpha: 0.08),
                      labelStyle: TextStyle(
                        color: isSelected ? AppPalette.night : AppPalette.textSecondary,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                      ),
                      side: BorderSide.none,
                      onSelected: (_) => setState(() => _selectedFilterIndex = index),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: const [
                  _RecycleCard(subject: '线性代数', date: '2026-04-01', difficulty: 4, question: '设矩阵 A 的特征值为 λ1, λ2, λ3，且 A 可逆，求 A* 的特征值。'),
                  _RecycleCard(subject: '数据结构', date: '2026-03-28', difficulty: 3, question: '已知一棵二叉树的前序与中序遍历序列，画出原二叉树。'),
                  _RecycleCard(subject: 'Java', date: '2026-03-25', difficulty: 5, question: '解释 JVM 中垃圾回收机制的分代回收原理。'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecycleCard extends StatelessWidget {
  const _RecycleCard({
    required this.subject,
    required this.date,
    required this.difficulty,
    required this.question,
  });

  final String subject;
  final String date;
  final int difficulty;
  final String question;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppPalette.matchaMist.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(subject, style: const TextStyle(color: AppPalette.matchaMist, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                Text(date, style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 14),
            Text(question, style: const TextStyle(color: AppPalette.textPrimary, fontSize: 15, height: 1.6)),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < difficulty ? Icons.star_rounded : Icons.star_border_rounded,
                      color: index < difficulty ? AppPalette.almondCream : AppPalette.textSecondary.withValues(alpha: 0.3),
                      size: 16,
                    ),
                  ),
                ),
                Row(
                  children: [
                    TextButton(onPressed: () {}, child: const Text('彻底移除', style: TextStyle(color: Color(0xFFE17D6B)))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.matchaMist,
                        foregroundColor: AppPalette.night,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('去复习', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
