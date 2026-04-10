const { WebSocketServer } = require("ws");
const { createServer } = require("http");

const PORT = process.env.PORT || 8080;

// rooms: Map<roomId, Map<connId, { ws, peerId }>>
const rooms = new Map();
// games: only tracked in "bj-lobby"  Map<code, { code, host_name, player_count, peerId }>
const games = new Map();
let nextConnId = 1;

function getOrCreateRoom(roomId) {
  if (!rooms.has(roomId)) rooms.set(roomId, new Map());
  return rooms.get(roomId);
}

function broadcast(room, msg, excludeConnId = null) {
  const json = JSON.stringify(msg);
  for (const [id, peer] of room) {
    if (id !== excludeConnId && peer.ws.readyState === 1) {
      peer.ws.send(json);
    }
  }
}

function sendTo(room, peerId, msg) {
  for (const peer of room.values()) {
    if (peer.peerId === peerId && peer.ws.readyState === 1) {
      peer.ws.send(JSON.stringify(msg));
      break;
    }
  }
}

const server = createServer((req, res) => {
  res.writeHead(200);
  res.end("BJ Relay running");
});

const wss = new WebSocketServer({ server });

wss.on("connection", (ws, req) => {
  // URL path is the room id, e.g. /bj-lobby or /bj-AB12
  const roomId = (req.url || "/").replace(/^\//, "") || "default";
  const isLobby = roomId === "bj-lobby";
  const room = getOrCreateRoom(roomId);

  const connId = nextConnId++;
  const peerId = connId; // simple: connection order = peer id
  room.set(connId, { ws, peerId });

  // Greet new joiner
  const joinMsg = isLobby
    ? { type: "joined", peer_id: peerId, games: [...games.values()].map(({ code, host_name, player_count }) => ({ code, host_name, player_count })) }
    : { type: "joined", peer_id: peerId };
  ws.send(JSON.stringify(joinMsg));

  broadcast(room, { type: "peer_joined", peer_id: peerId }, connId);

  ws.on("message", (raw) => {
    let data;
    try { data = JSON.parse(raw); } catch { return; }

    // Lobby: handle game registration
    if (isLobby && data.type === "register_game") {
      const entry = { code: data.code, host_name: data.host_name, player_count: 1, peerId };
      games.set(data.code, entry);
      broadcast(room, { type: "game_added", game: { code: entry.code, host_name: entry.host_name, player_count: entry.player_count } });
      return;
    }

    // Targeted or broadcast relay
    if (data.to !== undefined) {
      sendTo(room, data.to, { ...data, from: peerId });
    } else {
      broadcast(room, { ...data, from: peerId }, connId);
    }
  });

  ws.on("close", () => {
    room.delete(connId);
    if (room.size === 0) rooms.delete(roomId);

    // Remove games hosted by this peer
    if (isLobby) {
      for (const [code, game] of games) {
        if (game.peerId === peerId) {
          games.delete(code);
          broadcast(room, { type: "remove_game", code });
        }
      }
    }

    broadcast(room, { type: "peer_left", peer_id: peerId });
  });
});

server.listen(PORT, () => console.log(`Relay listening on port ${PORT}`));
