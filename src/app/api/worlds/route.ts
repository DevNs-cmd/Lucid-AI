import { NextRequest, NextResponse } from "next/server";
import { v4 as uuid } from "uuid";
import { db } from "@/lib/db";
import { getSessionUserId } from "@/lib/auth";
import { generateOpeningScene, generatePortrait } from "@/lib/ai";

export async function GET() {
  const userId = await getSessionUserId();
  if (!userId) return NextResponse.json({ error: "Not signed in." }, { status: 401 });

  const worlds = db.getWorldsByUser(userId).sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
  return NextResponse.json({ worlds });
}

export async function POST(req: NextRequest) {
  const userId = await getSessionUserId();
  if (!userId) return NextResponse.json({ error: "Not signed in." }, { status: 401 });

  const { title, genre, premise } = await req.json();
  if (!title || !genre || !premise) {
    return NextResponse.json({ error: "Title, genre and premise are required." }, { status: 400 });
  }

  const worldId = uuid();
  const opening = await generateOpeningScene(genre, premise);

  let npcIds: string[] = [];
  if (opening.npcIntroduced) {
    const npcId = uuid();
    const portraitUrl = await generatePortrait(
      `${opening.npcIntroduced.name}, ${opening.npcIntroduced.personality}, ${genre} setting`
    );
    db.createNpc({
      id: npcId,
      worldId,
      name: opening.npcIntroduced.name,
      personality: opening.npcIntroduced.personality,
      relationship: 0,
      emotion: "neutral",
      portraitUrl,
    });
    npcIds = [npcId];
  }

  const coverUrl = await generatePortrait(`${title}, ${genre}, ${premise}, wide establishing shot`);

  const now = new Date().toISOString();
  const world = {
    id: worldId,
    userId,
    title,
    genre,
    premise,
    currentScene: opening.scene,
    currentChoices: opening.choices.map((label) => ({ id: uuid(), label })),
    npcIds,
    timeOfDay: "dusk",
    chapter: 1,
    coverUrl,
    createdAt: now,
    updatedAt: now,
  };
  db.createWorld(world);

  db.addEvent({
    id: uuid(),
    worldId,
    type: "scene",
    text: opening.scene,
    createdAt: now,
  });

  return NextResponse.json({ world });
}
