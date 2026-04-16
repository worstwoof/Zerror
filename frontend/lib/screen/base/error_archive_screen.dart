import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/app_ui.dart';
import '../../core/theme.dart';
import 'error_detail_screen.dart';

class ErrorArchiveScreen extends StatefulWidget {
  const ErrorArchiveScreen({super.key});

  @override
  State<ErrorArchiveScreen> createState() => _ErrorArchiveScreenState();
}

class _ErrorArchiveScreenState extends State<ErrorArchiveScreen> {
  String _selectedSubject = '全部';

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final filteredList = store.errorsBySubject(_selectedSubject);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppPalette.textPrimary),
        title: const Text(
          '错题档案',
          style: TextStyle(color: AppPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppPalette.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: AppSurface(
        padding: const EdgeInsets.fromLTRB(20, 72, 20, 12),
        child: Column(
          children: [
            _buildStatsHeader(store),
            const SizedBox(height: 18),
            _buildSubjectFilter(store),
            const SizedBox(height: 12),
            Expanded(
              child: filteredList.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) =>
                          _buildErrorCard(context, store, filteredList[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader(AppStore store) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppPalette.pineGreen, AppPalette.kombuGreen, AppPalette.artichoke],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('累计收录', '${store.totalErrors}', AppPalette.textPrimary),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildStatItem('待复习', '${store.pendingReviewCount}', AppPalette.almondCream),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildStatItem('已掌握', '${store.masteredCount}', AppPalette.textPrimary),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(color: valueColor, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildSubjectFilter(AppStore store) {
    final subjects = store.subjectOptions;
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: subjects.length,
        itemBuilder: (context, index) {
          final subject = subjects[index];
          final isSelected = _selectedSubject == subject;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(subject),
              selected: isSelected,
              selectedColor: AppPalette.matchaMist,
              backgroundColor: AppPalette.pastelGrey.withValues(alpha: 0.08),
              labelStyle: TextStyle(
                color: isSelected ? AppPalette.night : AppPalette.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
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

  Widget _buildEmptyState() {
    return Center(
      child: AppPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.inbox_rounded,
              color: AppPalette.textSecondary,
              size: 42,
            ),
            SizedBox(height: 14),
            Text(
              '还没有错题档案',
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '先录入第一道错题，这里才会开始积累你的专属档案。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, AppStore store, ErrorRecord item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: AppPalette.pastelGrey.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: item.isMastered
                  ? AppPalette.matchaMist.withValues(alpha: 0.3)
                  : AppPalette.pastelGrey.withValues(alpha: 0.08),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ErrorDetailScreen(errorId: item.id)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _subjectPill(item.subject),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.topic,
                          style: const TextStyle(color: AppPalette.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          store.toggleFavorite(item.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(item.isFavorite ? '已取消收藏这道错题' : '已加入我的收藏'),
                              duration: const Duration(milliseconds: 1200),
                            ),
                          );
                        },
                        icon: Icon(
                          item.isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          color: item.isFavorite ? AppPalette.almondCream : AppPalette.textSecondary,
                          size: 20,
                        ),
                      ),
                      if (item.isMastered)
                        const Icon(Icons.check_circle_rounded, color: AppPalette.matchaMist, size: 18)
                      else
                        Text(
                          item.dateLabel,
                          style: const TextStyle(color: AppPalette.textSecondary, fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    item.question,
                    style: const TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.flag_rounded,
                              color: const Color(0xFFE17D6B).withValues(alpha: 0.8),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '错因: ${item.reason}',
                                style: TextStyle(
                                  color: const Color(0xFFE17D6B).withValues(alpha: 0.9),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ErrorDetailScreen(errorId: item.id)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: item.isMastered ? Colors.transparent : AppPalette.matchaMist,
                          elevation: 0,
                          side: item.isMastered ? const BorderSide(color: AppPalette.matchaMist) : BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: Text(
                          item.isMastered ? '再看一眼' : '开始复习',
                          style: TextStyle(
                            color: item.isMastered ? AppPalette.matchaMist : AppPalette.night,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _subjectPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppPalette.matchaMist.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppPalette.matchaMist, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
