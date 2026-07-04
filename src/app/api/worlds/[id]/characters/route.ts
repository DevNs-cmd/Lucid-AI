import { NextRequest, NextResponse } from "next/server";
import { v4 as uuid } from "uuid";
import { db } from "@/lib/db";
import { getSessionUserId } from "@/lib/auth";
import { generatePortrait } from "@/lib/ai";

export async function POST(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const userId = await getSessionUserId();
  if (!userId) return NextResponse.json({ error: "Not signed in." }, { status: 401 });

  const { id } = await params;
  const world = db.getWorld(id);
  if (!world || world.userId !== userId) {
    return NextResponse.json({ error: "World not found." }, { status: 404 });
  }

  const { name, archetype } = await req.json();
  if (!name || !archetype) {
    return NextResponse.json({ error: "Name and archetype are required." }, { status: 400 });
  }

  const portraitUrl = await generatePortrait(`${name}, a ${archetype}, ${world.genre} setting`);

  const character = {
    id: uuid(),
    worldId: id,
    userId,
    name,
    archetype,
    stats: {
      courage: 40 + Math.floor(Math.random() * 30),
      wisdom: 40 + Math.floor(Math.random() * 30),
      charm: 40 + Math.floor(Math.random() * 30),
    },
    portraitUrl,
  };
  db.createCharacter(character);

  return NextResponse.json({ character });
}
