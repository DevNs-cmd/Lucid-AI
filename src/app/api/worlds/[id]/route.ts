import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import { getSessionUserId } from "@/lib/auth";

export async function GET(_req: Request, { params }: { params: Promise<{ id: string }> }) {
  const userId = await getSessionUserId();
  if (!userId) return NextResponse.json({ error: "Not signed in." }, { status: 401 });

  const { id } = await params;
  const world = db.getWorld(id);
  if (!world || world.userId !== userId) {
    return NextResponse.json({ error: "World not found." }, { status: 404 });
  }

  const npcs = db.getNpcsByWorld(id);
  const characters = db.getCharactersByWorld(id);

  return NextResponse.json({ world, npcs, characters });
}
