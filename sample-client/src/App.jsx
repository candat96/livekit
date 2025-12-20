import { useState, useRef, useEffect } from 'react';
import { Room, RoomEvent, VideoPresets } from 'livekit-client';

const styles = {
  container: {
    maxWidth: '1200px',
    margin: '0 auto',
    padding: '20px',
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
    background: '#1a1a2e',
    minHeight: '100vh',
    color: '#fff',
  },
  title: {
    textAlign: 'center',
    marginBottom: '20px',
    color: '#00d9ff',
  },
  configPanel: {
    background: '#16213e',
    padding: '20px',
    borderRadius: '10px',
    marginBottom: '20px',
  },
  formGroup: {
    marginBottom: '15px',
  },
  label: {
    display: 'block',
    marginBottom: '5px',
    color: '#a0a0a0',
  },
  input: {
    width: '100%',
    padding: '10px',
    border: '1px solid #333',
    borderRadius: '5px',
    background: '#0f0f23',
    color: '#fff',
    fontSize: '14px',
    boxSizing: 'border-box',
  },
  btnPrimary: {
    padding: '12px 24px',
    border: 'none',
    borderRadius: '5px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: 'bold',
    marginRight: '10px',
    marginBottom: '10px',
    background: '#00d9ff',
    color: '#000',
  },
  btnDanger: {
    padding: '12px 24px',
    border: 'none',
    borderRadius: '5px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: 'bold',
    marginRight: '10px',
    marginBottom: '10px',
    background: '#ff4757',
    color: '#fff',
  },
  btnSuccess: {
    padding: '12px 24px',
    border: 'none',
    borderRadius: '5px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: 'bold',
    marginRight: '10px',
    marginBottom: '10px',
    background: '#2ed573',
    color: '#000',
  },
  btnDisabled: {
    opacity: 0.5,
    cursor: 'not-allowed',
  },
  status: {
    padding: '10px',
    borderRadius: '5px',
    marginBottom: '20px',
    textAlign: 'center',
  },
  statusConnected: {
    background: '#2ed57333',
    color: '#2ed573',
  },
  statusDisconnected: {
    background: '#ff475733',
    color: '#ff4757',
  },
  statusConnecting: {
    background: '#ffa50233',
    color: '#ffa502',
  },
  videoGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(480px, 1fr))',
    gap: '20px',
    marginTop: '20px',
  },
  videoContainer: {
    background: '#16213e',
    borderRadius: '10px',
    overflow: 'hidden',
    position: 'relative',
  },
  video: {
    width: '100%',
    height: '480px',
    objectFit: 'cover',
    background: '#000',
  },
  videoLabel: {
    position: 'absolute',
    bottom: '10px',
    left: '10px',
    background: 'rgba(0,0,0,0.7)',
    padding: '5px 10px',
    borderRadius: '5px',
    fontSize: '12px',
  },
  controls: {
    marginTop: '20px',
    textAlign: 'center',
  },
  logPanel: {
    background: '#0f0f23',
    borderRadius: '10px',
    padding: '15px',
    marginTop: '20px',
    maxHeight: '200px',
    overflowY: 'auto',
    fontFamily: 'monospace',
    fontSize: '12px',
  },
  logEntry: {
    padding: '3px 0',
    borderBottom: '1px solid #222',
  },
};

function App() {
  const [roomName, setRoomName] = useState('test-room');
  const [participantName, setParticipantName] = useState('user-' + Math.random().toString(36).substring(7));
  const [connectionStatus, setConnectionStatus] = useState('disconnected');
  const [logs, setLogs] = useState([{ message: 'Ready to connect...', type: 'info' }]);
  const [participants, setParticipants] = useState([]);
  const [isCameraEnabled, setIsCameraEnabled] = useState(false);
  const [isMicEnabled, setIsMicEnabled] = useState(false);

  const roomRef = useRef(null);
  const localVideoRef = useRef(null);

  const addLog = (message, type = 'info') => {
    const time = new Date().toLocaleTimeString();
    setLogs(prev => [...prev, { message: `[${time}] ${message}`, type }]);
  };

  const handleConnect = async () => {
    try {
      setConnectionStatus('connecting');
      addLog('Generating token...', 'info');

      // Call server to generate token
      const response = await fetch('/api/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ roomName, participantName }),
      });

      if (!response.ok) {
        throw new Error('Failed to generate token');
      }

      const { token, livekitUrl } = await response.json();
      addLog(`Token generated successfully`, 'success');

      // Create and connect room
      const room = new Room({
        adaptiveStream: true,
        dynacast: true,
        videoCaptureDefaults: {
          resolution: VideoPresets.h720.resolution,
        },
      });

      roomRef.current = room;

      // Setup event listeners
      room.on(RoomEvent.Connected, () => {
        addLog(`Connected to room: ${roomName}`, 'success');
        setConnectionStatus('connected');
      });

      room.on(RoomEvent.Disconnected, () => {
        addLog('Disconnected from room', 'warn');
        setConnectionStatus('disconnected');
        setParticipants([]);
      });

      room.on(RoomEvent.ParticipantConnected, (participant) => {
        addLog(`Participant joined: ${participant.identity}`, 'info');
        updateParticipants();
      });

      room.on(RoomEvent.ParticipantDisconnected, (participant) => {
        addLog(`Participant left: ${participant.identity}`, 'warn');
        updateParticipants();
      });

      room.on(RoomEvent.TrackSubscribed, (track, publication, participant) => {
        addLog(`Subscribed to ${track.kind} from ${participant.identity}`, 'info');
        updateParticipants();
      });

      room.on(RoomEvent.TrackUnsubscribed, (track, publication, participant) => {
        addLog(`Unsubscribed from ${track.kind} of ${participant.identity}`, 'info');
        updateParticipants();
      });

      addLog(`Connecting to ${livekitUrl}...`, 'info');
      await room.connect(livekitUrl, token);

      updateParticipants();

    } catch (error) {
      console.error('Connection error:', error);
      addLog(`Connection error: ${error.message}`, 'error');
      setConnectionStatus('disconnected');
    }
  };

  const updateParticipants = () => {
    if (!roomRef.current) return;

    const room = roomRef.current;
    const allParticipants = [room.localParticipant, ...Array.from(room.remoteParticipants.values())];
    setParticipants(allParticipants.map(p => ({
      identity: p.identity,
      isLocal: p === room.localParticipant,
      videoTrack: p.getTrackPublication('camera')?.track,
      audioTrack: p.getTrackPublication('microphone')?.track,
    })));
  };

  const handleDisconnect = async () => {
    if (roomRef.current) {
      await roomRef.current.disconnect();
      roomRef.current = null;
      setIsCameraEnabled(false);
      setIsMicEnabled(false);
    }
  };

  const toggleCamera = async () => {
    if (!roomRef.current) return;

    try {
      if (isCameraEnabled) {
        await roomRef.current.localParticipant.setCameraEnabled(false);
        addLog('Camera disabled', 'info');
      } else {
        await roomRef.current.localParticipant.setCameraEnabled(true);
        addLog('Camera enabled', 'success');
      }
      setIsCameraEnabled(!isCameraEnabled);
      updateParticipants();
    } catch (error) {
      addLog(`Camera error: ${error.message}`, 'error');
    }
  };

  const toggleMic = async () => {
    if (!roomRef.current) return;

    try {
      if (isMicEnabled) {
        await roomRef.current.localParticipant.setMicrophoneEnabled(false);
        addLog('Microphone disabled', 'info');
      } else {
        await roomRef.current.localParticipant.setMicrophoneEnabled(true);
        addLog('Microphone enabled', 'success');
      }
      setIsMicEnabled(!isMicEnabled);
    } catch (error) {
      addLog(`Microphone error: ${error.message}`, 'error');
    }
  };

  const getStatusStyle = () => {
    switch (connectionStatus) {
      case 'connected':
        return { ...styles.status, ...styles.statusConnected };
      case 'connecting':
        return { ...styles.status, ...styles.statusConnecting };
      default:
        return { ...styles.status, ...styles.statusDisconnected };
    }
  };

  const getStatusText = () => {
    switch (connectionStatus) {
      case 'connected':
        return 'Connected';
      case 'connecting':
        return 'Connecting...';
      default:
        return 'Disconnected';
    }
  };

  const getLogColor = (type) => {
    switch (type) {
      case 'success': return '#2ed573';
      case 'error': return '#ff4757';
      case 'warn': return '#ffa502';
      default: return '#00d9ff';
    }
  };

  return (
    <div style={styles.container}>
      <h1 style={styles.title}>LiveKit React Client</h1>

      <div style={styles.configPanel}>
        <div style={styles.formGroup}>
          <label style={styles.label}>Room Name</label>
          <input
            type="text"
            style={styles.input}
            value={roomName}
            onChange={(e) => setRoomName(e.target.value)}
            disabled={connectionStatus !== 'disconnected'}
          />
        </div>
        <div style={styles.formGroup}>
          <label style={styles.label}>Participant Name</label>
          <input
            type="text"
            style={styles.input}
            value={participantName}
            onChange={(e) => setParticipantName(e.target.value)}
            disabled={connectionStatus !== 'disconnected'}
          />
        </div>
        <button
          style={{
            ...styles.btnPrimary,
            ...(connectionStatus !== 'disconnected' ? styles.btnDisabled : {}),
          }}
          onClick={handleConnect}
          disabled={connectionStatus !== 'disconnected'}
        >
          Connect & Join Room
        </button>
        <button
          style={{
            ...styles.btnDanger,
            ...(connectionStatus !== 'connected' ? styles.btnDisabled : {}),
          }}
          onClick={handleDisconnect}
          disabled={connectionStatus !== 'connected'}
        >
          Disconnect
        </button>
      </div>

      <div style={getStatusStyle()}>{getStatusText()}</div>

      <div style={styles.controls}>
        <button
          style={{
            ...styles.btnSuccess,
            ...(connectionStatus !== 'connected' ? styles.btnDisabled : {}),
          }}
          onClick={toggleCamera}
          disabled={connectionStatus !== 'connected'}
        >
          {isCameraEnabled ? 'Disable Camera' : 'Enable Camera'}
        </button>
        <button
          style={{
            ...styles.btnSuccess,
            ...(connectionStatus !== 'connected' ? styles.btnDisabled : {}),
          }}
          onClick={toggleMic}
          disabled={connectionStatus !== 'connected'}
        >
          {isMicEnabled ? 'Disable Mic' : 'Enable Mic'}
        </button>
      </div>

      <div style={styles.videoGrid}>
        {participants.map((participant) => (
          <VideoTile key={participant.identity} participant={participant} />
        ))}
      </div>

      <div style={styles.logPanel}>
        {logs.map((log, index) => (
          <div key={index} style={{ ...styles.logEntry, color: getLogColor(log.type) }}>
            {log.message}
          </div>
        ))}
      </div>
    </div>
  );
}

function VideoTile({ participant }) {
  const videoRef = useRef(null);
  const audioRef = useRef(null);

  useEffect(() => {
    if (participant.videoTrack && videoRef.current) {
      participant.videoTrack.attach(videoRef.current);
      return () => {
        participant.videoTrack.detach(videoRef.current);
      };
    }
  }, [participant.videoTrack]);

  useEffect(() => {
    if (participant.audioTrack && audioRef.current && !participant.isLocal) {
      participant.audioTrack.attach(audioRef.current);
      return () => {
        participant.audioTrack.detach(audioRef.current);
      };
    }
  }, [participant.audioTrack, participant.isLocal]);

  return (
    <div style={styles.videoContainer}>
      <video ref={videoRef} style={styles.video} autoPlay playsInline muted={participant.isLocal} />
      {!participant.isLocal && <audio ref={audioRef} autoPlay />}
      <div style={styles.videoLabel}>
        {participant.identity} {participant.isLocal ? '(You)' : ''}
      </div>
    </div>
  );
}

export default App;
