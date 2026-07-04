"use client";

import { useEffect, useState, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import { Nav } from "@/components/Nav";
import { NpcPanel } from "@/components/NpcPanel";
import { NewCharacterForm } from "@/components/NewCharacterForm";
import type { World, NPC, Character } from "@/lib/db";

export default function WorldPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();

  const [world, setWorld] = useState<World | null>(null);
  const [npcs, setNpcs] = useState<NPC[]>([]);
  const [characters, setCharacters] = useState<Character[]>([]);
  const [loading, setLoading] = useState(true);
  const [advancing, setAdvancing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const res = await fetch(`/api/worlds/${id}`);
    if (res.status === 401) {
      router.push("/login");
      return;
    }
    if (!res.ok) {
      setError("This world could not be found.");
      setLoading(false);
      return;
    }
    const data = await res.json();
    setWorld(data.world);
    setNpcs(data.npcs);
    setCharacters(data.characters);
    setLoading(false);
  }, [id, router]);

  useEffect(() => {
    load();
  }, [load]);

  async function choose(label: string) {
    setAdvancing(true);
    setError(null);
    const res = await fetch(`/api/worlds/${id}/advance`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ choiceLabel: label }),
    });
    const data = await res.json();
    setAdvancing(false);
    if (!res.ok) {
      setError(data.error || "The story could not continue.");
      return;
    }
    setWorld(data.world);
    setNpcs(data.npcs);
  }

  if (loading) {
    return (
      <>
        <Nav />
        <main className="flex flex-1 items-center justify-center text-parchment-dim">
          Weaving your world…
        </main>
      </>
    );
  }

  if (error || !world) {
    return (
      <>
        <Nav />
        <main className="flex flex-1 flex-col items-center justify-center gap-4 text-parchment-dim">
          <p>{error || "World not found."}</p>
          <Link href="/dashboard" className="text-arcane-bright hover:underline">
            Back to your worlds
          </Link>
        </main>
      </>
    );
  }

  return (
    <>
      <Nav />
      <main className="flex-1 px-6 py-10">
        <div className="mx-auto grid max-w-6xl gap-8 lg:grid-cols-[1fr_320px]">
          <div>
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <p className="text-xs uppercase tracking-[0.3em] text-arcane-bright">
                  {world.genre} · Chapter {world.chapter}
                </p>
                <h1 className="mt-1 font-display text-3xl text-parchment">{world.title}</h1>
              </div>
              <div className="flex gap-3 text-sm">
                <Link
                  href={`/world/${id}/journal`}
                  className="rounded-full border border-white/10 px-4 py-1.5 text-parchment-dim hover:border-arcane/50 hover:text-parchment"
                >
                  Journal
                </Link>
                <Link
                  href="/dashboard"
                  className="rounded-full border border-white/10 px-4 py-1.5 text-parchment-dim hover:border-arcane/50 hover:text-parchment"
                >
                  All worlds
                </Link>
              </div>
            </div>

            <div className="glass-panel glow-border mt-6 rounded-2xl p-8">
              <p className="whitespace-pre-line text-lg leading-relaxed text-parchment">
                {world.currentScene}
              </p>
            </div>

            <div className="mt-6 space-y-3">
              {world.currentChoices.map((choice) => (
                <button
                  key={choice.id}
                  disabled={advancing}
                  onClick={() => choose(choice.label)}
                  className="glass-panel w-full rounded-xl border border-white/10 px-5 py-4 text-left text-parchment transition-all hover:border-arcane/60 hover:bg-veil/40 disabled:opacity-40"
                >
                  <span className="text-arcane-bright">›</span> {choice.label}
                </button>
              ))}
            </div>

            {advancing && <p className="mt-4 text-sm text-parchment-dim">The story is responding…</p>}
            {error && <p className="mt-4 text-sm text-danger">{error}</p>}

            <div className="mt-10">
              <h2 className="font-display text-lg text-parchment">Your characters</h2>
              <div className="mt-4 grid gap-4 sm:grid-cols-2">
                {characters.map((c) => (
                  <Link
                    key={c.id}
                    href={`/world/${id}/character/${c.id}`}
                    className="glass-panel flex items-center gap-3 rounded-xl p-4 hover:border-arcane/50"
                  >
                    {c.portraitUrl && (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={c.portraitUrl} alt={c.name} className="h-12 w-12 rounded-full bg-ink-2" />
                    )}
                    <div>
                      <p className="text-sm font-medium text-parchment">{c.name}</p>
                      <p className="text-xs text-parchment-dim">{c.archetype}</p>
                    </div>
                  </Link>
                ))}
              </div>
              <div className="mt-4">
                <NewCharacterForm worldId={id} onCreated={load} />
              </div>
            </div>
          </div>

          <aside className="space-y-4">
            <h2 className="font-display text-lg text-parchment">Characters you&apos;ve met</h2>
            {npcs.length === 0 && <p className="text-sm text-parchment-dim">No one yet.</p>}
            {npcs.map((npc) => (
              <NpcPanel key={npc.id} npc={npc} />
            ))}
          </aside>
        </div>
      </main>
    </>
  );
}
