import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import { getSessionUserId } from "@/lib/auth";

export async function GET() {
  const userId = await getSessionUserId();
  if (!userId) return NextResponse.json({ user: null });

  const user = db.getUserById(userId);
  if (!user) return NextResponse.json({ user: null });

  return NextResponse.json({ user: { id: user.id, name: user.name, email: user.email } });
}
