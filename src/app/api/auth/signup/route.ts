import { NextRequest, NextResponse } from "next/server";
import { v4 as uuid } from "uuid";
import { db } from "@/lib/db";
import { hashPassword, signSession, setSessionCookie } from "@/lib/auth";

export async function POST(req: NextRequest) {
  const { name, email, password } = await req.json();

  if (!name || !email || !password) {
    return NextResponse.json({ error: "Name, email and password are all required." }, { status: 400 });
  }
  if (password.length < 6) {
    return NextResponse.json({ error: "Password must be at least 6 characters." }, { status: 400 });
  }
  if (db.getUserByEmail(email)) {
    return NextResponse.json({ error: "An account with this email already exists." }, { status: 409 });
  }

  const user = {
    id: uuid(),
    name,
    email,
    passwordHash: await hashPassword(password),
    createdAt: new Date().toISOString(),
  };
  db.createUser(user);

  const token = signSession(user.id);
  await setSessionCookie(token);

  return NextResponse.json({ id: user.id, name: user.name, email: user.email });
}
