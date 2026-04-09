import 'package:flutter/material.dart';
import 'error_detail_screen.dart'; // 🌟 引入刚写的详情页
class ErrorArchiveScreen extends StatefulWidget {
  const ErrorArchiveScreen({super.key});

  @override
  State<ErrorArchiveScreen> createState() => _ErrorArchiveScreenState();
}

class _ErrorArchiveScreenState extends State<ErrorArchiveScreen> {
  final Color primaryGreen = const Color(0xFF70A88D);
  String _selectedSubject = '全部'; // 当前选中的分类

  final List<String> _subjects = ['全部', '线性代数', 'Java', '数据结构', '考研政治'];

  // 模拟的错题数据库
  final List<Map<String, dynamic>> _errorDatabase = [
    {
      'subject': '线性代数',
      'topic': '矩阵特征值与对角化',
      'question': '设矩阵 A 的特征值为 λ1, λ2, λ3，且 A 可逆。求证：A 的伴随矩阵 A* 的特征值为 |A|/λ。',
      'reason': '概念模糊',
      'date': '今天 14:30',
      'isMastered': false,
    },
    {
      'subject': '数据结构',
      'topic': 'KMP 算法实现',
      'question': '在 C++ 中编写 KMP 模式匹配算法时，求 next 数组的推导过程。',
      'reason': '边界遗漏',
      'date': '昨天 20:15',
      'isMastered': true,
    },
    {
      'subject': 'Java',
      'topic': '面向对象与多态',
      'question': '在 3D 彩票模拟系统中，如何使用接口（Interface）统一管理不同的抽奖策略？',
      'reason': '思路断裂',
      'date': '3月26日',
      'isMastered': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1E2823) : const Color(0xFFF0F4F2);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2C362F);
    final cardColor = isDarkMode ? Colors.white12 : Colors.white;

    // 根据选中的标签过滤数据
    final filteredList = _selectedSubject == '全部'
        ? _errorDatabase
        : _errorDatabase.where((item) => item['subject'] == _selectedSubject).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
        title: Text('错题档案', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.search_rounded), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // 1. 顶部统计面板
          _buildStatsHeader(textColor, cardColor),

          // 2. 标签过滤器 (横向滑动)
          _buildSubjectFilter(textColor, cardColor),

          // 3. 错题列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final item = filteredList[index];
                return _buildErrorCard(item, textColor, cardColor);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============== 模块：顶部统计 ==============
  Widget _buildStatsHeader(Color textColor, Color cardColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: primaryGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('累计收录', '128', Colors.white),
            Container(width: 1, height: 40, color: Colors.white24),
            _buildStatItem('待复习', '15', Colors.orange.shade300),
            Container(width: 1, height: 40, color: Colors.white24),
            _buildStatItem('已掌握', '86', Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: valueColor, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  // ============== 模块：学科过滤器 ==============
  Widget _buildSubjectFilter(Color textColor, Color cardColor) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _subjects.length,
        itemBuilder: (context, index) {
          final subject = _subjects[index];
          final isSelected = _selectedSubject == subject;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(subject),
              selected: isSelected,
              selectedColor: primaryGreen,
              backgroundColor: cardColor,
              labelStyle: TextStyle(color: isSelected ? Colors.white : textColor.withOpacity(0.7), fontSize: 13),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (selected) {
                if (selected) setState(() => _selectedSubject = subject);
              },
            ),
          );
        },
      ),
    );
  }

  // ============== 模块：错题卡片 ==============
  // ============== 模块：错题卡片 ==============
  Widget _buildErrorCard(Map<String, dynamic> item, Color textColor, Color cardColor) {
    final bool isMastered = item['isMastered'];

    // 🌟 重点修改：用 Material 和 InkWell 包裹，提供原生水波纹点击体验
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent, // 保持透明，让里面的 Ink 回显颜色
        child: Ink(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: isMastered ? Border.all(color: primaryGreen.withOpacity(0.3), width: 1) : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              // 🌟 重点修改：点击跳转到详情页，并把这道题的 item 数据全部传过去
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ErrorDetailScreen(errorData: item),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 卡片头部：学科标签 + 状态
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text(item['subject'], style: TextStyle(color: primaryGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text(item['topic'], style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12)),
                        ],
                      ),
                      if (isMastered)
                        Icon(Icons.check_circle_rounded, color: primaryGreen, size: 18)
                      else
                        Text(item['date'], style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 题目正文
                  Text(
                    item['question'],
                    style: TextStyle(color: textColor, fontSize: 15, height: 1.5, fontWeight: FontWeight.w500),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),

                  // 卡片底部：错因 + 按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.flag_rounded, color: Colors.redAccent.withOpacity(0.7), size: 14),
                          const SizedBox(width: 4),
                          Text('错因: ${item['reason']}', style: TextStyle(color: Colors.redAccent.withOpacity(0.7), fontSize: 12)),
                        ],
                      ),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          onPressed: () {
                            // 这里也可以执行跳转，或者保留原样，因为外层的 InkWell 已经接管了点击事件
                            Navigator.push(context, MaterialPageRoute(builder: (context) => ErrorDetailScreen(errorData: item)));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMastered ? Colors.transparent : primaryGreen,
                            elevation: 0,
                            side: isMastered ? BorderSide(color: primaryGreen) : BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Text(
                              isMastered ? '再看一眼' : '开始复习',
                              style: TextStyle(color: isMastered ? primaryGreen : Colors.white, fontSize: 12, fontWeight: FontWeight.bold)
                          ),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}