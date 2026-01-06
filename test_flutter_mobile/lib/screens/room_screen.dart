import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';

class RoomScreen extends StatefulWidget {
  final String token;
  final String url;
  final String roomName;
  final String participantName;

  const RoomScreen({
    super.key,
    required this.token,
    required this.url,
    required this.roomName,
    required this.participantName,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with TickerProviderStateMixin {
  Room? _room;
  LocalParticipant? _localParticipant;
  final List<RemoteParticipant> _remoteParticipants = [];
  bool _isConnecting = true;
  bool _showChat = false;
  bool _showParticipants = false;
  final List<ChatMessage> _chatMessages = [];
  final _chatController = TextEditingController();
  EventsListener<RoomEvent>? _listener;

  Timer? _callTimer;
  int _callDuration = 0;

  // PiP - circular and smaller
  Offset _pipOffset = const Offset(16, 100);
  final double _pipSize = 90; // circular size

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _connect();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _listener?.dispose();
    _room?.disconnect();
    _room?.dispose();
    _chatController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _callDuration++);
    });
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _connect() async {
    try {
      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(dtx: true),
          defaultVideoPublishOptions: VideoPublishOptions(simulcast: true),
        ),
      );

      _room = room;
      _listener = room.createListener();
      _setupListeners();

      await room.connect(
        widget.url,
        widget.token,
        fastConnectOptions: FastConnectOptions(
          microphone: const TrackOption(enabled: true),
          camera: const TrackOption(enabled: true),
        ),
      );

      // Sync participants after connection
      _syncParticipants();

      setState(() {
        _localParticipant = room.localParticipant;
        _isConnecting = false;
      });
      _startCallTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _syncParticipants() {
    if (_room == null) return;
    setState(() {
      _remoteParticipants.clear();
      _remoteParticipants.addAll(_room!.remoteParticipants.values);
    });
  }

  void _setupListeners() {
    _listener
      ?..on<ParticipantConnectedEvent>((event) {
        _syncParticipants();
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        _syncParticipants();
      })
      ..on<TrackPublishedEvent>((event) {
        _syncParticipants();
        setState(() {});
      })
      ..on<TrackUnpublishedEvent>((event) => setState(() {}))
      ..on<TrackSubscribedEvent>((event) {
        _syncParticipants();
        setState(() {});
      })
      ..on<TrackUnsubscribedEvent>((event) => setState(() {}))
      ..on<TrackMutedEvent>((event) => setState(() {}))
      ..on<TrackUnmutedEvent>((event) => setState(() {}))
      ..on<LocalTrackPublishedEvent>((event) => setState(() {}))
      ..on<LocalTrackUnpublishedEvent>((event) => setState(() {}))
      ..on<ActiveSpeakersChangedEvent>((event) => setState(() {}))
      ..on<DataReceivedEvent>((event) => _handleDataReceived(event))
      ..on<RoomDisconnectedEvent>((event) {
        if (mounted) Navigator.of(context).pop();
      });
  }

  void _handleDataReceived(DataReceivedEvent event) {
    final message = String.fromCharCodes(event.data);
    final senderName = event.participant?.identity ?? 'Unknown';
    setState(() {
      _chatMessages.add(ChatMessage(
        sender: senderName,
        message: message,
        timestamp: DateTime.now(),
      ));
    });
  }

  Future<void> _sendMessage() async {
    final message = _chatController.text.trim();
    if (message.isEmpty) return;

    try {
      await _localParticipant?.publishData(message.codeUnits, reliable: true);
      setState(() {
        _chatMessages.add(ChatMessage(
          sender: 'You',
          message: message,
          timestamp: DateTime.now(),
        ));
      });
      _chatController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  void _leaveRoom() {
    _room?.disconnect();
    Navigator.of(context).pop();
  }

  VideoTrack? _getVideoTrack(Participant participant) {
    for (final pub in participant.videoTrackPublications) {
      if (pub.subscribed && pub.track != null && !pub.muted) {
        return pub.track as VideoTrack;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnecting) {
      return Scaffold(
        backgroundColor: const Color(0xFF202124),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: Color(0xFF8AB4F8),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Joining meeting...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.roomName,
                style: const TextStyle(
                  color: Color(0xFF9AA0A6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF202124),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // All participants grid (including self)
          _buildParticipantsView(),

          // Top bar
          _buildTopBar(),

          // Bottom controls (Google Meet style)
          _buildBottomBar(),

          // Chat panel
          if (_showChat) _buildChatPanel(),

          // Participants panel
          if (_showParticipants) _buildParticipantsPanel(),
        ],
      ),
    );
  }

  int get _totalParticipants {
    int count = _localParticipant != null ? 1 : 0;
    count += _remoteParticipants.length;
    return count;
  }

  Widget _buildParticipantsView() {
    final totalCount = _totalParticipants;

    // Only me - show waiting screen
    if (_remoteParticipants.isEmpty) {
      return Container(
        color: const Color(0xFF202124),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF3C4043),
                ),
                child: Center(
                  child: Text(
                    _getInitials(widget.participantName),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFE8EAED),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Waiting for others to join',
                style: TextStyle(
                  color: Color(0xFFE8EAED),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDuration(_callDuration),
                style: const TextStyle(
                  color: Color(0xFF9AA0A6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Build grid with all participants including self
    return _buildGridView(totalCount);
  }

  Widget _buildGridView(int totalCount) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxTileHeight = screenHeight / 2;

    // Calculate grid layout
    int crossAxisCount;
    if (totalCount == 2) {
      crossAxisCount = 2; // Side by side
    } else if (totalCount <= 4) {
      crossAxisCount = 2; // 2x2
    } else {
      crossAxisCount = 2; // 2 columns for more
    }

    final tileWidth = (screenWidth - 24) / crossAxisCount;
    final tileHeight = (tileWidth * 4 / 3).clamp(0.0, maxTileHeight).toDouble();
    final rowCount = (totalCount / crossAxisCount).ceil();
    final totalHeight = (tileHeight * rowCount) + (8 * (rowCount - 1));

    return Container(
      color: const Color(0xFF202124),
      height: screenHeight,
      child: Center(
        child: SizedBox(
          // height: totalHeight.clamp(0.0, screenHeight - 120).toDouble(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: tileWidth / tileHeight,
              ),
              itemCount: totalCount,
              itemBuilder: (context, index) {
                // First tile is local participant
                if (index == 0 && _localParticipant != null) {
                  return _buildLocalTile();
                }
                // Remote participants
                final remoteIndex = index - 1;
                if (remoteIndex < _remoteParticipants.length) {
                  return _buildRemoteTile(_remoteParticipants[remoteIndex]);
                }
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocalTile() {
    final videoTrack = _localParticipant != null ? _getVideoTrack(_localParticipant!) : null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3C4043),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8AB4F8),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (videoTrack != null)
              VideoTrackRenderer(
                videoTrack,
                mirrorMode: VideoViewMirrorMode.mirror,
              )
            else
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF5F6368),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(widget.participantName),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFE8EAED),
                      ),
                    ),
                  ),
                ),
              ),
            // Name label
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isMicEnabled())
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.mic_off,
                          color: Color(0xFFF28B82),
                          size: 14,
                        ),
                      ),
                    const Flexible(
                      child: Text(
                        'You',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteTile(RemoteParticipant participant) {
    final videoTrack = _getVideoTrack(participant);
    final isSpeaking = participant.isSpeaking;

    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 13, 125, 211),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSpeaking ? const Color(0xFF8AB4F8) : Colors.transparent,
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (videoTrack != null)
              VideoTrackRenderer(videoTrack)
            else
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF5F6368),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(participant.identity),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFE8EAED),
                      ),
                    ),
                  ),
                ),
              ),
            // Name label
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isParticipantMicOn(participant))
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.mic_off,
                          color: Color(0xFFF28B82),
                          size: 14,
                        ),
                      ),
                    Flexible(
                      child: Text(
                        participant.identity,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.6),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Meeting info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.roomName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDuration(_callDuration),
                        style: const TextStyle(
                          color: Color(0xFFADADAD),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Participant count
                GestureDetector(
                  onTap: () => setState(() => _showParticipants = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '$_totalParticipants',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Actions
                _buildTopButton(Icons.flip_camera_ios_rounded, _switchCamera),
                const SizedBox(width: 8),
                _buildTopButton(Icons.volume_up_rounded, _toggleSpeaker),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildLocalPiP() {
    if (_localParticipant == null) return const SizedBox();

    final videoTrack = _getVideoTrack(_localParticipant!);
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: _pipOffset.dx,
      top: _pipOffset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            double newX = _pipOffset.dx + details.delta.dx;
            double newY = _pipOffset.dy + details.delta.dy;
            newX = newX.clamp(12, screenSize.width - _pipSize - 12);
            newY = newY.clamp(
              MediaQuery.of(context).padding.top + 60,
              screenSize.height - _pipSize - 100 - bottomPadding,
            );
            _pipOffset = Offset(newX, newY);
          });
        },
        onPanEnd: (details) {
          // Snap to nearest edge
          final screenWidth = screenSize.width;
          final centerX = _pipOffset.dx + _pipSize / 2;
          setState(() {
            if (centerX < screenWidth / 2) {
              _pipOffset = Offset(12, _pipOffset.dy);
            } else {
              _pipOffset = Offset(screenWidth - _pipSize - 12, _pipOffset.dy);
            }
          });
        },
        child: Container(
          width: _pipSize,
          height: _pipSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF8AB4F8),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (videoTrack != null)
                  VideoTrackRenderer(
                    videoTrack,
                    mirrorMode: VideoViewMirrorMode.mirror,
                  )
                else
                  Container(
                    color: const Color(0xFF3C4043),
                    child: Center(
                      child: Text(
                        _getInitials(widget.participantName),
                        style: const TextStyle(
                          color: Color(0xFFE8EAED),
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                // Mic indicator at bottom
                if (!_isMicEnabled())
                  Positioned(
                    bottom: 4,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF28B82),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mic_off,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  icon: _isMicEnabled() ? Icons.mic_rounded : Icons.mic_off_rounded,
                  isActive: _isMicEnabled(),
                  onTap: _toggleMicrophone,
                ),
                _buildControlButton(
                  icon: _isCameraEnabled()
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
                  isActive: _isCameraEnabled(),
                  onTap: _toggleCamera,
                ),
                _buildEndCallButton(),
                _buildControlButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  isActive: true,
                  onTap: () => setState(() => _showChat = !_showChat),
                  badgeCount: 0,
                ),
                _buildControlButton(
                  icon: Icons.more_vert_rounded,
                  isActive: true,
                  onTap: _showMoreOptions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? const Color(0xFF3C4043)
                : const Color(0xFFF28B82),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1A73E8),
                    ),
                    child: Center(
                      child: Text(
                        badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndCallButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _leaveRoom,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFEA4335),
          ),
          child: const Icon(
            Icons.call_end_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2E30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF5F6368),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _buildOptionItem(
                Icons.screen_share_rounded,
                'Share screen',
                _toggleScreenShare,
              ),
              _buildOptionItem(
                Icons.people_outline_rounded,
                'Participants ($_totalParticipants)',
                () => setState(() => _showParticipants = true),
              ),
              _buildOptionItem(
                Icons.info_outline_rounded,
                'Meeting details',
                () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFE8EAED)),
      title: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFE8EAED),
          fontSize: 16,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _buildChatPanel() {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: MediaQuery.of(context).size.width * 0.85,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF202124),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF3C4043)),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      'In-call messages',
                      style: TextStyle(
                        color: Color(0xFFE8EAED),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFFE8EAED)),
                      onPressed: () => setState(() => _showChat = false),
                    ),
                  ],
                ),
              ),
              // Messages
              Expanded(
                child: _chatMessages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 48,
                              color: const Color(0xFF5F6368),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No messages yet',
                              style: TextStyle(
                                color: Color(0xFF9AA0A6),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _chatMessages.length,
                        itemBuilder: (context, index) {
                          final msg = _chatMessages[index];
                          final isMe = msg.sender == 'You';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isMe
                                        ? const Color(0xFF1A73E8)
                                        : const Color(0xFF5F6368),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _getInitials(msg.sender),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            msg.sender,
                                            style: const TextStyle(
                                              color: Color(0xFFE8EAED),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatTime(msg.timestamp),
                                            style: const TextStyle(
                                              color: Color(0xFF9AA0A6),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        msg.message,
                                        style: const TextStyle(
                                          color: Color(0xFFE8EAED),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              // Input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFF3C4043)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF3C4043),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _chatController,
                          style: const TextStyle(color: Color(0xFFE8EAED)),
                          decoration: const InputDecoration(
                            hintText: 'Send a message',
                            hintStyle: TextStyle(color: Color(0xFF9AA0A6)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: const Color(0xFF8AB4F8),
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        onTap: _sendMessage,
                        borderRadius: BorderRadius.circular(24),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.send_rounded,
                            color: Color(0xFF202124),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantsPanel() {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: MediaQuery.of(context).size.width * 0.85,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF202124),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF3C4043)),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Participants ($_totalParticipants)',
                      style: const TextStyle(
                        color: Color(0xFFE8EAED),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFFE8EAED)),
                      onPressed: () => setState(() => _showParticipants = false),
                    ),
                  ],
                ),
              ),
              // Participants list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    // Local participant (You)
                    if (_localParticipant != null)
                      _buildParticipantItem(
                        name: '${widget.participantName} (You)',
                        isMicOn: _isMicEnabled(),
                        isCameraOn: _isCameraEnabled(),
                        isLocal: true,
                      ),
                    // Remote participants
                    ..._remoteParticipants.map((p) => _buildParticipantItem(
                          name: p.identity,
                          isMicOn: _isParticipantMicOn(p),
                          isCameraOn: _isParticipantCameraOn(p),
                          isLocal: false,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantItem({
    required String name,
    required bool isMicOn,
    required bool isCameraOn,
    required bool isLocal,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF3C4043).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLocal ? const Color(0xFF1A73E8) : const Color(0xFF5F6368),
            ),
            child: Center(
              child: Text(
                _getInitials(name.replaceAll(' (You)', '')),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Color(0xFFE8EAED),
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            color: isMicOn ? const Color(0xFF8AB4F8) : const Color(0xFFF28B82),
            size: 20,
          ),
          const SizedBox(width: 12),
          Icon(
            isCameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            color: isCameraOn ? const Color(0xFF8AB4F8) : const Color(0xFFF28B82),
            size: 20,
          ),
        ],
      ),
    );
  }

  bool _isParticipantMicOn(Participant participant) {
    for (final pub in participant.audioTrackPublications) {
      if (!pub.muted && pub.track != null) return true;
    }
    return false;
  }

  bool _isParticipantCameraOn(Participant participant) {
    for (final pub in participant.videoTrackPublications) {
      if (!pub.muted && pub.track != null) return true;
    }
    return false;
  }

  // Helper methods
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  bool _isMicEnabled() => _localParticipant?.isMicrophoneEnabled() ?? false;
  bool _isCameraEnabled() => _localParticipant?.isCameraEnabled() ?? false;

  Future<void> _toggleMicrophone() async {
    await _localParticipant?.setMicrophoneEnabled(!_isMicEnabled());
    setState(() {});
  }

  Future<void> _toggleCamera() async {
    await _localParticipant?.setCameraEnabled(!_isCameraEnabled());
    setState(() {});
  }

  Future<void> _toggleScreenShare() async {
    await _localParticipant?.setScreenShareEnabled(
      !(_localParticipant?.isScreenShareEnabled() ?? false),
    );
    setState(() {});
  }

  Future<void> _toggleSpeaker() async {
    final currentSpeaker = _room?.speakerOn ?? true;
    await _room?.setSpeakerOn(!currentSpeaker);
    setState(() {});
  }

  Future<void> _switchCamera() async {
    final track = _localParticipant?.videoTrackPublications.firstOrNull?.track;
    if (track is LocalVideoTrack) {
      final devices = await Hardware.instance.enumerateDevices();
      final videoDevices =
          devices.where((d) => d.kind == 'videoinput').toList();
      if (videoDevices.length > 1) {
        final currentDeviceId = track.currentOptions.deviceId;
        final nextDevice = videoDevices.firstWhere(
          (d) => d.deviceId != currentDeviceId,
          orElse: () => videoDevices.first,
        );
        await track.restartTrack(CameraCaptureOptions(
          deviceId: nextDevice.deviceId,
        ));
      }
    }
  }
}

class ChatMessage {
  final String sender;
  final String message;
  final DateTime timestamp;

  ChatMessage({
    required this.sender,
    required this.message,
    required this.timestamp,
  });
}
