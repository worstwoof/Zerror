import 'package:flutter/material.dart';

class DataDashboardScreen extends StatefulWidget {
  const DataDashboardScreen({super.key});

  @override
  State<DataDashboardScreen> createState() => _DataDashboardScreenState();
}

class _DataDashboardScreenState extends State<DataDashboardScreen> {
  final Color primaryGreen = const Color(0xFF70A88D);

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
          '学习数据看板',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 顶部 AI 洞察提示语
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryGreen.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: primaryGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI 洞察：本周你在「数据结构与算法」上的正确率提升了 15%，继续保持！',
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 2. 核心数据概览
            Text('学习概况', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildOverviewCard('收录错题', '342', cardColor, textColor, subTextColor),
                const SizedBox(width: 16),
                _buildOverviewCard('成功消灭', '215', cardColor, primaryGreen, subTextColor), // 突出显示的绿色
              ],
            ),
            const SizedBox(height: 32),

            // 3. 活跃度柱状图 (原生手写柱状图)
            Text('本周复习活跃度', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildBarChartItem('一', 0.4, primaryGreen, subTextColor),
                      _buildBarChartItem('二', 0.7, primaryGreen, subTextColor),
                      _buildBarChartItem('三', 0.3, primaryGreen, subTextColor),
                      _buildBarChartItem('四', 0.9, primaryGreen, subTextColor),
                      _buildBarChartItem('五', 0.6, primaryGreen, subTextColor),
                      _buildBarChartItem('六', 0.2, primaryGreen.withOpacity(0.5), subTextColor),
                      _buildBarChartItem('日', 0.8, primaryGreen, subTextColor),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 4. 学科薄弱点分析 (横向进度条)
            Text('错题知识点分布', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _buildSubjectProgress('线性代数', 0.75, '75 题', textColor, subTextColor),
                  const SizedBox(height: 20),
                  _buildSubjectProgress('数据结构与算法', 0.45, '45 题', textColor, subTextColor),
                  const SizedBox(height: 20),
                  _buildSubjectProgress('Java 核心编程', 0.20, '20 题', textColor, subTextColor),
                  const SizedBox(height: 20),
                  _buildSubjectProgress('其他', 0.10, '10 题', textColor, subTextColor),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 组件：顶部概览卡片
  Widget _buildOverviewCard(String title, String value, Color bgColor, Color valueColor, Color titleColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: titleColor, fontSize: 13)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: valueColor, fontSize: 32, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // 组件：竖向柱状图 (本周活跃度)
  Widget _buildBarChartItem(String label, double fillRatio, Color barColor, Color labelColor) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 120, // 柱子的最大高度
          decoration: BoxDecoration(
            color: labelColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: fillRatio, // 根据比例填充高度
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: TextStyle(color: labelColor, fontSize: 12)),
      ],
    );
  }

  // 组件：横向进度条 (学科分布)
  Widget _buildSubjectProgress(String subject, double ratio, String count, Color textColor, Color subTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(subject, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
            Text(count, style: TextStyle(color: subTextColor, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: subTextColor.withOpacity(0.1),
            color: primaryGreen,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}