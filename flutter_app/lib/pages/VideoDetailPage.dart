import 'package:MoocHub/config/Config.dart';
import 'package:MoocHub/model/VideoModel.dart';
import 'package:MoocHub/services/ApiService.dart';
import 'package:MoocHub/widget/CommentsPanel.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoDetailPage extends StatefulWidget {
  final int videoId;

  const VideoDetailPage({super.key, required this.videoId});

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  final ApiService _apiService = ApiService();
  VideoModel? _video;
  bool _loading = true;
  bool _error = false;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
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
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
      );

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

  Widget _buildPlayer() {
    if (_loading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error || _chewieController == null) {
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
      child: Chewie(controller: _chewieController!),
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
