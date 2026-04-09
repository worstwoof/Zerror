import 'package:flutter/material.dart';
import 'level_practice_screen.dart';
import 'advanced_challenge_screen.dart';
import 'final_exam_screen.dart';
import 'level_one_screen.dart';
class WeaknessPracticeScreen extends StatefulWidget {
  const WeaknessPracticeScreen({super.key});

  @override
  State<WeaknessPracticeScreen> createState() => _WeaknessPracticeScreenState();
}

class _WeaknessPracticeScreenState extends State<WeaknessPracticeScreen> {
  final Color bgDark = const Color(0xFF1E2823);
  final Color primaryGreen = const Color(0xFF70A88D);
  final Color cardBg = const Color(0xFF2A352F);
  final Color currentTextColor = Colors.white;

  // 🌟 核心引擎：记录当前激活的关卡（1表示第一关，以此类推）
  // 假设用户已经做完了第1关，现在进度在第2关
  // 🌟 核心引擎：记录当前激活的关卡（改为从第 1 关开始）
  int _currentActiveLevel = 1;

  // 🌟 核心逻辑：处理底部按钮的点击与跳转
  void _startCurrentLevel() async {
    if (_currentActiveLevel > 4) return; // 已经全部通关

    Widget nextScreen;
    switch (_currentActiveLevel) {
      case 1: // 🌟 必须加上 case 1，否则点击没反应
        nextScreen = const LevelOneScreen();
        break;
      case 2:
        nextScreen = const LevelPracticeScreen();
        break;
      case 3:
        nextScreen = const AdvancedChallengeScreen();
        break;
      case 4:
        nextScreen = const FinalExamScreen();
        break;
      default:
        return;
    }

    // 🌟 等待目标页面返回结果
    // 当做题页面调用 Navigator.pop(context, true) 时，result 就会是 true
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );

    // 如果接收到了闯关成功的信号，关卡+1，刷新页面！
    if (result == true) {
      setState(() {
        _currentActiveLevel++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('攻克薄弱点', style: TextStyle(color: currentTextColor, fontSize: 18, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: currentTextColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/auth_bg.png', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.35)),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _buildAiDiagnosisCard(),
                  const SizedBox(height: 40),

                  Row(
                    children: [
                      Icon(Icons.route_rounded, color: primaryGreen, size: 22),
                      const SizedBox(width: 8),
                      Text('专属突破计划', style: TextStyle(color: currentTextColor, fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 🌟 只需要传入关卡编号，UI 会根据 _currentActiveLevel 自动推导状态
                  _buildPracticeNode(
                    level: 1,
                    title: '概念扫盲：什么是特征值？',
                    subtitle: '3 分钟 AI 动画解析 + 2 道基础判断题',
                    icon: Icons.play_circle_fill_rounded,
                  ),
                  _buildPracticeNode(
                    level: 2,
                    title: '基础演练：特征多项式计算',
                    subtitle: '5 道针对性错题变式，主要攻克计算粗心',
                    icon: Icons.edit_document,
                  ),
                  _buildPracticeNode(
                    level: 3,
                    title: '进阶挑战：伴随矩阵与特征值',
                    subtitle: '3 道压轴大题，融合多个知识点',
                    icon: Icons.workspace_premium_rounded,
                  ),
                  _buildPracticeNode(
                    level: 4,
                    title: '终极测试：线性代数综合卷',
                    subtitle: '全真模拟，检验学习闭环',
                    icon: Icons.flag_rounded,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // 🌟 动态底部按钮
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: bgDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, -5)),
          ],
        ),
        child: ElevatedButton.icon(
          // 如果超过4关，按钮置灰（传null）
          onPressed: _currentActiveLevel > 4 ? null : _startCurrentLevel,
          icon: Icon(_currentActiveLevel > 4 ? Icons.verified_rounded : Icons.bolt_rounded, color: Colors.white),
          label: Text(
              _currentActiveLevel > 4 ? '特训已全部完成' : '挑战第 0$_currentActiveLevel 关',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            disabledBackgroundColor: primaryGreen.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildAiDiagnosisCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: primaryGreen.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(Icons.psychology_rounded, color: primaryGreen, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('知芽 AI 诊断', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('目标靶向：线性代数 - 矩阵特征值', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Zerror，分析你近两周的 12 道错题发现，你在「矩阵特征值的求解」上丢分率高达 65%。主要问题在于特征多项式的计算展开容易出错。我为你定制了包含 4 个阶段的突破训练。',
            style: TextStyle(color: Colors.white, fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }

  // 🌟 动态节点生成器：所有的 UI 状态全部通过 level 和 _currentActiveLevel 动态计算得出！
  Widget _buildPracticeNode({
    required int level,
    required String title,
    required String subtitle,
    required IconData icon,
    bool isLast = false,
  }) {
    // 逻辑判定核心
    final bool isCompleted = level < _currentActiveLevel;
    final bool isActive = level == _currentActiveLevel;
    final bool isLocked = level > _currentActiveLevel;

    final String indexStr = '0$level';

    final Color nodeColor = isCompleted ? primaryGreen : (isActive ? primaryGreen : Colors.white.withValues(alpha: 0.2));
    final Color textColor = isLocked ? Colors.white.withValues(alpha: 0.4) : Colors.white;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isActive ? primaryGreen.withValues(alpha: 0.2) : (isCompleted ? primaryGreen : cardBg),
                  shape: BoxShape.circle,
                  border: Border.all(color: nodeColor, width: isActive ? 2 : 1),
                ),
                child: Center(
                  child: isCompleted // 完成的变成打勾
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                      : Text(indexStr, style: TextStyle(color: nodeColor, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isCompleted ? primaryGreen : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isActive ? primaryGreen.withValues(alpha: 0.1) : cardBg.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isActive ? primaryGreen.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(subtitle, style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 完成变成勾号，锁定变成锁头，激活展示原始图标
                  Icon(isCompleted ? Icons.check_circle_rounded : (isLocked ? Icons.lock_outline_rounded : icon), color: nodeColor, size: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}