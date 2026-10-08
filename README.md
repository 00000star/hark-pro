# Hark AI Computer-Use Agent 🖥️🤖

Hark is an autonomous, vision-grounded Computer-Use AI agent designed to interact with virtual desktops, web interfaces, and GUI applications just like a human. It combines Set-of-Marks (SoM) visual prompting, human-like cursor dynamics with Bezier easing, and real-time MJPEG/WebSocket desktop telemetry streaming.

---

## 🏛️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        User / Client                        │
│   (Web Dashboard / REST API / WebSocket Telemetry Client)   │
└───────────────▲─────────────────────────────┬───────────────┘
                │ MJPEG Video                 │ Start / Pause
                │ & Telemetry Stream          │ Task Request
┌───────────────┴─────────────────────────────▼───────────────┐
│              FastAPI Server (src/stream/server.py)          │
│  - GET  /stream/video (Multipart MJPEG live feed)           │
│  - WS   /ws/telemetry (Real-time cursor coordinates & state)│
│  - POST /api/task (Start autonomous execution)              │
│  - POST /api/task/pause | /resume                           │
│  - GET  /api/task/status | /logs                            │
└─────────────────────────────┬───────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│            ActionEngine (src/agent/action_engine.py)        │
│  - Vision LLM Grounding (GPT-4o / Qwen-2.5-VL / Claude)     │
│  - Set-of-Marks (SoM) Visual badge matching                 │
│  - Autonomous Step Planning & Fallback Simulator            │
└─────────────────────────────┬───────────────────────────────┘
                              │ Human-like Actions
                              │ (Smooth Bezier mouse, keystrokes)
┌─────────────────────────────▼───────────────────────────────┐
│        BrowserController (src/sandbox/browser.py)           │
│  - Playwright Chromium Virtual Session                      │
│  - Set-of-Marks DOM Element Harvester                       │
│  - Visual Canvas Renderer with Cursor Overlay               │
└─────────────────────────────────────────────────────────────┘
```

### Key Modules

- **`src/sandbox/browser.py`**:
  - Manages headless/headed Playwright Chromium contexts.
  - Extracts interactive DOM elements (`<a>`, `<button>`, `<input>`, `textarea`, `[role=...]`).
  - Tags elements with visual Set-of-Marks (SoM) bounding boxes and badge IDs.
  - Generates natural, human-like mouse movements via cubic Bezier curves with jitter.
  - Captures high-definition JPEG frames with virtual cursor overlay.

- **`src/agent/action_engine.py`**:
  - Multi-modal vision reasoning engine.
  - Accepts visual screenshots tagged with Set-of-Marks badges.
  - Predicts structured actions (`click`, `type`, `scroll`, `wait`, `navigate`, `finish`).
  - Includes a fallback simulator for automated operation even without external Vision LLM API keys.

- **`src/stream/server.py`**:
  - High-performance FastAPI server.
  - `/stream/video`: Continuous multipart/x-mixed-replace MJPEG virtual screen stream.
  - `/ws/telemetry`: WebSocket streaming cursor coordinates (`x`, `y`), mouse click status, and task logs.
  - REST endpoints for task submission and lifecycle control.

- **`main.py`**:
  - Unified CLI and server entrypoint.
  - Supports running isolated tasks directly from the command line or starting the long-running streaming server.

---

## 🚀 Quickstart

### 1. Prerequisites & Installation

Python 3.10+ is required.

```bash
# Clone or navigate to the repository
cd /sdcard/Antigravity_Projects/hark_agent

# Install Python dependencies
pip install -r requirements.txt

# Install Playwright browser binaries
playwright install chromium
```

### 2. Run Direct CLI Task

To run an autonomous task directly in headless mode:

```bash
python3 main.py --task "Search the latest news on Hacker News"
```

### 3. Run FastAPI Streaming Server

Start the API and live streaming server:

```bash
python3 main.py --host 0.0.0.0 --port 8000
```

Once running:
- **Interactive API Docs (Swagger UI)**: `http://localhost:8000/docs`
- **Live Desktop Video Stream**: `http://localhost:8000/stream/video`
- **Live Telemetry WebSocket**: `ws://localhost:8000/ws/telemetry`

---

## 🐳 Docker Deployment

The container includes a full headless Xvfb framebuffer, Fluxbox window manager, and all required graphics/browser libraries on Ubuntu 24.04.

### Build Docker Image

```bash
docker build -t hark-agent:latest -f docker/Dockerfile .
```

### Run Docker Container

```bash
docker run -d \
  --name hark-agent \
  -p 8000:8000 \
  --shm-size=2g \
  -e OPENAI_API_KEY="your-api-key-here" \
  hark-agent:latest
```

View the live virtual screen inside your browser:
```
http://localhost:8000/stream/video
```

---

## 🔌 API Reference

### REST Endpoints

| Method | Endpoint | Description | Request Body / Parameters |
|---|---|---|---|
| `POST` | `/api/task` | Launch an autonomous agent task | `{"task": "Search for AI models", "max_steps": 10}` |
| `POST` | `/api/task/pause` | Pause current execution | None |
| `POST` | `/api/task/resume` | Resume paused execution | None |
| `GET` | `/api/task/status` | Current status, running state, and cursor | None |
| `GET` | `/api/task/logs` | Fetch recent execution logs | None |
| `GET` | `/stream/video` | MJPEG video stream of the virtual desktop | HTTP Multipart Stream |

### WebSocket Endpoint

- `GET /ws/telemetry`
  - Streams real-time JSON packets:
    ```json
    {
      "event": "cursor_position",
      "data": {
        "x": 640.0,
        "y": 400.0,
        "is_mouse_down": false
      }
    }
    ```
  - Also receives lifecycle events (`task_started`, `action_start`, `action_end`, `task_finished`).

---

## ⚙️ Environment Variables

- `OPENAI_API_KEY`: API key for GPT-4o Vision action prediction. If unset, the agent automatically runs in fallback simulation mode.
- `ANTHROPIC_API_KEY`: Alternative vision LLM key.
- `DISPLAY`: Virtual display for Xvfb (default `:99` inside container).
- `SCREEN_WIDTH`: Viewport width (default `1280`).
- `SCREEN_HEIGHT`: Viewport height (default `800`).
