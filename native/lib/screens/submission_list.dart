import 'package:flutter/material.dart';
import 'package:native_app/models/submission.dart';

import '../services/storage_service.dart';
import '../main.dart' as app;
import '../theme/theme.dart';
import '../widgets/date_formatter.dart';
import '../widgets/ui/ui.dart';
import 'submission_detail.dart';
import 'submit_screen.dart';

class SubmissionList extends StatefulWidget {
  const SubmissionList({super.key});

  @override
  State<SubmissionList> createState() => _SubmissionListState();
}

class _SubmissionListState extends State<SubmissionList> {
  List<Submission> _submissions = [];
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _cursor;

  static const int _pageSize = 5;

  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  bool _hasImage = false;
  bool _hasVideo = false;
  bool _hasPhoneNumber = false;
  bool _hasLocation = false;
  bool _hasTitle = false;

  bool get _hasFilters =>
      _search.isNotEmpty ||
      _hasImage ||
      _hasVideo ||
      _hasPhoneNumber ||
      _hasLocation ||
      _hasTitle;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification &&
        notification.metrics.extentAfter <= 0 &&
        _hasMore &&
        !_loadingMore &&
        !_loading) {
      _fetchNextPage();
    }
    return false;
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final browserId = await StorageService.getBrowserId();
      final result = await _callApi(browserId, cursor: null);

      setState(() {
        _submissions = _parseSubmissions(result);
        _updateCursor(result);
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('LOAD ERROR: $e\n$st');
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _fetchNextPage() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    try {
      final browserId = await StorageService.getBrowserId();
      final result = await _callApi(browserId, cursor: _cursor);

      if (!mounted) return;
      setState(() {
        _submissions.addAll(_parseSubmissions(result));
        _updateCursor(result);
        _loadingMore = false;
      });
    } catch (e, st) {
      debugPrint('FETCH NEXT ERROR: $e\n$st');
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<Map<String, dynamic>> _callApi(String browserId, {String? cursor}) {
    return app.apiService.listMySubmissions(
      browserId,
      q: _search,
      hasImage: _hasImage,
      hasVideo: _hasVideo,
      hasPhoneNumber: _hasPhoneNumber,
      hasLocation: _hasLocation,
      hasTitle: _hasTitle,
      cursor: cursor,
      limit: _pageSize,
    );
  }

  List<Submission> _parseSubmissions(Map<String, dynamic> result) {
    final resultData = result['data'] as Map<String, dynamic>;
    final rawList = (resultData['submissions'] as List<dynamic>?) ?? [];
    return rawList
        .map((json) => Submission.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  void _updateCursor(Map<String, dynamic> result) {
    final pag = result['pagination'] as Map<String, dynamic>?;
    _cursor = pag?['nextCursor'] as String?;
    _hasMore = (pag?['hasMore'] as bool?) ?? false;
  }

  Future<void> _reload() {
    setState(() {
      _cursor = null;
      _hasMore = true;
      _submissions.clear();
    });
    return _loadSubmissions();
  }

  void _applySearch(String value) {
    setState(() {
      _search = value;
      _hasImage = false;
      _hasVideo = false;
      _hasPhoneNumber = false;
      _hasLocation = false;
      _hasTitle = false;
      _cursor = null;
      _hasMore = true;
      _submissions.clear();
      _error = null;
    });
    _loadSubmissions();
  }

  void _clearFilters() {
    setState(() {
      _search = '';
      _searchCtrl.clear();
      _hasImage = false;
      _hasVideo = false;
      _hasPhoneNumber = false;
      _hasLocation = false;
      _hasTitle = false;
      _cursor = null;
      _hasMore = true;
      _submissions.clear();
      _error = null;
    });
    _loadSubmissions();
  }

  void _showFilterSortSheet() {
    showAppSheet<void>(
      context,
      child: StatefulBuilder(
        builder: (context, setModalState) {
          Widget filterSwitch(
            String label,
            IconData icon,
            bool value,
            ValueChanged<bool> onChanged,
          ) {
            return SwitchListTile(
              value: value,
              secondary: Icon(icon, size: AppIconSize.md),
              title: Text(label, style: Theme.of(context).textTheme.bodyLarge),
              contentPadding: EdgeInsets.zero,
              onChanged: (v) {
                setModalState(() => onChanged(v));
                setState(() {});
              },
            );
          }

          return SingleChildScrollView(
            padding: AppSpacing.screen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter by content',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                AppSpacing.gapSm,
                filterSwitch(
                  'Has title',
                  Icons.title,
                  _hasTitle,
                  (v) => _hasTitle = v,
                ),
                filterSwitch(
                  'Has photo',
                  Icons.image_outlined,
                  _hasImage,
                  (v) => _hasImage = v,
                ),
                filterSwitch(
                  'Has video',
                  Icons.videocam_outlined,
                  _hasVideo,
                  (v) => _hasVideo = v,
                ),
                filterSwitch(
                  'Has phone number',
                  Icons.phone_outlined,
                  _hasPhoneNumber,
                  (v) => _hasPhoneNumber = v,
                ),
                filterSwitch(
                  'Has location',
                  Icons.location_on_outlined,
                  _hasLocation,
                  (v) => _hasLocation = v,
                ),
                AppSpacing.gapMd,
                PrimaryButton(
                  label: 'Apply',
                  onPressed: () {
                    Navigator.pop(context);
                    _reload();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _navigateToSubmit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubmitScreen()),
    );
  }

  void _navigateToDetail(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubmissionDetailScreen(submissionId: id),
      ),
    );
  }

  void _handleBackNavigation() {
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SubmitScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Log'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: _handleBackNavigation,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: () => app.showMenu(
              context,
              onNavigateNew: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubmitScreen()),
              ),
              onNavigateSubmissions: () {},
              onLock: app.logoutHandler,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search submissions',
                      prefixIcon: const Icon(
                        Icons.search,
                        size: AppIconSize.md,
                      ),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                size: AppIconSize.md,
                              ),
                              tooltip: 'Clear search',
                              onPressed: () => _applySearch(''),
                            )
                          : null,
                    ),
                    onSubmitted: _applySearch,
                  ),
                ),
                AppSpacing.gapHSm,
                IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: _hasFilters
                        ? context.colors.primary
                        : context.colors.textSecondary,
                  ),
                  tooltip: 'Filter',
                  onPressed: _showFilterSortSheet,
                ),
              ],
            ),
          ),
          if (_hasFilters)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ..._buildFilterChips(),
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            ),
          if (!_loading && _submissions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Showing ${_submissions.length} submission${_submissions.length == 1 ? '' : 's'}',
                  style: context.mono(
                    fontSize: 11,
                    color: context.colors.textTertiary,
                  ),
                ),
              ),
            ),
          ],
          if (_loading)
            const Expanded(
              child: LoadingView(),
            ),
          if (!_loading && _error != null)
            Expanded(child: _buildError()),
          if (!_loading && _error == null && _submissions.isEmpty)
            Expanded(
              child: EmptyState(
                message: _hasFilters ? 'No matching submissions' : 'No submissions yet',
                detail: _hasFilters
                    ? 'Try adjusting or clearing your filters.'
                    : 'Tap "New Submission" to create your first one.',
              ),
            ),
          if (!_loading && _error == null && _submissions.isNotEmpty)
            Expanded(
              child: _buildScrollWithFooter(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToSubmit,
        icon: const Icon(Icons.add),
        label: const Text('New Submission'),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required VoidCallback onTap,
  }) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: c.primarySubtle,
          borderRadius: AppRadii.brSm,
          border: Border.all(color: c.primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: c.accent, letterSpacing: 0),
        ),
      ),
    );
  }

  List<Widget> _buildFilterChips() {
    final chips = <Widget>[];

    if (_search.isNotEmpty)
      chips.add(_filterChip(
        label: _search,
        onTap: () => _applySearch(''),
      ));
    if (_hasImage)
      chips.add(_filterChip(
        label: 'Photo',
        onTap: () {
          setState(() => _hasImage = false);
          _reload();
        },
      ));
    if (_hasVideo)
      chips.add(_filterChip(
        label: 'Video',
        onTap: () {
          setState(() => _hasVideo = false);
          _reload();
        },
      ));
    if (_hasPhoneNumber)
      chips.add(_filterChip(
        label: 'Phone',
        onTap: () {
          setState(() => _hasPhoneNumber = false);
          _reload();
        },
      ));
    if (_hasLocation)
      chips.add(_filterChip(
        label: 'Location',
        onTap: () {
          setState(() => _hasLocation = false);
          _reload();
        },
      ));
    if (_hasTitle)
      chips.add(_filterChip(
        label: 'Title',
        onTap: () {
          setState(() => _hasTitle = false);
          _reload();
        },
      ));

    return chips;
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: AppSpacing.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBanner(message: _error!),
            AppSpacing.gapLg,
            OutlinedButton.icon(
              onPressed: _loadSubmissions,
              icon: const Icon(Icons.refresh, size: AppIconSize.md),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return EmptyState(
      message: _hasFilters ? 'No matching submissions' : 'No submissions yet',
      detail: _hasFilters
          ? 'Try adjusting or clearing your filters.'
          : 'Tap "New Submission" to create your first one.',
    );
  }

  Widget _buildList() {
    final c = context.colors;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          sliver: SliverList.separated(
            itemCount: _submissions.length,
            separatorBuilder: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Divider(height: 1, color: c.outline),
            ),
            itemBuilder: (context, index) {
              final s = _submissions[index];
              final hasTitle = s.what?.isNotEmpty == true;
              return InkWell(
                onTap: () => _navigateToDetail(s.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hasTitle ? s.what! : 'Untitled submission',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: hasTitle
                                        ? c.textPrimary
                                        : c.textTertiary,
                                    fontStyle: hasTitle
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              formatDate(s.createdAt),
                              style: context.mono(
                                fontSize: 11,
                                color: c.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (s.mediaCount > 0) ...[
                        Icon(
                          Icons.attach_file,
                          size: AppIconSize.sm,
                          color: c.textTertiary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${s.mediaCount}',
                          style: context.mono(
                            fontSize: 12,
                            color: c.textTertiary,
                          ),
                        ),
                        AppSpacing.gapHMd,
                      ],
                      Icon(
                        Icons.chevron_right,
                        size: AppIconSize.md,
                        color: c.textTertiary,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: _buildFooterAlwaysVisible(),
        ),
      ],
    );
  }

  Widget _buildScrollWithFooter() {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: RefreshIndicator(
        onRefresh: _reload,
        child: _buildList(),
      ),
    );
  }

  Widget _buildFooterAlwaysVisible() {
    if (!_hasMore && !_loadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          'You\'ve seen all ${_submissions.length} submission${_submissions.length == 1 ? '' : 's'}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            height: AppIconSize.md,
            width: AppIconSize.md,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        'Scroll down to load more',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
