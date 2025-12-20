import express from 'express';
import cors from 'cors';
import { AccessToken } from 'livekit-server-sdk';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();
app.use(cors());
app.use(express.json());

// Serve static files in production
app.use(express.static(join(__dirname, 'dist')));

// Configuration - Match these with your LiveKit server
const API_KEY = process.env.LIVEKIT_API_KEY || 'apikey';
const API_SECRET = process.env.LIVEKIT_API_SECRET || 'Abc@123';
const LIVEKIT_URL = process.env.LIVEKIT_URL || 'ws://194.233.66.68:7880';

app.post('/api/token', async (req, res) => {
  try {
    const { roomName, participantName } = req.body;

    const room = roomName || 'test-room';
    const participant = participantName || 'user-' + Math.random().toString(36).substring(7);

    const token = new AccessToken(API_KEY, API_SECRET, {
      identity: participant,
      ttl: '24h',
    });

    token.addGrant({
      room: room,
      roomJoin: true,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    });

    const jwt = await token.toJwt();

    res.json({
      token: jwt,
      roomName: room,
      participantName: participant,
      livekitUrl: LIVEKIT_URL,
    });
  } catch (error) {
    console.error('Error generating token:', error);
    res.status(500).json({ error: 'Failed to generate token' });
  }
});

// Fallback to index.html for SPA
app.get('*', (req, res) => {
  res.sendFile(join(__dirname, 'dist', 'index.html'));
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running at http://0.0.0.0:${PORT}`);
  console.log(`LiveKit URL: ${LIVEKIT_URL}`);
});
