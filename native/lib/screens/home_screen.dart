import 'package:flutter/material.dart';
import 'package:native_app/models/submission.dart';

import '../services/storage_service.dart';
import '../main.dart' as app;
import '../theme/theme.dart';
import '../widgets/date_formatter.dart';
import '../widgets/ui/ui.dart';
import 'submission_detail.dart';
import 'submit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Submission> _submissions = [];
  String? _error;
  bool _loading = true;
  int _totalPages = 1;

  static const int _pageSize = 5;
  int _currentPage = 0;

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

  Future<void> _loadSubmissions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final browserId = await StorageService.getBrowserId();
      final result = await app.apiService.listMySubmissionsWithPagination(
        browserId,
        q: _search,
        hasImage: _hasImage,
        hasVideo: _hasVideo,
        hasPhoneNumber: _hasPhoneNumber,
        hasLocation: _hasLocation,
        hasTitle: _hasTitle,
        page: _currentPage + 1,
        limit: _pageSize,
      );

      final resultData = result['data'] as Map<String, dynamic>;
      final rawList = (resultData['submissions'] as List<dynamic>?) ?? [];
      final pag = result['pagination'] as Map<String, dynamic>?;
      final totalPages = (pag?['totalPages'] as num?)?.toInt() ?? 1;

      setState(() {
        _submissions = rawList
            .map((json) => Submission.fromJson(json as Map<String, dynamic>))
            .toList();
        _totalPages = totalPages < 1 ? 1 : totalPages;
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

  void _goToPage(int page) {
    if (_loading || page < 0 || page >= _totalPages || page == _currentPage) {
      return;
    }
    setState(() => _currentPage = page);
    _loadSubmissions();
  }

  Future<void> _reload() {
    setState(() {
      _currentPage = 0;
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
      _currentPage = 0;
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
      _currentPage = 0;
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
              title: Text(label,
                  style: Theme.of(context).textTheme.bodyLarge),
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
                Text('Filter by content',
                    style: Theme.of(context).textTheme.titleMedium),
                AppSpacing.gapSm,
                filterSwitch('Has title', Icons.title, _hasTitle,
                    (v) => _hasTitle = v),
                filterSwitch('Has photo', Icons.image_outlined, _hasImage,
                    (v) => _hasImage = v),
                filterSwitch('Has video', Icons.videocam_outlined, _hasVideo,
                    (v) => _hasVideo = v),
                filterSwitch('Has phone number', Icons.phone_outlined,
                    _hasPhoneNumber, (v) => _hasPhoneNumber = v),
                filterSwitch('Has location', Icons.location_on_outlined,
                    _hasLocation, (v) => _hasLocation = v),
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
                      prefixIcon:
                          const Icon(Icons.search, size: AppIconSize.md),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  size: AppIconSize.md),
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
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? _buildError()
                    : _submissions.isEmpty
                        ? _buildEmpty()
                        : _buildList(),
          ),
        ],
      ),
      bottomNavigationBar: _buildPagination(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToSubmit,
        icon: const Icon(Icons.add),
        label: const Text('New Submission'),
      ),
    );
  }

  List<Widget> _buildFilterChips() {
    final c = context.colors;
    final chips = <Widget>[];

    Widget chip(String label) => Container(
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
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: c.accent, letterSpacing: 0),
          ),
        );

    if (_search.isNotEmpty) chips.add(chip(_search));
    if (_hasImage) chips.add(chip('Photo'));
    if (_hasVideo) chips.add(chip('Video'));
    if (_hasPhoneNumber) chips.add(chip('Phone'));
    if (_hasLocation) chips.add(chip('Location'));
    if (_hasTitle) chips.add(chip('Title'));

    return chips;
  }

  Widget? _buildPagination() {
    if (_totalPages <= 1) return null;
    final c = context.colors;

    var start = _currentPage - 2;
    if (start < 0) start = 0;
    var end = start + 4;
    if (end > _totalPages - 1) {
      end = _totalPages - 1;
      start = end - 4;
      if (start < 0) start = 0;
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.outline)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous page',
              onPressed: (_currentPage > 0 && !_loading)
                  ? () => _goToPage(_currentPage - 1)
                  : null,
            ),
            for (var i = start; i <= end; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(40, 40),
                      backgroundColor:
                          i == _currentPage ? c.primary : Colors.transparent,
                      foregroundColor:
                          i == _currentPage ? c.onPrimary : c.textSecondary,
                    ),
                    onPressed: _loading ? null : () => _goToPage(i),
                    child: Text('${i + 1}'),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next page',
              onPressed: (_currentPage < _totalPages - 1 && !_loading)
                  ? () => _goToPage(_currentPage + 1)
                  : null,
            ),
          ],
        ),
      ),
    );
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
          : 'Tap “New Submission” to create your first one.',
    );
  }

  Widget _buildList() {
    final c = context.colors;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: _submissions.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: c.outline),
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
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                    Icon(Icons.attach_file,
                        size: AppIconSize.sm, color: c.textTertiary),
                    const SizedBox(width: AppSpacing.xs),
                    Text('${s.mediaCount}',
                        style: context.mono(
                            fontSize: 12, color: c.textTertiary)),
                    AppSpacing.gapHMd,
                  ],
                  Icon(Icons.chevron_right,
                      size: AppIconSize.md, color: c.textTertiary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
