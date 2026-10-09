import 'package:flutter/material.dart';
import 'package:native_app/models/submission.dart';
import '../services/storage_service.dart';
import '../main.dart' as app;
import '../widgets/date_formatter.dart';
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

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  // Filters
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
    setState(() => _loading = true);
    try {
      final browserId = await StorageService.getBrowserId();
      final result = await app.apiService.listMySubmissions(
        browserId,
        q: _search,
        hasImage: _hasImage,
        hasVideo: _hasVideo,
        hasPhoneNumber: _hasPhoneNumber,
        hasLocation: _hasLocation,
        hasTitle: _hasTitle,
      );
      final rawList = (result['data'] as List<dynamic>?) ?? [];
      setState(() {
        _submissions = rawList
            .map((json) => Submission.fromJson(json as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _applySearch(String value) {
    setState(() {
      _search = value;
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
    });
    _loadSubmissions();
  }

  void _showFilterSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filter by Content', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _hasTitle,
                  secondary: const Icon(Icons.title, size: 20, color: Color(0xFF9CA3AF)),
                  title: const Text('Has Title', style: TextStyle(color: Color(0xFFE5E7EB))),
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (v) => setModalState(() => _hasTitle = v),
                ),
                SwitchListTile(
                  value: _hasImage,
                  secondary: const Icon(Icons.image, size: 20, color: Color(0xFF9CA3AF)),
                  title: const Text('Has Photo', style: TextStyle(color: Color(0xFFE5E7EB))),
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (v) => setModalState(() => _hasImage = v),
                ),
                SwitchListTile(
                  value: _hasVideo,
                  secondary: const Icon(Icons.videocam, size: 20, color: Color(0xFF9CA3AF)),
                  title: const Text('Has Video', style: TextStyle(color: Color(0xFFE5E7EB))),
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (v) => setModalState(() => _hasVideo = v),
                ),
                SwitchListTile(
                  value: _hasPhoneNumber,
                  secondary: const Icon(Icons.phone, size: 20, color: Color(0xFF9CA3AF)),
                  title: const Text('Has Phone Number', style: TextStyle(color: Color(0xFFE5E7EB))),
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (v) => setModalState(() => _hasPhoneNumber = v),
                ),
                SwitchListTile(
                  value: _hasLocation,
                  secondary: const Icon(Icons.location_on, size: 20, color: Color(0xFF9CA3AF)),
                  title: const Text('Has Location', style: TextStyle(color: Color(0xFFE5E7EB))),
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (v) => setModalState(() => _hasLocation = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _loadSubmissions();
                    },
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Apply', style: TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.pop(context) : null,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => app.showMenu(
              context,
              onNavigateNew: () => Navigator.pop(context),
              onNavigateSubmissions: () {},
              onLock: app.logout,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () => _applySearch(''),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      isDense: true,
                    ),
                    onSubmitted: _applySearch,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: _hasFilters ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
                    size: 22,
                  ),
                  onPressed: _showFilterSortSheet,
                ),
              ],
            ),
          ),

          if (_hasFilters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  ..._buildFilterChips(),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _submissions.isEmpty
                        ? _buildEmpty()
                        : _buildList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToSubmit(),
        icon: const Icon(Icons.add),
        label: const Text('New Submission'),
      ),
    );
  }

  List<Widget> _buildFilterChips() {
    final chips = <Widget>[];
    if (_search.isNotEmpty) {
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Chip(
          label: Text('"$_search"', style: const TextStyle(fontSize: 11)),
          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.3),
          visualDensity: VisualDensity.compact,
        ),
      ));
    }
    if (_hasImage) {
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Chip(
          label: const Text('Photo', style: TextStyle(fontSize: 11)),
          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.3),
          visualDensity: VisualDensity.compact,
        ),
      ));
    }
    if (_hasVideo) {
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Chip(
          label: const Text('Video', style: TextStyle(fontSize: 11)),
          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.3),
          visualDensity: VisualDensity.compact,
        ),
      ));
    }
    if (_hasPhoneNumber) {
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Chip(
          label: const Text('Phone', style: TextStyle(fontSize: 11)),
          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.3),
          visualDensity: VisualDensity.compact,
        ),
      ));
    }
    if (_hasLocation) {
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Chip(
          label: const Text('Location', style: TextStyle(fontSize: 11)),
          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.3),
          visualDensity: VisualDensity.compact,
        ),
      ));
    }
    if (_hasTitle) {
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Chip(
          label: const Text('Title', style: TextStyle(fontSize: 11)),
          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.3),
          visualDensity: VisualDensity.compact,
        ),
      ));
    }
    return chips;
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
              ),
              child: Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5)), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadSubmissions,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_upload_outlined, size: 48, color: Color(0xFF6B7280)),
          const SizedBox(height: 8),
          Text(
            _hasFilters ? 'No matching submissions' : 'No submissions yet',
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadSubmissions,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _submissions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final s = _submissions[index];
          return Card(
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFF1F2937)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text(
                s.what?.isNotEmpty == true ? s.what! : '[No title]',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFE5E7EB)),
              ),
              subtitle: Text(
                formatDate(s.createdAt),
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s.mediaCount > 0) ...[
                    const Icon(Icons.attach_file, size: 16, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    Text('${s.mediaCount}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                  ],
                ],
              ),
              onTap: () => _navigateToDetail(s.id),
            ),
          );
        },
      ),
    );
  }

  void _navigateToSubmit() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubmitScreen()),
    );
  }

  void _navigateToDetail(String id) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SubmissionDetailScreen(submissionId: id)));
  }
}
