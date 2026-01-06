# Hướng dẫn Deploy LiveKit Server Local

## Cách 1: Sử dụng Docker (Khuyến nghị)

### Yêu cầu
- Docker Desktop đã được cài đặt

### Bước 1: Chạy LiveKit Server

```bash
docker run --rm \
  -p 7880:7880 \
  -p 7881:7881 \
  -p 7882:7882/udp \
  livekit/livekit-server \
  --dev \
  --bind 0.0.0.0
```

Server sẽ chạy với:
- **API Key**: `devkey`
- **API Secret**: `secret`
- **WebSocket URL**: `ws://localhost:7880`

### Bước 2: Tạo Access Token

Cài đặt LiveKit CLI:
```bash
# macOS
brew install livekit-cli

# Hoặc tải từ GitHub releases
# https://github.com/livekit/livekit-cli/releases
```

Tạo token:
```bash
livekit-cli create-token \
  --api-key devkey \
  --api-secret secret \
  --join --room my-room --identity user1 \
  --valid-for 24h
```

---

## Cách 2: Cài đặt trực tiếp (không dùng Docker)

### macOS
```bash
brew install livekit
```

### Linux
```bash
curl -sSL https://get.livekit.io | bash
```

### Chạy server
```bash
livekit-server --dev
```

---

## Cách 3: Sử dụng Docker Compose

Tạo file `docker-compose.yml`:

```yaml
version: "3.9"

services:
  livekit:
    image: livekit/livekit-server:latest
    command: --dev --bind 0.0.0.0
    ports:
      - "7880:7880"
      - "7881:7881"
      - "7882:7882/udp"
    environment:
      - LIVEKIT_KEYS=devkey: secret
```

Chạy:
```bash
docker-compose up -d
```

---

## Test kết nối

### Sử dụng LiveKit Meet (Web App)

1. Truy cập: https://meet.livekit.io
2. Nhập thông tin:
   - **LiveKit URL**: `ws://localhost:7880`
   - **Token**: (token bạn tạo ở trên)

### Sử dụng code (JavaScript/TypeScript)

```bash
npm install livekit-client
```

```javascript
import { Room, RoomEvent } from 'livekit-client';

const room = new Room();

room.on(RoomEvent.Connected, () => {
  console.log('Connected to room!');
});

await room.connect('ws://localhost:7880', 'YOUR_TOKEN');
```

---

## Cấu hình nâng cao (Production)

Tạo file `livekit.yaml`:

```yaml
port: 7880
rtc:
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true

keys:
  your-api-key: your-api-secret

logging:
  level: info
```

Chạy với config:
```bash
docker run --rm \
  -p 7880:7880 \
  -p 7881:7881 \
  -p 50000-60000:50000-60000/udp \
  -v $PWD/livekit.yaml:/livekit.yaml \
  livekit/livekit-server \
  --config /livekit.yaml
```

---

## Ports cần mở

| Port | Protocol | Mục đích |
|------|----------|----------|
| 7880 | TCP | HTTP API & WebSocket |
| 7881 | TCP | WebRTC over TCP |
| 7882 | UDP | WebRTC over UDP |
| 50000-60000 | UDP | RTC ports (production) |

---

## Tài liệu tham khảo

- [LiveKit Docs](https://docs.livekit.io)
- [LiveKit GitHub](https://github.com/livekit/livekit)
- [LiveKit Client SDKs](https://docs.livekit.io/client-sdk/)
