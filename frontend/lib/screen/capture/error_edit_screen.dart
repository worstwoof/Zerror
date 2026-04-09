import 'dart:io';
import 'package:flutter/material.dart';

class ErrorEditScreen extends StatefulWidget {
  final String imagePath;
  final String initialText;

  const ErrorEditScreen({super.key, required this.imagePath, required this.initialText});

  @override
  State<ErrorEditScreen> createState() => _ErrorEditScreenState();
}

class _ErrorEditScreenState extends State<ErrorEditScreen> {
  final Color primaryGreen = const Color(0xFF70A88D);
  late TextEditingController _questionController;
  late TextEditingController _reflectionController;

  bool _isAiThinking = true; // 控制 AI 分析的加载状态
  bool _showSimilarQuestions = false; // 控制是否显示举一反三
  String _selectedErrorReason = ''; // 记录选中的错因

  final List<String> _errorReasons = ['粗心大意', '概念模糊', '公式遗忘', '思路断裂', '计算错误'];

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.initialText);
    _reflectionController = TextEditingController();
    _simulateAiAnalysis(); // 进入页面即开始模拟 AI 深度分析
  }

  // 模拟 AI 深度思考的过程
  Future<void> _simulateAiAnalysis() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() { _isAiThinking = false; });
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _reflectionController.dispose();
    super.dispose();
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
        title: Text('知芽 AI 解析', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: _isAiThinking
          ? _buildLoadingState(textColor)
          : _buildAnalysisDashboard(textColor, cardColor, isDarkMode),

      // 底部悬浮的保存按钮
      bottomNavigationBar: _isAiThinking ? null : Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bgColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: const Text('🎉 错题已入库！知芽会在最佳遗忘点提醒你复习。'), backgroundColor: primaryGreen),
            );
            Navigator.pop(context); // 返回主页
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('生成我的错题档案', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // ================= 模块 0：加载状态 =================
  Widget _buildLoadingState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryGreen),
          const SizedBox(height: 24),
          Text('知芽 AI 正在深度剖析题目...', style: TextStyle(color: textColor, fontSize: 16)),
          const SizedBox(height: 8),
          Text('正在生成解答、归类知识点与拓展练习', style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 13)),
        ],
      ),
    );
  }

  // ================= 主面板 =================
  Widget _buildAnalysisDashboard(Color textColor, Color cardColor, bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 原题与 AI 标签
          _buildOriginalQuestionCard(textColor, cardColor),
          const SizedBox(height: 20),

          // 2. AI 核心解析区
          _buildAiSolutionCard(textColor, cardColor),
          const SizedBox(height: 20),

          // 3. 举一反三区
          _buildSimilarQuestionsArea(textColor, cardColor),
          const SizedBox(height: 20),

          // 4. 用户反思区 (做错原因)
          _buildUserReflectionCard(textColor, cardColor),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ================= 模块 1：原题与标签 =================
  Widget _buildOriginalQuestionCard(Color textColor, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(widget.imagePath), width: 50, height: 50, fit: BoxFit.cover)),
              const SizedBox(width: 12),
              // AI 自动生成的标签
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: const Text('线性代数', style: TextStyle(fontSize: 12)), backgroundColor: primaryGreen.withOpacity(0.1), side: BorderSide.none),
                    Chip(label: const Text('矩阵特征值', style: TextStyle(fontSize: 12)), backgroundColor: primaryGreen.withOpacity(0.1), side: BorderSide.none),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _questionController,
            maxLines: null,
            style: TextStyle(color: textColor, fontSize: 15),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
          ),
        ],
      ),
    );
  }

  // ================= 模块 2：AI 深度解析 =================
  Widget _buildAiSolutionCard(Color textColor, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text('AI 独家解析', style: TextStyle(color: primaryGreen, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          // 模拟视频讲解按钮
          InkWell(
            onTap: () { /* TODO: 播放音视频讲解 */ },
            child: Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36),
                  SizedBox(width: 12),
                  Text('播放 AI 动态板书讲解 (02:15)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 解题思路总结
          Text('💡 破题技巧', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('伴随矩阵 A* 的特征值与原矩阵 A 的特征值关系是：λ* = |A| / λ。遇到此类问题，优先联想定义式 A*A = |A|E。',
              style: TextStyle(color: textColor.withOpacity(0.8), height: 1.5, fontSize: 14)),
          const SizedBox(height: 12),
          const Divider(),
          // 详细步骤 (这里用 ExpansionTile 折叠，避免太长)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text('查看详细推导步骤', style: TextStyle(color: primaryGreen, fontSize: 14)),
              tilePadding: EdgeInsets.zero,
              children: [
                Text('1. 根据定义：A* = |A| · A⁻¹\n2. 若 A 对应特征值为 λ，则 A⁻¹ 的特征值为 1/λ\n3. 因此 A* 的特征值为 |A|/λ',
                    style: TextStyle(color: textColor.withOpacity(0.8), height: 1.6)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ================= 模块 3：举一反三 =================
  Widget _buildSimilarQuestionsArea(Color textColor, Color cardColor) {
    if (!_showSimilarQuestions) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => setState(() => _showSimilarQuestions = true),
          icon: Icon(Icons.hub_rounded, color: primaryGreen),
          label: Text('生成举一反三练习 (2题)', style: TextStyle(color: primaryGreen)),
          style: OutlinedButton.styleFrom(
              side: BorderSide(color: primaryGreen),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.explore_rounded, color: Colors.orange.shade400, size: 20),
              const SizedBox(width: 8),
              Text('举一反三', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text('练习 1：设三阶矩阵 A 的特征值为 1, 2, -1，求 |A*| 的值。', style: TextStyle(color: textColor.withOpacity(0.9), fontSize: 14)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: (){}, child: Text('查看 AI 答案', style: TextStyle(color: primaryGreen, fontSize: 13))),
          )
        ],
      ),
    );
  }

  // ================= 模块 4：自我复盘 =================
  Widget _buildUserReflectionCard(Color textColor, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🎯 自我复盘', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text('这次为什么做错了？', style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _errorReasons.map((reason) {
              final isSelected = _selectedErrorReason == reason;
              return ChoiceChip(
                label: Text(reason),
                selected: isSelected,
                selectedColor: primaryGreen,
                backgroundColor: textColor.withOpacity(0.05),
                labelStyle: TextStyle(color: isSelected ? Colors.white : textColor, fontSize: 13),
                side: BorderSide.none,
                onSelected: (bool selected) {
                  if (selected) setState(() => _selectedErrorReason = reason);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reflectionController,
            maxLines: 3,
            style: TextStyle(color: textColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: '写下你的避坑笔记...',
              hintStyle: TextStyle(color: textColor.withOpacity(0.3)),
              filled: true,
              fillColor: textColor.withOpacity(0.03),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }
}