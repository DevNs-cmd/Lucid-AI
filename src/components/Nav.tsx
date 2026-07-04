"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Logo } from "./Logo";

type SessionUser = { id: string; name: string; email: string } | null;

export function Nav() {
  const [user, setUser] = useState<SessionUser>(null);
  const [loaded, setLoaded] = useState(false);
  const router = useRouter();

  useEffect(() => {
    fetch("/api/auth/me")
      .then((r) => r.json())
      .then((data) => setUser(data.user))
      .finally(() => setLoaded(true));
  }, []);

  async function handleLogout() {
    await fetch("/api/auth/logout", { method: "POST" });
    setUser(null);
    router.push("/");
    router.refresh();
  }

  return (
    <nav className="sticky top-0 z-50 border-b border-white/5 bg-ink/80 backdrop-blur-md">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
        <Link href="/" className="flex items-center gap-2.5">
          <Logo />
          <span className="font-display text-lg tracking-wide text-parchment">Lucid AI</span>
        </Link>

        <div className="flex items-center gap-6 text-sm">
          {loaded && user ? (
            <>
              <Link href="/dashboard" className="text-parchment-dim hover:text-parchment transition-colors">
                My Worlds
              </Link>
              <span className="hidden text-parchment-dim sm:inline">{user.name}</span>
              <button
                onClick={handleLogout}
                className="rounded-full border border-white/10 px-4 py-1.5 text-parchment-dim hover:border-arcane/50 hover:text-parchment transition-colors"
              >
                Log out
              </button>
            </>
          ) : loaded ? (
            <>
              <Link href="/login" className="text-parchment-dim hover:text-parchment transition-colors">
                Log in
              </Link>
              <Link
                href="/signup"
                className="rounded-full bg-arcane px-4 py-1.5 font-medium text-white shadow-[0_0_20px_rgba(139,92,246,0.4)] hover:bg-arcane-bright transition-colors"
              >
                Start your story
              </Link>
            </>
          ) : null}
        </div>
      </div>
    </nav>
  );
}
