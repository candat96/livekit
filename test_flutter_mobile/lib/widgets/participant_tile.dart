import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class ParticipantTile extends StatelessWidget {
  final Participant participant;
  final VideoTrack? videoTrack;
  final bool isLocal;

  const ParticipantTile({
    super.key,
    required this.participant,
    this.videoTrack,
    this.isLocal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: participant.isSpeaking ? Colors.green : Colors.transparent,
          width: 3,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (videoTrack != null)
              VideoTrackRenderer(
                videoTrack!,
                mirrorMode: isLocal
                    ? VideoViewMirrorMode.mirror
                    : VideoViewMirrorMode.off,
              )
            else
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.deepPurple,
                  child: Text(
                    _getInitials(participant.identity),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isMicMuted())
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.mic_off,
                          size: 16,
                          color: Colors.red,
                        ),
                      ),
                    Text(
                      isLocal ? 'You' : participant.identity,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (participant.connectionQuality != ConnectionQuality.unknown)
              Positioned(
                right: 8,
                top: 8,
                child: _buildConnectionQualityIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  bool _isMicMuted() {
    for (final pub in participant.audioTrackPublications) {
      if (pub.muted) return true;
    }
    return false;
  }

  Widget _buildConnectionQualityIndicator() {
    IconData icon;
    Color color;

    switch (participant.connectionQuality) {
      case ConnectionQuality.excellent:
        icon = Icons.signal_cellular_4_bar;
        color = Colors.green;
        break;
      case ConnectionQuality.good:
        icon = Icons.signal_cellular_alt;
        color = Colors.yellow;
        break;
      case ConnectionQuality.poor:
        icon = Icons.signal_cellular_alt_1_bar;
        color = Colors.red;
        break;
      default:
        icon = Icons.signal_cellular_0_bar;
        color = Colors.grey;
    }

    return Icon(icon, size: 16, color: color);
  }
}
