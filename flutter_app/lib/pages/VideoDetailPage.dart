import 'dart:async';
import 'package:MoocHub/config/Config.dart';
import 'package:MoocHub/model/VideoModel.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/services/StorageService.dart';
import 'package:MoocHub/widget/CommentsPanel.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _hideTimer?.cancel();
    _saveProgress(force: true);
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final token = await _storageService.getUserToken();
    _loggedIn = token != null && token.toString().isNotEmpty && token != 'null';
    if (mounted) {
      setState(() {});
    }
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
      if (raw is! Map<String, dynamic>) {
        throw Exception('video data invalid');
      }

      final video = VideoModel.fromJson(raw);
      final url = Config.resolveImage(video.videoUrl);
      if (url.isEmpty) {
        throw Exception('video url empty');
      }

      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoController!.initialize();
      await _videoController!.setPlaybackSpeed(_playbackSpeed);
      _videoController!.addListener(_handlePlayerUpdate);

      if (_loggedIn) {
        await _loadProgress();
      }

      _startProgressTimer();

      if (mounted) {
        setState(() {
          _video = video;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveProgress();
    });
  }

  void _handlePlayerUpdate() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (!controller.value.isPlaying) {
      _saveProgress();
    }
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
      final diff = now.difference(_lastProgressSentAt!);
      if (diff.inSeconds < 5) return;
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
    } catch (_) {
      // ignore
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
      if (controller != null && controller.value.isInitialized && lastSeconds > 0) {
        final duration = controller.value.duration.inSeconds;
        if (lastSeconds < duration) {
          await controller.seekTo(Duration(seconds: lastSeconds));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已为你续播至 ${_formatDuration(lastSeconds)}')),
            );
          }
        }
      }
    } catch (_) {
      // ignore
    }
  }

  void _showControlsNow() {
    if (!_showControls) {
      setState(() {
        _showControls = true;
      });
    }
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  Future<void> _showSpeedPicker() async {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final selected = await showModalBottomSheet<double>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: speeds
                .map(
                  (speed) => ListTile(
                    title: Text('${speed}x'),
                    trailing: speed == _playbackSpeed
                        ? const Icon(Icons.check, color: Colors.teal)
                        : null,
                    onTap: () => Navigator.pop(context, speed),
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (selected != null) {
      final controller = _videoController;
      if (controller != null) {
        await controller.setPlaybackSpeed(selected);
      }
      if (mounted) {
        setState(() {
          _playbackSpeed = selected;
        });
      }
    }
  }

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('播放设置'),
              ),
              ListTile(
                title: const Text('倍速'),
                subtitle: Text('${_playbackSpeed}x'),
                trailing: const Icon(Icons.speed),
                onTap: () async {
                  Navigator.pop(context);
                  await _showSpeedPicker();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _enterFullscreen() async {
    if (_videoController == null || _isFullscreen) return;
    setState(() {
      _isFullscreen = true;
    });
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: GestureDetector(
                onTap: _showControlsNow,
                behavior: HitTestBehavior.opaque,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: AspectRatio(
                        aspectRatio:
                            _videoController?.value.aspectRatio ?? 16 / 9,
                        child: IgnorePointer(
                          ignoring: true,
                          child: VideoPlayer(_videoController!),
                        ),
                      ),
                    ),
                    if (_showControls) _buildControls(isFullscreen: true),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (mounted) {
      setState(() {
        _isFullscreen = false;
      });
    }
  }

  Widget _buildPlayer() {
    if (_loading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error || _videoController == null) {
      return SizedBox(
        height: 220,
        child: Center(
          child: TextButton(
            onPressed: _loadVideo,
            child: const Text('加载失败，点击重试'),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _videoController?.value.aspectRatio ?? 16 / 9,
      child: GestureDetector(
        onTap: _showControlsNow,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            IgnorePointer(
              ignoring: true,
              child: VideoPlayer(_videoController!),
            ),
            if (_showControls) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls({bool isFullscreen = false}) {
    final controller = _videoController!;
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final duration = value.duration.inSeconds;
        final position = value.position.inSeconds.clamp(0, duration);
        final currentValue = _dragValue ?? position.toDouble();

        return Container(
          color: Colors.black38,
          child: Column(
            children: [
              if (isFullscreen)
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              if (!isFullscreen)
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: _showSettings,
                  ),
                ),
              const Spacer(),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (value.isPlaying) {
                        controller.pause();
                        _saveProgress(force: true);
                      } else {
                        controller.play();
                        _startHideTimer();
                      }
                      setState(() {});
                    },
                  ),
                  Text(
                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.fullscreen, color: Colors.white),
                    onPressed: _enterFullscreen,
                  ),
                ],
              ),
              Slider(
                value: currentValue,
                min: 0,
                max: duration.toDouble().clamp(1, double.infinity),
                onChangeStart: (_) {
                  setState(() {
                    _dragValue = currentValue;
                  });
                },
                onChanged: (value) {
                  setState(() {
                    _dragValue = value;
                  });
                },
                onChangeEnd: (value) async {
                  await controller.seekTo(Duration(seconds: value.toInt()));
                  setState(() {
                    _dragValue = null;
                  });
                  _saveProgress(force: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfo() {
    final video = _video;
    if (video == null) {
      return const SizedBox.shrink();
    }
    final thumb = Config.resolveImage(video.thumbUrl);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            video.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: thumb.isEmpty
                      ? 'https://picsum.photos/seed/v${video.id}/160/90'
                      : thumb,
                  width: 120,
                  height: 68,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    width: 120,
                    height: 68,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.play_circle_outline),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  video.description.isEmpty ? '暂无描述' : video.description,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('时长', _formatDuration(video.durationSec)),
              _pill('课程ID', video.courseId),
              _pill('视频ID', video.id),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    final m = minutes.toString().padLeft(2, '0');
    final s = remaining.toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('视频播放')),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            _buildPlayer(),
            const TabBar(
              tabs: [
                Tab(text: '视频详情'),
                Tab(text: '评论'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(children: [_buildInfo()]),
                  if (_video == null)
                    const Center(child: Text('暂无评论'))
                  else
                    CommentsPanel(
                      targetType: 'video',
                      targetId: int.tryParse(_video!.id) ?? 0,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
