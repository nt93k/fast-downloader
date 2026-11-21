import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../core/download_manager.dart';
import '../core/download_task.dart';
import '../utils/format.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DownloadManager _manager = DownloadManager();
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _manager.init();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocus.dispose();
    _manager.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال رابط يبدأ بـ http أو https')),
      );
      return;
    }
    _manager.addDownload(url);
    _urlController.clear();
    _urlFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _manager,
              builder: (context, _) => Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F7FB),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildInputCard(),
                          _buildListHeader(),
                          Expanded(child: _buildTaskList()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.rocket_launch, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تنزيل سريع',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'تنزيل من الرابط مع استئناف تلقائي بعد انقطاع الإنترنت',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Chip(
            avatar: Icon(
              _manager.isOnline ? Icons.wifi : Icons.wifi_off,
              size: 16,
              color: _manager.isOnline ? Colors.green : Colors.red,
            ),
            label: Text(
              _manager.isOnline ? 'متصل' : 'غير متصل',
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.9),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _urlController,
                focusNode: _urlFocus,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                keyboardType: TextInputType.url,
                autocorrect: false,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'https://example.com/file.zip',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.link),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.download),
                label: const Text('ابدأ التنزيل', style: TextStyle(fontSize: 16)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Row(
        children: [
          const Text(
            'التنزيلات',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(
            '(${_manager.tasks.length})',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const Spacer(),
          if (_manager.tasks.any(
            (task) =>
                task.status == DownloadStatus.done ||
                task.status == DownloadStatus.canceled,
          ))
            TextButton(
              onPressed: _manager.clearFinished,
              child: const Text('تنظيف المكتملة'),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    if (_manager.tasks.isEmpty) {
      return Center(
        child: Opacity(
          opacity: 0.65,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_download_outlined,
                  size: 76, color: Colors.blue.shade300),
              const SizedBox(height: 16),
              const Text(
                'لا توجد تنزيلات بعد',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'ألصق رابط الملف في الأعلى واضغط ابدأ. إذا انقطع الإنترنت فسيعود التنزيل للمتابعة من حيث توقف.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: _manager.tasks.length,
      itemBuilder: (context, index) =>
          _buildTaskCard(_manager.tasks[index]),
    );
  }

  Widget _buildTaskCard(DownloadTask task) {
    final remaining = formatDuration(task.remaining);
    final totalText = task.totalBytes == null
        ? '—'
        : formatBytes(task.totalBytes!);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _statusColor(task.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _statusIcon(task.status),
                    color: _statusColor(task.status),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        task.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip(task),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: task.totalBytes == null ? null : task.progress,
                minHeight: 9,
                backgroundColor: Colors.grey.shade200,
                color: _statusColor(task.status),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${formatBytes(task.downloaded)} / $totalText'
                  '${remaining != null ? '  •  متبقي $remaining' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const Spacer(),
                Text(
                  formatSpeed(task.speedBytesPerSecond),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            if (task.status == DownloadStatus.error &&
                task.errorMessage != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 15, color: Colors.red.shade400),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${task.errorMessage} — سيُعاد المحاولة تلقائياً',
                      style:
                          TextStyle(fontSize: 11, color: Colors.red.shade500),
                    ),
                  ),
                ],
              ),
            ],
            if (task.status == DownloadStatus.done &&
                task.savedPath != null) ...[
              const SizedBox(height: 8),
              Text(
                task.savedPath!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: 11, color: Colors.green.shade700),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (task.canPause)
                  IconButton(
                    tooltip: 'إيقاف مؤقت',
                    icon: const Icon(Icons.pause_circle_outline),
                    onPressed: () => _manager.pause(task),
                  ),
                if (task.canResume)
                  IconButton(
                    tooltip: task.status == DownloadStatus.error
                        ? 'إعادة المحاولة الآن'
                        : 'متابعة',
                    icon: const Icon(Icons.play_circle_outline),
                    onPressed: () => _manager.resume(task),
                  ),
                if (task.status == DownloadStatus.done &&
                    task.savedPath != null)
                  IconButton(
                    tooltip: 'نسخ مسار الملف',
                    icon: const Icon(Icons.folder_open_outlined),
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: task.savedPath!));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ مسار الملف')),
                      );
                    },
                  ),
                IconButton(
                  tooltip: 'إلغاء وحذف',
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  onPressed: () => _manager.remove(task),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(DownloadTask task) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _statusColor(task.status).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(task.status),
        style: TextStyle(
          color: _statusColor(task.status),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _statusLabel(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return 'جارٍ التنزيل';
      case DownloadStatus.paused:
        return 'متوقف';
      case DownloadStatus.error:
        return 'إعادة الاتصال';
      case DownloadStatus.done:
        return 'اكتمل';
      case DownloadStatus.canceled:
        return 'ملغي';
    }
  }

  Color _statusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return const Color(0xFF1565C0);
      case DownloadStatus.paused:
        return Colors.orange.shade700;
      case DownloadStatus.error:
        return Colors.red.shade600;
      case DownloadStatus.done:
        return Colors.green.shade700;
      case DownloadStatus.canceled:
        return Colors.grey;
    }
  }

  IconData _statusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return Icons.downloading_rounded;
      case DownloadStatus.paused:
        return Icons.pause_circle_outline;
      case DownloadStatus.error:
        return Icons.wifi_off;
      case DownloadStatus.done:
        return Icons.check_circle_outline;
      case DownloadStatus.canceled:
        return Icons.cancel_outlined;
    }
  }
}
