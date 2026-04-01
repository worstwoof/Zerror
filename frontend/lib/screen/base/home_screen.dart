import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 顶部摘要区 (Hero 区域)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('早安，知识的种子正在发芽 🌱', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.secondary)),
                    const SizedBox(height: 8),
                    Text('连续复习 12 天', style: theme.textTheme.headlineLarge),
                    Text('本周沉淀 34 题', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.secondary)),
                    const SizedBox(height: 24),
                    // TODO: 这里未来可以放你提到的“网格植物图”或“年轮图”的可视化组件
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                      ),
                      child: Center(
                        child: Text('抽象植物可视化区域', style: theme.textTheme.bodySmall),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 中部 - 今日待办 (To-Do)
            SliverToBoxAdapter(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('今日训练任务', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text('需灌溉 5 题', style: theme.textTheme.bodyMedium),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: 跳转到特训营
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), // 圆滑的主按钮
                        ),
                        child: const Text('开始复习', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 底部 - 学习记录标题
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 24, top: 32, bottom: 8),
                child: Text('学习记录', style: theme.textTheme.titleLarge),
              ),
            ),

            // 底部 - 最近沉淀的错题列表
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      title: Text('二次函数极值与区间的最值问题探讨', style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            _buildTag('🟢 数学', theme),
                            const SizedBox(width: 8),
                            _buildTag('导数应用', theme),
                          ],
                        ),
                      ),
                      trailing: const CircularProgressIndicator(
                        value: 0.25, // 掌握度 25%
                        backgroundColor: Color(0xFFEAF0EB),
                        color: Color(0xFF6A8A71),
                        strokeWidth: 4,
                      ),
                      onTap: () {
                        // TODO: 点击进入详情页
                      },
                    ),
                  );
                },
                childCount: 5, // 占位显示 5 条记录
              ),
            ),

            // 底部留白
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // 专属的小标签组件 (药丸形状)
  Widget _buildTag(String text, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F1), // 浅灰绿底
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w500),
      ),
    );
  }
}