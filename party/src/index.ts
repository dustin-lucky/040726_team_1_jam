import type * as Party from "partykit/server";

interface PeerInfo {
  id: number;
  name: string;
}

interface GameEntry {
  code: string;
  host_name: string;
  player_count: number;
  peer_id: number;
}

// Single server handles both room types:
//   "bj-lobby"  — tracks open game list, sends it to new joiners
//   "bj-XXXX"   — game room: tracks players with names, relays messages
export default class BjServer implements Party.Server {
  peers = new Map<string, PeerInfo>(); // conn.id -> {id, name}
  nextId = 1;
  games = new Map<string, GameEntry>(); // lobby only

  get isLobby() {
    return this.room.id === "bj-lobby";
  }

  onConnect(conn: Party.Connection, ctx: Party.ConnectionContext) {
    const id = this.nextId++;
    const url = new URL(ctx.request.url);
    const name = url.searchParams.get("name") || "Player";

    this.peers.set(conn.id, { id, name });

    if (this.isLobby) {
      // Send assigned peer_id + current open game list
      conn.send(JSON.stringify({
        type: "joined",
        peer_id: id,
        games: [...this.games.values()].map(({ code, host_name, player_count }) => ({
          code, host_name, player_count,
        })),
      }));
      this.room.broadcast(
        JSON.stringify({ type: "peer_joined", peer_id: id }),
        [conn.id]
      );
    } else {
      // Game room: send full player list (including self) to new joiner
      const players = [...this.peers.values()].map(p => ({
        peer_id: p.id,
        name: p.name,
        player_index: p.id - 1, // peer ids start at 1; host = index 0
      }));
      conn.send(JSON.stringify({ type: "joined", peer_id: id, players }));

      // Tell everyone else about the new player
      this.room.broadcast(JSON.stringify({
        type: "player_joined",
        peer_id: id,
        name,
        player_index: id - 1,
      }), [conn.id]);
    }
  }

  onClose(conn: Party.Connection) {
    const peer = this.peers.get(conn.id);
    this.peers.delete(conn.id);

    if (!peer) return;

    // Auto-remove games hosted by this peer (lobby only)
    if (this.isLobby) {
      for (const [code, game] of this.games) {
        if (game.peer_id === peer.id) {
          this.games.delete(code);
          this.room.broadcast(JSON.stringify({ type: "remove_game", code }));
        }
      }
    }

    this.room.broadcast(JSON.stringify({ type: "peer_left", peer_id: peer.id }));
  }

  onMessage(msg: string, sender: Party.Connection) {
    const data = JSON.parse(msg);
    const peer = this.peers.get(sender.id);
    if (!peer) return;
    const from = peer.id;

    // Lobby: register a new open game
    if (this.isLobby && data.type === "register_game") {
      const entry: GameEntry = {
        code: data.code,
        host_name: data.host_name,
        player_count: 1,
        peer_id: from,
      };
      this.games.set(data.code, entry);
      this.room.broadcast(JSON.stringify({
        type: "game_added",
        game: { code: entry.code, host_name: entry.host_name, player_count: entry.player_count },
      }));
      return;
    }

    // Lobby: a player joined an open game — increment count
    if (this.isLobby && data.type === "join_game") {
      const game = this.games.get(data.code);
      if (game) {
        game.player_count += 1;
        this.room.broadcast(JSON.stringify({
          type: "game_updated",
          game: { code: game.code, host_name: game.host_name, player_count: game.player_count },
        }));
      }
      return;
    }

    // Default relay: targeted (data.to set) or broadcast
    if (data.to !== undefined) {
      for (const [cid, p] of this.peers) {
        if (p.id === data.to) {
          this.room.getConnection(cid)?.send(JSON.stringify({ ...data, from }));
          break;
        }
      }
    } else {
      this.room.broadcast(JSON.stringify({ ...data, from }), [sender.id]);
    }
  }

  constructor(readonly room: Party.Room) {}
}
