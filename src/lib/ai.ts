import type { NPC, World } from "./db";

/**
 * LUCID AI — AI Orchestrator
 * ===========================
 * This is the ONE file that talks to AI providers. Every "AI module" from
 * the product spec (Story AI, NPC AI, Memory AI, Emotion AI, Image AI) is
 * implemented here as a function. Nothing else in the codebase calls an AI
 * API directly — that's on purpose, so that when the real API keys are
 * handed over, this is the only file that needs to change.
 *
 * HOW TO GO LIVE:
 * 1. Set OPENAI_API_KEY (or ANTHROPIC_API_KEY) in your .env.local
 * 2. That's it — callLLM() below will automatically stop using the
 *    mock generator and start calling the real model.
 *
 * Until a key is present, every function falls back to a deterministic
 * "mock brain" so the whole product is playable end-to-end with zero
 * setup — useful for demos, teammates without keys yet, and offline dev.
 */

const OPENAI_KEY = process.env.OPENAI_API_KEY;
const ANTHROPIC_KEY = process.env.ANTHROPIC_API_KEY;

// ---------------------------------------------------------------------------
// Low-level model call — swap/extend this if a different provider is given
// ---------------------------------------------------------------------------
async function callLLM(systemPrompt: string, userPrompt: string): Promise<string> {
  if (OPENAI_KEY) {
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${OPENAI_KEY}`,
      },
      body: JSON.stringify({
        model: process.env.OPENAI_MODEL || "gpt-4o-mini",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
        temperature: 0.9,
      }),
    });
    if (!res.ok) throw new Error(`OpenAI error: ${res.status} ${await res.text()}`);
    const data = await res.json();
    return data.choices[0].message.content as string;
  }

  if (ANTHROPIC_KEY) {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: process.env.ANTHROPIC_MODEL || "claude-3-5-haiku-latest",
        max_tokens: 1024,
        system: systemPrompt,
        messages: [{ role: "user", content: userPrompt }],
      }),
    });
    if (!res.ok) throw new Error(`Anthropic error: ${res.status} ${await res.text()}`);
    const data = await res.json();
    return data.content[0].text as string;
  }

  // ---- No key configured: deterministic mock so the app still runs ----
  return mockBrain(systemPrompt, userPrompt);
}

function safeJsonParse<T>(raw: string, fallback: T): T {
  try {
    const cleaned = raw.replace(/```json|```/g, "").trim();
    return JSON.parse(cleaned) as T;
  } catch {
    return fallback;
  }
}

// ---------------------------------------------------------------------------
// STORY AI — opening scene generation
// ---------------------------------------------------------------------------
export type SceneResult = {
  scene: string;
  choices: string[];
  npcIntroduced?: { name: string; personality: string };
};

export async function generateOpeningScene(genre: string, premise: string): Promise<SceneResult> {
  const system =
    "You are the Story AI for an interactive fiction platform called Lucid AI. " +
    "Write vivid, second-person opening scenes (120-180 words) for a branching story, " +
    "then propose 3 distinct player choices. Introduce exactly one named NPC. " +
    'Respond ONLY as JSON: {"scene": string, "choices": [string,string,string], ' +
    '"npcIntroduced": {"name": string, "personality": string}}';
  const user = `Genre: ${genre}\nPremise: ${premise}`;
  const raw = await callLLM(system, user);
  return safeJsonParse<SceneResult>(raw, mockOpeningScene(genre, premise));
}

// ---------------------------------------------------------------------------
// STORY AI + NPC AI + MEMORY AI + EMOTION AI — advancing the story
// ---------------------------------------------------------------------------
export type AdvanceResult = {
  scene: string;
  choices: string[];
  relationshipDelta: number; // applied to the most relevant NPC
  emotion: string;
  chapterAdvanced: boolean;
};

export async function advanceStory(
  world: World,
  npcs: NPC[],
  chosenChoice: string,
  recentHistory: string[]
): Promise<AdvanceResult> {
  const system =
    "You are the combined Story AI, NPC AI, Memory AI and Emotion AI for Lucid AI. " +
    "You are told the world state, the NPCs and their current relationship scores, and " +
    "the player's chosen action. Continue the story (120-180 words), remembering past " +
    "events and keeping NPC behavior consistent with their relationship score " +
    "(-100 hostile to 100 devoted). Then propose 3 new choices, and report how the " +
    "primary NPC's relationship score should change (-15 to +15) and their new emotion " +
    "(one word: happy, neutral, angry, sad, suspicious, afraid, hopeful). " +
    'Respond ONLY as JSON: {"scene": string, "choices": [string,string,string], ' +
    '"relationshipDelta": number, "emotion": string, "chapterAdvanced": boolean}';

  const npcSummary = npcs
    .map((n) => `- ${n.name}: personality="${n.personality}", relationship=${n.relationship}, emotion=${n.emotion}`)
    .join("\n");

  const user =
    `World: ${world.title} (${world.genre})\nPremise: ${world.premise}\n` +
    `Chapter: ${world.chapter}\nTime of day: ${world.timeOfDay}\n\n` +
    `NPCs:\n${npcSummary}\n\n` +
    `Recent history:\n${recentHistory.slice(-5).join("\n")}\n\n` +
    `Player chose: "${chosenChoice}"`;

  const raw = await callLLM(system, user);
  return safeJsonParse<AdvanceResult>(raw, mockAdvance(chosenChoice));
}

// ---------------------------------------------------------------------------
// IMAGE AI — character / NPC portraits
// ---------------------------------------------------------------------------
export async function generatePortrait(description: string): Promise<string> {
  if (OPENAI_KEY) {
    try {
      const res = await fetch("https://api.openai.com/v1/images/generations", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${OPENAI_KEY}`,
        },
        body: JSON.stringify({
          model: "gpt-image-1",
          prompt: `Fantasy game character portrait, digital painting style: ${description}`,
          size: "1024x1024",
        }),
      });
      if (res.ok) {
        const data = await res.json();
        if (data.data?.[0]?.url) return data.data[0].url as string;
        if (data.data?.[0]?.b64_json) return `data:image/png;base64,${data.data[0].b64_json}`;
      }
    } catch {
      // fall through to mock
    }
  }
  // Mock portrait: deterministic generated avatar, no key required.
  const seed = encodeURIComponent(description.slice(0, 40));
  return `https://api.dicebear.com/9.x/adventurer/svg?seed=${seed}`;
}

// ---------------------------------------------------------------------------
// Mock brain — used only when no API key is configured yet
// ---------------------------------------------------------------------------
function mockBrain(system: string, user: string): string {
  if (system.includes("propose 3 new choices")) {
    const choiceMatch = user.match(/Player chose: "([^"]+)"/);
    return JSON.stringify(mockAdvance(choiceMatch?.[1] ?? "continue"));
  }
  const genreMatch = user.match(/Genre: (.+)/);
  const premiseMatch = user.match(/Premise: (.+)/);
  return JSON.stringify(mockOpeningScene(genreMatch?.[1] ?? "fantasy", premiseMatch?.[1] ?? ""));
}

const MOCK_NAMES = ["Kael", "Nyra", "Thorne", "Sable", "Ilyra", "Dorian", "Vesper"];
const MOCK_TRAITS = [
  "guarded but fiercely loyal once trust is earned",
  "sharp-tongued and quick to test strangers",
  "warm and curious, eager for news of the outside world",
  "haunted by a past debt, wary of every stranger",
];

function mockOpeningScene(genre: string, premise: string): SceneResult {
  const name = MOCK_NAMES[Math.floor(Math.random() * MOCK_NAMES.length)];
  const trait = MOCK_TRAITS[Math.floor(Math.random() * MOCK_TRAITS.length)];
  return {
    scene:
      `The air still carries the weight of ${premise || "the world you've stepped into"}. ` +
      `A ${genre} settles around you like fog as you take your first steps forward. ` +
      `Ahead, a figure named ${name} watches from the shadows — not quite friend, not quite foe. ` +
      `Their eyes track your every movement, weighing who you might become in this story. ` +
      `The path splits before you; whatever you choose next will shape everything that follows.\n\n` +
      `[Connect an AI API key in .env.local to replace this placeholder scene with live, ` +
      `dynamically generated storytelling.]`,
    choices: [
      `Approach ${name} directly and introduce yourself`,
      "Stay hidden and observe a while longer",
      "Look for another way around, avoiding contact entirely",
    ],
    npcIntroduced: { name, personality: trait },
  };
}

function mockAdvance(chosenChoice: string): AdvanceResult {
  const positive = /approach|help|trust|befriend|introduce|greet/i.test(chosenChoice);
  const negative = /avoid|attack|steal|lie|threaten|hide/i.test(chosenChoice);
  const delta = positive ? 8 : negative ? -8 : 2;
  const emotion = delta > 5 ? "hopeful" : delta < 0 ? "suspicious" : "neutral";
  return {
    scene:
      `You chose to "${chosenChoice.toLowerCase()}." The world responds in kind — ` +
      `small shifts ripple outward from your decision, and those around you take notice. ` +
      `The story continues to remember every choice you've made so far, weaving them into ` +
      `what comes next.\n\n` +
      `[This is placeholder continuation text — connect an AI API key to generate real, ` +
      `context-aware story branches.]`,
    choices: [
      "Press forward, committed to this path",
      "Pause and reconsider your approach",
      "Change course entirely",
    ],
    relationshipDelta: delta,
    emotion,
    chapterAdvanced: Math.random() > 0.7,
  };
}
