import 'package:flutter/material.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  final Color primaryGreen = const Color(0xFF70A88D);
  int _selectedFilterIndex = 0; // 当前选中的分类标签索引

  // 模拟的分类标签数据
  final List<String> _filters = ['全部', '线性代数', '数据结构', 'Java', '考研政治'];

  @override
  Widget build(BuildContext context) {
    // 动态主题适配
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1E2823) : const Color(0xFFF0F4F2);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2C362F);
    final subTextColor = isDarkMode ? Colors.white70 : Colors.black54;
    final cardColor = isDarkMode ? Colors.white12 : Colors.black.withOpacity(0.05);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          '错题回收站',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_sweep_rounded, color: textColor),
            tooltip: '清空回收站',
            onPressed: () {
              // TODO: 清空确认弹窗
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 横向滑动的分类标签
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Row(
              children: List.generate(_filters.length, (index) {
                final isSelected = _selectedFilterIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: GestureDetector(
                    onTap: () {
                      setState(() { _selectedFilterIndex = index; });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryGreen : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? primaryGreen : subTextColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _filters[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : subTextColor,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),

          // 2. 错题卡片列表
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              children: [
                _buildErrorCard(
                  subject: '线性代数',
                  question: '设矩阵 A 的特征值为 λ1, λ2, λ3，且 A 可逆，求 A* 的特征值。',
                  date: '2026-04-01',
                  difficulty: 4,
                  cardColor: cardColor,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _buildErrorCard(
                  subject: '数据结构',
                  question: '已知一棵二叉树的前序遍历序列为 ABCDEF，中序遍历序列为 CBAEDF，请画出这棵二叉树。',
                  date: '2026-03-28',
                  difficulty: 3,
                  cardColor: cardColor,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                _buildErrorCard(
                  subject: 'Java',
                  question: '详细解释 JVM 中垃圾回收机制（GC）的分代收集算法原理，以及新生代和老年代的区别。',
                  date: '2026-03-25',
                  difficulty: 5,
                  cardColor: cardColor,
                  textColor: textColor,
                  subTextColor: subTextColor,
                ),
                const SizedBox(height: 40), // 底部留白
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 组件：单条错题卡片
  Widget _buildErrorCard({
    required String subject,
    required String question,
    required String date,
    required int difficulty,
    required Color cardColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：学科标签和日期
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  subject,
                  style: TextStyle(color: primaryGreen, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              Text(date, style: TextStyle(color: subTextColor, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),

          // 中间：题目截取内容
          Text(
            question,
            style: TextStyle(color: textColor, fontSize: 15, height: 1.6),
            maxLines: 3, // 最多显示3行
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),

          // 底部：难度星星和操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 难度星星展示
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < difficulty ? Icons.star_rounded : Icons.star_border_rounded,
                    color: index < difficulty ? Colors.amber : subTextColor.withOpacity(0.3),
                    size: 16,
                  );
                }),
              ),

              // 动作按钮
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      // TODO: 移除错题
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('彻底移除', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      // TODO: 跳转到复习/详情页
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('去复习', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}