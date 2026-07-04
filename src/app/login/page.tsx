"use client";

import Link from "next/link";
import { useState, FormEvent } from "react";
import { useRouter } from "next/navigation";
import { Nav } from "@/components/Nav";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    const res = await fetch("/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });
    const data = await res.json();
    setLoading(false);
    if (!res.ok) {
      setError(data.error || "Something went wrong.");
      return;
    }
    router.push("/dashboard");
    router.refresh();
  }

  return (
    <>
      <Nav />
      <main className="flex flex-1 items-center justify-center px-6 py-16">
        <div className="glass-panel glow-border w-full max-w-sm rounded-2xl p-8">
          <h1 className="font-display text-2xl text-parchment">Welcome back</h1>
          <p className="mt-1 text-sm text-parchment-dim">Your worlds have kept moving without you.</p>

          <form onSubmit={handleSubmit} className="mt-6 space-y-4">
            <div>
              <label className="mb-1.5 block text-xs text-parchment-dim">Email</label>
              <input
                required
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full rounded-lg border border-white/10 bg-ink-2 px-3.5 py-2.5 text-sm text-parchment outline-none focus:border-arcane"
                placeholder="you@example.com"
              />
            </div>
            <div>
              <label className="mb-1.5 block text-xs text-parchment-dim">Password</label>
              <input
                required
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full rounded-lg border border-white/10 bg-ink-2 px-3.5 py-2.5 text-sm text-parchment outline-none focus:border-arcane"
                placeholder="••••••••"
              />
            </div>

            {error && <p className="text-sm text-danger">{error}</p>}

            <button
              type="submit"
              disabled={loading}
              className="w-full rounded-lg bg-arcane py-2.5 text-sm font-medium text-white shadow-[0_0_20px_rgba(139,92,246,0.4)] transition-opacity hover:opacity-90 disabled:opacity-50"
            >
              {loading ? "Logging in…" : "Log in"}
            </button>
          </form>

          <p className="mt-5 text-center text-sm text-parchment-dim">
            New here?{" "}
            <Link href="/signup" className="text-arcane-bright hover:underline">
              Create an account
            </Link>
          </p>
        </div>
      </main>
    </>
  );
}
