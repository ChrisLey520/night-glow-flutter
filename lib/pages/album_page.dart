import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

class AlbumPage extends StatefulWidget {
  const AlbumPage({super.key});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  List<AssetEntity> _assets = [];
  bool _loading = true;
  bool _denied = false;

  bool _multiSelect = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  Future<void> _load({bool initial = false}) async {
    if (initial) {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        if (mounted) setState(() { _loading = false; _denied = true; });
        return;
      }
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      filterOption: FilterOptionGroup(orders: [
        const OrderOption(type: OrderOptionType.createDate, asc: false),
      ]),
    );
    if (!mounted) return;
    if (albums.isEmpty) {
      setState(() { _assets = []; _loading = false; });
      return;
    }
    final assets = await albums.first.getAssetListRange(start: 0, end: 300);
    if (mounted) setState(() { _assets = assets; _loading = false; });
  }

  void _enterMultiSelect(String id) {
    setState(() {
      _multiSelect = true;
      _selectedIds.add(id);
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _multiSelect = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedIds.toList();
    // deleteWithIds shows the iOS system confirmation internally;
    // it returns the IDs that were actually deleted (empty if cancelled).
    final deleted = await PhotoManager.editor.deleteWithIds(ids);
    if (!mounted || deleted.isEmpty) return;
    setState(() {
      _multiSelect = false;
      _selectedIds.clear();
    });
    await _load();
  }

  Future<void> _onViewerDeleted() async {
    // Reload from photo_manager so the list reflects reality,
    // avoiding stale thumbnails caused by local-array filtering.
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: _multiSelect
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _exitMultiSelect,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: _multiSelect
            ? Text(
                _selectedIds.isEmpty ? '选择照片' : '已选 ${_selectedIds.length} 张',
                style: const TextStyle(color: Colors.white, fontSize: 17),
              )
            : const Text('相册',
                style: TextStyle(color: Colors.white, fontSize: 17)),
        actions: [
          if (_multiSelect && _selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _deleteSelected,
            ),
          if (_multiSelect)
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedIds.length == _assets.length) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds
                      ..clear()
                      ..addAll(_assets.map((a) => a.id));
                  }
                });
              },
              child: Text(
                _selectedIds.length == _assets.length ? '取消全选' : '全选',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white54));
    }
    if (_denied) {
      return const Center(
        child: Text('请在设置中允许访问相册',
            style: TextStyle(color: Colors.white54, fontSize: 15)),
      );
    }
    if (_assets.isEmpty) {
      return const Center(
        child: Text('相册为空',
            style: TextStyle(color: Colors.white54, fontSize: 15)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _assets.length,
      itemBuilder: (ctx, i) => _Thumbnail(
        asset: _assets[i],
        multiSelect: _multiSelect,
        selected: _selectedIds.contains(_assets[i].id),
        onTap: () {
          if (_multiSelect) {
            _toggleSelect(_assets[i].id);
            return;
          }
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              barrierColor: Colors.black,
              pageBuilder: (ctx, a1, a2) => _MediaViewerPage(
                asset: _assets[i],
                onDeleted: _onViewerDeleted,
              ),
              transitionsBuilder: (ctx, anim, secAnim, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 200),
              reverseTransitionDuration: const Duration(milliseconds: 150),
            ),
          );
        },
        onLongPress: () {
          if (!_multiSelect) _enterMultiSelect(_assets[i].id);
        },
      ),
    );
  }
}

// ── Thumbnail ─────────────────────────────────────────────────────────────────

class _Thumbnail extends StatefulWidget {
  final AssetEntity asset;
  final bool multiSelect;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _Thumbnail({
    required this.asset,
    required this.multiSelect,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    widget.asset
        .thumbnailDataWithSize(const ThumbnailSize(300, 300))
        .then((data) {
      if (mounted && data != null) setState(() => _thumb = data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Container(
        color: Colors.grey[900],
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_thumb != null)
              Image.memory(_thumb!, fit: BoxFit.cover)
            else
              const Center(
                  child: Icon(Icons.image, color: Colors.white12, size: 28)),
            if (widget.asset.type == AssetType.video && _thumb != null)
              const Positioned(
                right: 4,
                bottom: 4,
                child: Icon(Icons.play_circle_fill,
                    color: Colors.white70, size: 20),
              ),
            if (widget.multiSelect)
              Positioned.fill(
                child: Container(
                  color: widget.selected
                      ? Colors.blue.withValues(alpha: 0.35)
                      : Colors.transparent,
                ),
              ),
            if (widget.multiSelect)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.selected
                        ? Colors.blue
                        : Colors.black.withValues(alpha: 0.4),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: widget.selected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Media viewer ──────────────────────────────────────────────────────────────

class _MediaViewerPage extends StatefulWidget {
  final AssetEntity asset;
  final Future<void> Function() onDeleted;

  const _MediaViewerPage({
    required this.asset,
    required this.onDeleted,
  });

  @override
  State<_MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<_MediaViewerPage> {
  Uint8List? _imageBytes;
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  bool _deleting = false;

  bool get _isVideo => widget.asset.type == AssetType.video;

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      _initVideo();
    } else {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final file = await widget.asset.file;
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _imageBytes = bytes);
  }

  Future<void> _initVideo() async {
    final file = await widget.asset.file;
    if (file == null || !mounted) return;
    final ctrl = VideoPlayerController.file(file);
    await ctrl.initialize();
    if (!mounted) { ctrl.dispose(); return; }
    setState(() { _videoCtrl = ctrl; _videoReady = true; });
    ctrl.setLooping(true);
    ctrl.play();
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    // deleteWithIds shows the iOS system confirmation internally.
    // Returns the IDs that were actually deleted; empty means cancelled.
    final deleted =
        await PhotoManager.editor.deleteWithIds([widget.asset.id]);
    if (!mounted) return;
    if (deleted.isEmpty) {
      setState(() => _deleting = false);
      return;
    }
    await widget.onDeleted();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: _buildContent()),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: _deleting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white54))
                : IconButton(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent, size: 26),
                  ),
          ),
          if (_isVideo && _videoReady)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _videoCtrl!.value.isPlaying
                        ? _videoCtrl!.pause()
                        : _videoCtrl!.play();
                  }),
                  child: Icon(
                    _videoCtrl!.value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.white70,
                    size: 56,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isVideo) {
      if (!_videoReady) {
        return const CircularProgressIndicator(color: Colors.white54);
      }
      return AspectRatio(
        aspectRatio: _videoCtrl!.value.aspectRatio,
        child: VideoPlayer(_videoCtrl!),
      );
    }
    if (_imageBytes == null) {
      return const CircularProgressIndicator(color: Colors.white54);
    }
    return InteractiveViewer(
      child: Image.memory(_imageBytes!, fit: BoxFit.contain),
    );
  }
}
