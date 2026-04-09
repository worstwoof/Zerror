import 'package:flutter/material.dart';

class ErrorDetailScreen extends StatefulWidget {
  final Map<String, dynamic> errorData; // 接收从上一页传来的该题目的全部数据

  const ErrorDetailScreen({super.key, required this.errorData});

  @override
  State<ErrorDetailScreen> createState() => _ErrorDetailScreenState();
}

class _ErrorDetailScreenState extends State<ErrorDetailScreen> {
  final Color primaryGreen = const Color(0xFF70A88D);
  late bool _isMastered;

  @override
  void initState() {
    super.initState();
    _isMastered = widget.errorData['isMastered'] ?? false;
  }

  // 模拟不同学科的 AI 专属解析内容 (基于传入的卡片数据动态生成)
  String _getAiAnalysis(String subject) {
    if (subject.contains('数据结构')) {
      return '💡 核心剖析：\n在 C++ 实现 KMP 模式匹配算法时，next 数组的本质是寻找“最长相等前后缀”。\n\n⚠️ 易错点预警：\n你标注的错因是“边界遗漏”。请注意，当发生失配时，模式串指针回溯逻辑通常是 `while (j > 0 && s[i] != p[j]) j = next[j - 1];`。下标越界和未处理 `j == 0` 的情况是导致段错误的罪魁祸首。';
    } else if (subject.contains('线性代数')) {
      return '💡 核心剖析：\n遇到伴随矩阵的特征值问题，直接利用核心公式：A* = |A|A⁻¹。\n\n📚 推导逻辑：\n1. 若 A 的特征值为 λ，则 A⁻¹ 的特征值为 1/λ。\n2. 根据数乘矩阵的特征值性质，A* 的特征值即为 |A| × (1/λ) = |A|/λ。';
    } else if (subject.contains('Java')) {
      return '💡 核心剖析：\n在 3D 彩票模拟中，抽奖策略（如双色球、大乐透）各不相同。使用 Interface（如定义 `LotteryStrategy` 接口并包含 `draw()` 方法）可以让系统遵循“开闭原则”。\n只需让不同的具体策略类实现该接口，主程序便可统一调度，彻底解耦。';
    }
    return '💡 核心剖析：\n请仔细梳理题目条件，注意隐含条件的挖掘。结合之前的错因，建议重新审阅相关基础概念。';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1E2823) : const Color(0xFFF0F4F2);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF2C362F);
    final cardColor = isDarkMode ? Colors.white12 : Colors.white;

    final String subject = widget.errorData['subject'];
    final String aiAnalysisText = _getAiAnalysis(subject);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
        title: Text('错题复盘', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: Icon(Icons.share_rounded, color: textColor), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 题目信息头部卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: primaryGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text(subject, style: TextStyle(color: primaryGreen, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      Text(widget.errorData['date'], style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.errorData['question'],
                    style: TextStyle(color: textColor, fontSize: 18, height: 1.6, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. 我的复盘笔记卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.redAccent.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flag_rounded, color: Colors.redAccent.withOpacity(0.8), size: 20),
                      const SizedBox(width: 8),
                      Text('当时错因：${widget.errorData['reason']}', style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. AI 深度解析卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: primaryGreen.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: primaryGreen, size: 20),
                      const SizedBox(width: 8),
                      Text('AI 深度解析', style: TextStyle(color: primaryGreen, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    aiAnalysisText,
                    style: TextStyle(color: textColor.withOpacity(0.9), fontSize: 15, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),

      // 底部操作栏
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Row(
            children: [
              // 掌握状态切换按钮
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _isMastered = !_isMastered);
                    // 实际项目中这里需要同步修改上一页的列表数据并通知后端
                  },
                  icon: Icon(
                    _isMastered ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: _isMastered ? primaryGreen : textColor.withOpacity(0.5),
                  ),
                  label: Text(
                    _isMastered ? '已掌握' : '标为掌握',
                    style: TextStyle(color: _isMastered ? primaryGreen : textColor.withOpacity(0.8)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _isMastered ? primaryGreen : textColor.withOpacity(0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // AI 举一反三按钮
              Expanded(
                flex: 1,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.hub_rounded, size: 20),
                  label: const Text('AI 相似测验', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}