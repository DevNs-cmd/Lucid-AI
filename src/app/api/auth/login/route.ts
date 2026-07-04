import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db";
import { verifyPassword, signSession, setSessionCookie } from "@/lib/auth";

export async function POST(req: NextRequest) {
  const { email, password } = await req.json();

  const user = db.getUserByEmail(email ?? "");
  if (!user) {
    return NextResponse.json({ error: "No account found with this email." }, { status: 404 });
  }

  const valid = await verifyPassword(password ?? "", user.passwordHash);
  if (!valid) {
    return NextResponse.json({ error: "Incorrect password." }, { status: 401 });
  }

  const token = signSession(user.id);
  await setSessionCookie(token);

  return NextResponse.json({ id: user.id, name: user.name, email: user.email });
}
