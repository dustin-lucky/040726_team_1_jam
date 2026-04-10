import type * as Party from "partykit/server";

interface GameEntry {
  code: string;
  host_name: string;
  player_count: number;
  peer_id: number;
}

// Single server handles both rooms:
//   "bj-lobby" — tracks open game list, sends it to new joiners
//   "bj-XXXX"  — pure relay for in-progress games
export default class BjServer implements Party.Server {
  peers = new Map<string, number>(); // connection id -> integer peer_id
  nextId = 1;
  games = new Map<string, GameEntry>(); // only populated in the lobby room

  get isLobby() {
    return this.room.id === "bj-lobby";
  }

  onConnect(conn: Party.Connection) {
    const id = this.nextId++;
    this.peers.set(conn.id, id);

    if (this.isLobby) {
      // Send assigned peer_id + current open game list
      conn.send(
        JSON.stringify({
          type: "joined",
          peer_id: id,
          games: [...this.games.values()].map(({ code, host_name, player_count }) => ({
            code,
            host_name,
            player_count,
          })),
        })
      );
    } else {
      conn.send(JSON.stringify({ type: "joined", peer_id: id }));
    }

    this.room.broadcast(
      JSON.stringify({ type: "peer_joined", peer_id: id }),
      [conn.id]
    );
  }

  onClose(conn: Party.Connection) {
    const peerId = this.peers.get(conn.id);
    this.peers.delete(conn.id);

    // Auto-remove games hosted by disconnected peer
    if (this.isLobby && peerId !== undefined) {
      for (const [code, game] of this.games) {
        if (game.peer_id === peerId) {
          this.games.delete(code);
          this.room.broadcast(JSON.stringify({ type: "remove_game", code }));
        }
      }
    }

    this.room.broadcast(
      JSON.stringify({ type: "peer_left", peer_id: peerId })
    );
  }

  onMessage(msg: string, sender: Party.Connection) {
    const data = JSON.parse(msg);
    const from = this.peers.get(sender.id)!;

    // Lobby-specific: register a new open game
    if (this.isLobby && data.type === "register_game") {
      const entry: GameEntry = {
        code: data.code,
        host_name: data.host_name,
        player_count: 1,
        peer_id: from,
      };
      this.games.set(data.code, entry);
      this.room.broadcast(
        JSON.stringify({
          type: "game_added",
          game: { code: entry.code, host_name: entry.host_name, player_count: entry.player_count },
        })
      );
      return;
    }

    // Default relay: forward to one peer (data.to set) or broadcast to all
    if (data.to !== undefined) {
      for (const [cid, pid] of this.peers) {
        if (pid === data.to) {
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
