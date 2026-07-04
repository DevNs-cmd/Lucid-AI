import { NextRequest, NextResponse } from "next/server";
import { v4 as uuid } from "uuid";
import { db } from "@/lib/db";
import { getSessionUserId } from "@/lib/auth";
import { advanceStory } from "@/lib/ai";

export async function POST(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const userId = await getSessionUserId();
  if (!userId) return NextResponse.json({ error: "Not signed in." }, { status: 401 });

  const { id } = await params;
  const world = db.getWorld(id);
  if (!world || world.userId !== userId) {
    return NextResponse.json({ error: "World not found." }, { status: 404 });
  }

  const { choiceLabel } = await req.json();
  if (!choiceLabel) {
    return NextResponse.json({ error: "choiceLabel is required." }, { status: 400 });
  }

  const npcs = db.getNpcsByWorld(id);
  const history = db.getEventsByWorld(id).map((e) => e.text);

  // Log the player's choice as a journal event first.
  db.addEvent({
    id: uuid(),
    worldId: id,
    type: "choice",
    text: `You chose: ${choiceLabel}`,
    createdAt: new Date().toISOString(),
  });

  const result = await advanceStory(world, npcs, choiceLabel, history);

  // Memory AI + Relationship AI + Emotion AI: update the primary NPC.
  const primaryNpc = npcs[0];
  if (primaryNpc) {
    const newRelationship = Math.max(
      -100,
      Math.min(100, primaryNpc.relationship + (result.relationshipDelta ?? 0))
    );
    db.updateNpc(primaryNpc.id, { relationship: newRelationship, emotion: result.emotion || "neutral" });
  }

  const nextChapter = result.chapterAdvanced ? world.chapter + 1 : world.chapter;
  const updatedWorld = db.updateWorld(id, {
    currentScene: result.scene,
    currentChoices: result.choices.map((label) => ({ id: uuid(), label })),
    chapter: nextChapter,
  });

  db.addEvent({
    id: uuid(),
    worldId: id,
    type: "scene",
    text: result.scene,
    createdAt: new Date().toISOString(),
  });

  const updatedNpcs = db.getNpcsByWorld(id);

  return NextResponse.json({ world: updatedWorld, npcs: updatedNpcs });
}
