import 'package:flutter/material.dart';

class AdvancedChallengeScreen extends StatefulWidget {
  const AdvancedChallengeScreen({super.key});

  @override
  State<AdvancedChallengeScreen> createState() => _AdvancedChallengeScreenState();
}

class _AdvancedChallengeScreenState extends State<AdvancedChallengeScreen> {
  final Color bgDark = const Color(0xFF1E2823);
  final Color primaryGreen = const Color(0xFF70A88D);
  final Color cardBg = const Color(0xFF2A352F);

  // 模拟压轴大题的数据（多步求解）
  int _currentStep = 0; // 当前解锁到第几步

  final Map<String, dynamic> _bossProblem = {
    'title': '综合大题 1/3：特征值与伴随矩阵的融合',
    'context': '设三阶矩阵 A 的特征值为 λ₁=1, λ₂=-1, λ₃=2。\n矩阵 B = A* - 2E，其中 A* 是 A 的伴随矩阵，E 是单位矩阵。',
    'steps': [
      {
        'question': '第一问：求矩阵 A 的行列式 |A| 的值。',
        'options': ['|A| = 2', '|A| = -2', '|A| = 0', '|A| = -1'],
        'correctIndex': 1,
        'analysis': '行列式的值等于所有特征值的乘积：|A| = 1 × (-1) × 2 = -2。',
      },
      {
        'question': '第二问：求伴随矩阵 A* 的三个特征值。',
        'options': ['-2, 2, -1', '2, -2, 1', '-1, 1, -2', '1, -1, 2'],
        'correctIndex': 0,
        'analysis': 'A* 的特征值为 |A|/λ。分别为 -2/1 = -2, -2/(-1) = 2, -2/2 = -1。',
      },
      {
        'question': '第三问：求矩阵 B = A* - 2E 的行列式 |B|。',
        'options': ['|B| = 12', '|B| = 0', '|B| = -12', '|B| = 8'],
        'correctIndex': 1,
        'analysis': 'B 的特征值为 A* 的特征值减 2，即 -4, 0, -3。|B| 等于特征值之积，故 |B| = -4 × 0 × -3 = 0。',
      }
    ]
  };

  int? _selectedOption;
  bool _isStepSubmitted = false;
  bool _isCorrect = false; // 🌟 新增：记录当前步是否回答正确

  void _submitStep() {
    if (_selectedOption == null) return;

    final currentStepData = _bossProblem['steps'][_currentStep];
    final isCorrect = _selectedOption == currentStepData['correctIndex'];

    setState(() {
      _isStepSubmitted = true;
      _isCorrect = isCorrect; // 🌟 记录结果
    });

    if (isCorrect) {
      // 如果正确，3秒后自动进入下一步（给用户看解析的时间）
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isCorrect) { // 再次检查防止用户手动操作冲突
          _moveToNextStep();
        }
      });
    }
  }

  // 🌟 抽取跳转逻辑：方便自动跳转和手动点击跳转
  void _moveToNextStep() {
    if (_currentStep < (_bossProblem['steps'] as List).length - 1) {
      setState(() {
        _currentStep++;
        _selectedOption = null;
        _isStepSubmitted = false;
        _isCorrect = false;
      });
    } else {
      _showVictoryDialog();
    }
  }

  // 🌟 重试逻辑：重置当前步状态
  void _retryStep() {
    setState(() {
      _selectedOption = null;
      _isStepSubmitted = false;
      _isCorrect = false;
    });
  }
  void _showVictoryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_rounded, color: Colors.orangeAccent, size: 60),
            const SizedBox(height: 16),
            const Text('大题攻克！', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('完美的逻辑链！你已经掌握了特征值与伴随矩阵的综合运用。', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), height: 1.5)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () { Navigator.pop(context); // 关弹窗
              Navigator.pop(context, true); // 🌟 告诉路线图：我闯关成功啦！
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('返回路线图', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stepData = _bossProblem['steps'][_currentStep];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('第 03 关：进阶挑战', style: TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/images/auth_bg.png', fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.4))),

          SafeArea(
            child: Column(
              children: [
                // 公共题干区
                Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryGreen.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_bossProblem['title'], style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(_bossProblem['context'], style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6)),
                    ],
                  ),
                ),

                // 拆解步骤区
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _currentStep + 1, // 只显示到当前解锁的步骤
                    itemBuilder: (context, index) {
                      final isCurrentActiveStep = index == _currentStep;
                      final step = _bossProblem['steps'][index];

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg.withValues(alpha: isCurrentActiveStep ? 0.9 : 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isCurrentActiveStep ? primaryGreen.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: isCurrentActiveStep ? primaryGreen : Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                  child: Text('Step ${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(step['question'], style: TextStyle(color: Colors.white.withValues(alpha: isCurrentActiveStep ? 1.0 : 0.6), fontSize: 15))),
                              ],
                            ),

                            if (isCurrentActiveStep) ...[
                              const SizedBox(height: 20),
                              ...List.generate(step['options'].length, (optIdx) {
                                final isSelected = _selectedOption == optIdx;
                                final isCorrect = optIdx == step['correctIndex'];

                                Color borderColor = Colors.white.withValues(alpha: 0.1);
                                if (_isStepSubmitted) {
                                  if (isCorrect) borderColor = primaryGreen;
                                  else if (isSelected) borderColor = Colors.redAccent;
                                } else if (isSelected) borderColor = primaryGreen;

                                return GestureDetector(
                                  onTap: _isStepSubmitted ? null : () => setState(() => _selectedOption = optIdx),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: borderColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Text(step['options'][optIdx], style: const TextStyle(color: Colors.white)),
                                  ),
                                );
                              }),

                              // 解析反馈
                              if (_isStepSubmitted) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _selectedOption == step['correctIndex'] ? '✅ 回答正确！${step['analysis']}' : '❌ 思路偏了。${step['analysis']}',
                                  style: TextStyle(color: _selectedOption == step['correctIndex'] ? primaryGreen : Colors.redAccent, height: 1.5),
                                ),
                              ]
                            ] else ...[
                              // 已经做过的历史步骤，只显示正确答案
                              const SizedBox(height: 16),
                              Text('正确答案：${step['options'][step['correctIndex']]}', style: TextStyle(color: primaryGreen.withValues(alpha: 0.8), fontSize: 14)),
                            ]
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // 底部按钮
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: bgDark,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))],
                  ),
                  child: _buildDynamicButton(),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
  Widget _buildDynamicButton() {
    if (!_isStepSubmitted) {
      // 状态 1：待提交
      return ElevatedButton(
        onPressed: _selectedOption == null ? null : _submitStep,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          disabledBackgroundColor: Colors.white10,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('提交本步', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      );
    } else if (!_isCorrect) {
      // 状态 2：答错了，显示重试按钮
      return ElevatedButton(
        onPressed: _retryStep,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent.withOpacity(0.8),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('重新尝试', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      );
    } else {
      // 状态 3：答对了，显示继续按钮（或者等待自动跳转）
      return ElevatedButton(
        onPressed: _moveToNextStep,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('进入下一步', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withOpacity(0.5))),
          ],
        ),
      );
    }
  }
}