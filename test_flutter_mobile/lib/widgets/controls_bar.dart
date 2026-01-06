import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class ControlsBar extends StatelessWidget {
  final Room room;
  final LocalParticipant localParticipant;
  final VoidCallback onLeave;
  final VoidCallback onToggleChat;
  final VoidCallback onToggleParticipants;

  const ControlsBar({
    super.key,
    required this.room,
    required this.localParticipant,
    required this.onLeave,
    required this.onToggleChat,
    required this.onToggleParticipants,
  });

  bool get _isMicEnabled {
    return localParticipant.isMicrophoneEnabled();
  }

  bool get _isCameraEnabled {
    return localParticipant.isCameraEnabled();
  }

  bool get _isScreenShareEnabled {
    return localParticipant.isScreenShareEnabled();
  }

  bool get _isSpeakerOn {
    return room.speakerOn ?? true;
  }

  Future<void> _toggleMicrophone() async {
    await localParticipant.setMicrophoneEnabled(!_isMicEnabled);
  }

  Future<void> _toggleCamera() async {
    await localParticipant.setCameraEnabled(!_isCameraEnabled);
  }

  Future<void> _switchCamera() async {
    final track = localParticipant.videoTrackPublications.firstOrNull?.track;
    if (track is LocalVideoTrack) {
      final devices = await Hardware.instance.enumerateDevices();
      final videoDevices = devices.where((d) => d.kind == 'videoinput').toList();
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

  Future<void> _toggleScreenShare() async {
    await localParticipant.setScreenShareEnabled(!_isScreenShareEnabled);
  }

  Future<void> _toggleSpeaker() async {
    await room.setSpeakerOn(!_isSpeakerOn);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: _isMicEnabled ? Icons.mic : Icons.mic_off,
            label: 'Mic',
            isActive: _isMicEnabled,
            onPressed: _toggleMicrophone,
          ),
          _ControlButton(
            icon: _isCameraEnabled ? Icons.videocam : Icons.videocam_off,
            label: 'Camera',
            isActive: _isCameraEnabled,
            onPressed: _toggleCamera,
          ),
          _ControlButton(
            icon: Icons.cameraswitch,
            label: 'Flip',
            isActive: true,
            onPressed: _isCameraEnabled ? _switchCamera : null,
          ),
          _ControlButton(
            icon: _isSpeakerOn ? Icons.volume_up : Icons.hearing,
            label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
            isActive: true,
            onPressed: _toggleSpeaker,
          ),
          _ControlButton(
            icon: Icons.screen_share,
            label: 'Share',
            isActive: _isScreenShareEnabled,
            activeColor: Colors.green,
            onPressed: _toggleScreenShare,
          ),
          _ControlButton(
            icon: Icons.chat,
            label: 'Chat',
            isActive: true,
            onPressed: onToggleChat,
          ),
          _ControlButton(
            icon: Icons.people,
            label: 'People',
            isActive: true,
            onPressed: onToggleParticipants,
          ),
          _ControlButton(
            icon: Icons.call_end,
            label: 'Leave',
            isActive: true,
            activeColor: Colors.red,
            onPressed: onLeave,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback? onPressed;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    this.activeColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null
        ? Colors.grey
        : isActive
            ? (activeColor ?? Colors.white)
            : Colors.red;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
