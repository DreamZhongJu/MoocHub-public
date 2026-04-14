import 'dart:async';
import 'package:MoocHub/model/VideoModel.dart';
import 'package:MoocHub/services/AnalyticsService.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:MoocHub/widget/CommentsPanel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tencent_kit/tencent_kit.dart';
import 'package:video_player/video_player.dart';

class VideoDetailPage extends StatefulWidget {
  final int videoId;

  const VideoDetailPage({super.key, required this.videoId});

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final AnalyticsService _analyticsService = AnalyticsService();

  VideoModel? _video;
  bool _loading = true;
  bool _error = false;
  bool _loggedIn = false;
  bool _showControls = true;
  double _playbackSpeed = 1.0;
  double? _dragValue;
  bool _isFullscreen = false;
  DateTime? _lastProgressSentAt;
  Timer? _hideTimer;
  Timer? _progressTimer;
  VideoPlayerController? _videoController;
  bool _playEventSent = false;
  bool _completeEventSent = false;
  late final String _qqAppId;
  TencentKitPlatform? _tencent;
  StreamSubscription<TencentResp>? _qqShareSub;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _initTencent();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _hideTimer?.cancel();
    _saveProgress(force: true);
    _qqShareSub?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  void _initTencent() {
    _qqAppId = (dotenv.env['QQ_APP_ID'] ?? dotenv.env['TENCENT_APP_ID'] ?? '')
        .trim();
    if (_qqAppId.isNotEmpty && !kIsWeb) {
      _tencent = TencentKitPlatform.instance;
      _tencent!.registerApp(appId: _qqAppId);
      _qqShareSub = _tencent!.respStream().listen(_handleTencentResp);
    }
  }

  void _handleTencentResp(TencentResp resp) {
    if (resp is TencentShareMsgResp && mounted) {
      if (resp.isSuccessful) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('分享成功')));
      } else if (resp.isCancelled) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已取消分享')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(resp.msg ?? '分享失败')));
      }
    }
  }

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('分享给 QQ 好友'),
                onTap: () {
                  Navigator.pop(context);
                  _shareToQQ(TencentScene.kScene_QQ);
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('分享到 QQ 空间'),
                onTap: () {
                  Navigator.pop(context);
                  _shareToQQ(TencentScene.kScene_QZone);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareToQQ(int scene) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Web 不支持 QQ 分享')));
      return;
    }
    if (_qqAppId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QQ AppID 未配置')));
      return;
    }
    if (_tencent == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QQ SDK 未初始化')));
      return;
    }
    final installed = await _tencent!.isQQInstalled();
    if (!installed) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未检测到 QQ 客户端')));
      }
      return;
    }
    final video = _video;
    if (video == null) return;

    await _tencent!.shareWebpage(
      scene: scene,
      title: video.title,
      summary: video.description.isNotEmpty ? video.description : null,
      imageUri: video.thumbUrl.isNotEmpty ? Uri.parse(video.thumbUrl) : null,
      targetUrl: video.videoUrl,
      appName: 'MoocHub',
    );
  }

  Future<void> _bootstrap() async {
    final token = await _storageService.getUserToken();
    _loggedIn = token != null && token.toString().isNotEmpty && token != 'null';
    if (mounted) setState(() {});
    await _loadVideo();
  }

  Future<void> _loadVideo() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/videos/${widget.videoId}',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );

      if (response.code != 0 && response.code != 200) {
        throw Exception(response.msg);
      }

      final raw = response.data['video'];
      if (raw is! Map<String, dynamic>) throw Exception('video data invalid');

      final video = VideoModel.fromJson(raw);
      if (video.videoUrl.isEmpty) throw Exception('video url empty');

      _playEventSent = false;
      _completeEventSent = false;
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(video.videoUrl),
      );
      await _videoController!.initialize();
      await _videoController!.setPlaybackSpeed(_playbackSpeed);
      _videoController!.addListener(_handlePlayerUpdate);

      if (_loggedIn) await _loadProgress();
      _startProgressTimer();

      if (mounted) setState(() => _video = video);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _saveProgress(),
    );
  }

  void _handlePlayerUpdate() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      _maybeReportPlayEvent();
      _maybeReportCompleteEvent();
      return;
    }
    _saveProgress();
  }

  Future<void> _refreshLoginState() async {
    final token = await _storageService.getUserToken();
    _loggedIn = token != null && token.toString().isNotEmpty && token != 'null';
  }

  Future<void> _saveProgress({bool force = false}) async {
    await _refreshLoginState();
    if (!_loggedIn) return;
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    final position = controller.value.position.inSeconds;
    final duration = controller.value.duration.inSeconds;
    if (!force && position == 0) return;

    final now = DateTime.now();
    if (!force && _lastProgressSentAt != null) {
      if (now.difference(_lastProgressSentAt!).inSeconds < 5) return;
    }

    final percent = duration <= 0 ? 0 : position / duration * 100;
    try {
      final token = await _storageService.getUserToken();
      final headers = token == null ? null : {'Authorization': token};
      await _apiService.postForm<Map<String, dynamic>>(
        '/progress',
        data: {
          'video_id': widget.videoId.toString(),
          'last_position_sec': position.toString(),
          'progress_percent': percent.toStringAsFixed(2),
        },
        headers: headers,
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      _lastProgressSentAt = now;
    } catch (_) {}
  }

  Future<void> _maybeReportPlayEvent() async {
    if (_playEventSent) return;
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final position = controller.value.position.inSeconds;
    final duration = controller.value.duration.inSeconds;
    final percent = duration <= 0 ? 0 : position / duration * 100;
    if (position < 10 && percent < 5) return;
    final ok = await _analyticsService.trackPlayStart(
      videoId: widget.videoId,
      scene: 'video_detail',
      position: position,
    );
    if (ok) _playEventSent = true;
  }

  Future<void> _maybeReportCompleteEvent() async {
    if (_completeEventSent) return;
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration.inSeconds;
    if (duration <= 0) return;
    final position = controller.value.position.inSeconds
        .clamp(0, duration)
        .toInt();
    final percent = position / duration * 100;
    if (percent < 90) return;
    final ok = await _analyticsService.trackPlayComplete(
      videoId: widget.videoId,
      scene: 'video_detail',
      position: position,
    );
    if (ok) {
      _completeEventSent = true;
      _onLearningComplete();
    }
  }

  /// 学习完成后查询最新积分并弹出奖励提示
  Future<void> _onLearningComplete() async {
    if (!_loggedIn) return;
    try {
      final resp = await _apiService.get<Map<String, dynamic>>(
        '/points/balance',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      final balance = (resp.data['points_balance'] as num?)?.toInt();
      if (!mounted) return;
      final msg = balance != null
          ? '🎉 学习完成！当前积分：$balance'
          : '🎉 恭喜完成本节学习，积分已到账';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2D2D3A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.stars_rounded, color: Colors.amber, size: 18),
                SizedBox(width: 8),
                Text(
                  '🎉 恭喜完成本节学习，积分已到账',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF2D2D3A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadProgress() async {
    await _refreshLoginState();
    if (!_loggedIn) return;
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/progress/${widget.videoId}',
        fromJson: (raw) => raw as Map<String, dynamic>,
      );
      if (response.code != 0 && response.code != 200) return;

      final data = response.data;
      final lastPos = data['last_position_sec'];
      int lastSeconds = 0;
      if (lastPos is num) {
        lastSeconds = lastPos.toInt();
      } else if (lastPos is String) {
        lastSeconds = int.tryParse(lastPos) ?? 0;
      }

      final controller = _videoController;
      if (controller != null &&
          controller.value.isInitialized &&
          lastSeconds > 0) {
        final duration = controller.value.duration.inSeconds;
        if (lastSeconds < duration) {
          await controller.seekTo(Duration(seconds: lastSeconds));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已为你续播至 ${_formatDuration(lastSeconds)}'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      }
    } catch (_) {}
  }

  void _toggleControls() {
    if (_showControls) {
      _hideTimer?.cancel();
      setState(() => _showControls = false);
    } else {
      _showControlsNow();
    }
  }

  void _showControlsNow() {
    if (!_showControls) setState(() => _showControls = true);
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  Future<void> _showSpeedPicker() async {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    final selected = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final primary = Theme.of(ctx).colorScheme.primary;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2230) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(0, 16, 0, 16),
                  child: Text(
                    '播放速度',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                // Chip grid: 3 per row
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: speeds.map((speed) {
                      final active = speed == _playbackSpeed;
                      return GestureDetector(
                        onTap: () => Navigator.pop(ctx, speed),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width:
                              (MediaQuery.of(ctx).size.width - 40 - 10 * 2) / 3,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: active
                                ? primary.withValues(alpha: 0.12)
                                : (isDark
                                      ? const Color(0xFF252A38)
                                      : const Color(0xFFF3F5F9)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: active ? primary : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            speed == 1.0 ? '正常' : '${speed}x',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: active
                                  ? primary
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await _videoController?.setPlaybackSpeed(selected);
      if (mounted) setState(() => _playbackSpeed = selected);
    }
  }

  Future<void> _enterFullscreen() async {
    if (_videoController == null || _isFullscreen) return;
    setState(() => _isFullscreen = true);

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: _showControlsNow,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: _videoController?.value.aspectRatio ?? 16 / 9,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: _buildControls(isFullscreen: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (mounted) setState(() => _isFullscreen = false);
  }

  // ── UI Builders ────────────────────────────────────────────────────────────

  Widget _buildPlayerArea() {
    return Container(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: AspectRatio(
          aspectRatio: _videoController?.value.aspectRatio ?? 16 / 9,
          child: _buildPlayerContent(),
        ),
      ),
    );
  }

  Widget _buildPlayerContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
      );
    }
    if (_error || _videoController == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadVideo,
              child: const Text(
                '加载失败，点击重试',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoPlayer(_videoController!),
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: _buildControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildControls({bool isFullscreen = false}) {
    final controller = _videoController!;
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final duration = value.duration.inSeconds;
        final position = value.position.inSeconds.clamp(0, duration);
        final currentValue = _dragValue ?? position.toDouble();

        return Stack(
          children: [
            // ── Top bar ────────────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(4, 6, 8, 24),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: isFullscreen
                          ? () => Navigator.of(context).maybePop()
                          : () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _showSpeedPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_playbackSpeed}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showShareSheet,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.ios_share_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),

            // ── Center play / pause ────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: () {
                  if (value.isPlaying) {
                    controller.pause();
                    _saveProgress(force: true);
                  } else {
                    controller.play();
                    _startHideTimer();
                  }
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            ),

            // ── Bottom bar ─────────────────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(8, 24, 8, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white30,
                        thumbColor: Colors.white,
                        overlayColor: Colors.white24,
                      ),
                      child: Slider(
                        value: currentValue,
                        min: 0,
                        max: duration.toDouble().clamp(1, double.infinity),
                        onChangeStart: (_) =>
                            setState(() => _dragValue = currentValue),
                        onChanged: (v) => setState(() => _dragValue = v),
                        onChangeEnd: (v) async {
                          await controller.seekTo(Duration(seconds: v.toInt()));
                          setState(() => _dragValue = null);
                          _saveProgress(force: true);
                          _maybeReportPlayEvent();
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 8, 4),
                      child: Row(
                        children: [
                          Text(
                            '${_formatDuration(position)} / ${_formatDuration(duration)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              isFullscreen
                                  ? Icons.fullscreen_exit_rounded
                                  : Icons.fullscreen_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: isFullscreen
                                ? () => Navigator.of(context).maybePop()
                                : _enterFullscreen,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIntroTab() {
    final video = _video;
    if (video == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Title
        Text(
          video.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),

        // Meta badges
        Row(
          children: [
            _metaBadge(
              Icons.access_time_rounded,
              _formatDuration(video.durationSec),
            ),
            const SizedBox(width: 12),
            _metaBadge(Icons.play_lesson_rounded, '第 ${video.sortOrder} 节'),
          ],
        ),

        if (video.description.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF171A21) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '视频简介',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  video.description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _metaBadge(IconData icon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark ? Colors.white54 : Colors.grey.shade500,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F1115)
          : const Color(0xFFF5F6F8),
      body: Column(
        children: [
          _buildPlayerArea(),
          DefaultTabController(
            length: 2,
            child: Expanded(
              child: Column(
                children: [
                  Container(
                    color: isDark ? const Color(0xFF171A21) : Colors.white,
                    child: TabBar(
                      tabs: const [
                        Tab(text: '视频详情'),
                        Tab(text: '评论'),
                      ],
                      labelColor: primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: primary,
                      indicatorSize: TabBarIndicatorSize.label,
                      indicatorWeight: 3,
                      dividerColor: Colors.transparent,
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildIntroTab(),
                        _video == null
                            ? const Center(child: Text('暂无评论'))
                            : CommentsPanel(
                                targetType: 'video',
                                targetId: int.tryParse(_video!.id) ?? 0,
                                embedded: true,
                                showHeader: false,
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
