import fs from "fs";
import path from "path";

/**
 * LUCID AI — lightweight file-backed data store.
 *
 * This is intentionally NOT Postgres/Supabase. It's a zero-setup JSON store
 * so the whole team can run the app instantly with no external services.
 * When you're ready to move to Postgres, swap the read()/write() calls in
 * this file for real queries — every other file in the app only talks to
 * the functions exported below, so the rest of the codebase never changes.
 */

const DATA_DIR = path.join(process.cwd(), "data");
const DB_FILE = path.join(DATA_DIR, "db.json");

export type User = {
  id: string;
  name: string;
  email: string;
  passwordHash: string;
  createdAt: string;
};

export type NPC = {
  id: string;
  worldId: string;
  name: string;
  personality: string; // short description used in AI prompts
  relationship: number; // -100 (hatred) to 100 (devoted)
  emotion: string; // derived tag: happy / neutral / angry / sad / suspicious
  portraitUrl: string | null;
};

export type StoryEvent = {
  id: string;
  worldId: string;
  type: "scene" | "choice" | "system";
  text: string;
  createdAt: string;
};

export type Choice = {
  id: string;
  label: string;
};

export type World = {
  id: string;
  userId: string;
  title: string;
  genre: string;
  premise: string;
  currentScene: string;
  currentChoices: Choice[];
  npcIds: string[];
  timeOfDay: string;
  chapter: number;
  coverUrl: string | null;
  createdAt: string;
  updatedAt: string;
};

export type Character = {
  id: string;
  worldId: string;
  userId: string;
  name: string;
  archetype: string;
  stats: { courage: number; wisdom: number; charm: number };
  portraitUrl: string | null;
};

type DB = {
  users: User[];
  worlds: World[];
  npcs: NPC[];
  characters: Character[];
  events: StoryEvent[];
};

function ensureDb(): void {
  if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
  if (!fs.existsSync(DB_FILE)) {
    const empty: DB = { users: [], worlds: [], npcs: [], characters: [], events: [] };
    fs.writeFileSync(DB_FILE, JSON.stringify(empty, null, 2));
  }
}

function read(): DB {
  ensureDb();
  const raw = fs.readFileSync(DB_FILE, "utf-8");
  return JSON.parse(raw) as DB;
}

function write(db: DB): void {
  fs.writeFileSync(DB_FILE, JSON.stringify(db, null, 2));
}

export const db = {
  // ---- users ----
  getUserByEmail(email: string): User | undefined {
    return read().users.find((u) => u.email.toLowerCase() === email.toLowerCase());
  },
  getUserById(id: string): User | undefined {
    return read().users.find((u) => u.id === id);
  },
  createUser(user: User): void {
    const data = read();
    data.users.push(user);
    write(data);
  },

  // ---- worlds ----
  getWorldsByUser(userId: string): World[] {
    return read().worlds.filter((w) => w.userId === userId);
  },
  getWorld(id: string): World | undefined {
    return read().worlds.find((w) => w.id === id);
  },
  createWorld(world: World): void {
    const data = read();
    data.worlds.push(world);
    write(data);
  },
  updateWorld(id: string, patch: Partial<World>): World | undefined {
    const data = read();
    const idx = data.worlds.findIndex((w) => w.id === id);
    if (idx === -1) return undefined;
    data.worlds[idx] = { ...data.worlds[idx], ...patch, updatedAt: new Date().toISOString() };
    write(data);
    return data.worlds[idx];
  },

  // ---- npcs ----
  getNpcsByWorld(worldId: string): NPC[] {
    return read().npcs.filter((n) => n.worldId === worldId);
  },
  getNpc(id: string): NPC | undefined {
    return read().npcs.find((n) => n.id === id);
  },
  createNpc(npc: NPC): void {
    const data = read();
    data.npcs.push(npc);
    write(data);
  },
  updateNpc(id: string, patch: Partial<NPC>): NPC | undefined {
    const data = read();
    const idx = data.npcs.findIndex((n) => n.id === id);
    if (idx === -1) return undefined;
    data.npcs[idx] = { ...data.npcs[idx], ...patch };
    write(data);
    return data.npcs[idx];
  },

  // ---- characters ----
  getCharactersByWorld(worldId: string): Character[] {
    return read().characters.filter((c) => c.worldId === worldId);
  },
  getCharacter(id: string): Character | undefined {
    return read().characters.find((c) => c.id === id);
  },
  createCharacter(character: Character): void {
    const data = read();
    data.characters.push(character);
    write(data);
  },

  // ---- events / journal / timeline ----
  getEventsByWorld(worldId: string): StoryEvent[] {
    return read()
      .events.filter((e) => e.worldId === worldId)
      .sort((a, b) => a.createdAt.localeCompare(b.createdAt));
  },
  addEvent(event: StoryEvent): void {
    const data = read();
    data.events.push(event);
    write(data);
  },
};
