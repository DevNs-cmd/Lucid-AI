"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { Nav } from "@/components/Nav";
import type { Character, World } from "@/lib/db";

export default function CharacterProfilePage() {
  const { id, characterId } = useParams<{ id: string; characterId: string }>();
  const [character, setCharacter] = useState<Character | null>(null);
  const [world, setWorld] = useState<World | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch(`/api/worlds/${id}`)
      .then((r) => r.json())
      .then((data) => {
        setWorld(data.world || null);
        const found = (data.characters || []).find((c: Character) => c.id === characterId);
        setCharacter(found || null);
      })
      .finally(() => setLoading(false));
  }, [id, characterId]);

  if (loading) {
    return (
      <>
        <Nav />
        <main className="flex flex-1 items-center justify-center text-parchment-dim">Loading…</main>
      </>
    );
  }

  if (!character) {
    return (
      <>
        <Nav />
        <main className="flex flex-1 flex-col items-center justify-center gap-4 text-parchment-dim">
          <p>Character not found.</p>
          <Link href={`/world/${id}`} className="text-arcane-bright hover:underline">
            Back to story
          </Link>
        </main>
      </>
    );
  }

  const stats: [string, number][] = [
    ["Courage", character.stats.courage],
    ["Wisdom", character.stats.wisdom],
    ["Charm", character.stats.charm],
  ];

  return (
    <>
      <Nav />
      <main className="flex-1 px-6 py-10">
        <div className="mx-auto max-w-2xl">
          <Link href={`/world/${id}`} className="text-sm text-parchment-dim hover:text-parchment">
            ← Back to {world?.title}
          </Link>

          <div className="glass-panel glow-border mt-4 rounded-2xl p-8 text-center">
            {character.portraitUrl && (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={character.portraitUrl}
                alt={character.name}
                className="mx-auto h-28 w-28 rounded-full border border-white/10 bg-ink-2"
              />
            )}
            <h1 className="mt-4 font-display text-2xl text-parchment">{character.name}</h1>
            <p className="text-sm text-arcane-bright">{character.archetype}</p>

            <div className="mt-8 space-y-4 text-left">
              {stats.map(([label, value]) => (
                <div key={label}>
                  <div className="flex justify-between text-xs text-parchment-dim">
                    <span>{label}</span>
                    <span>{value}</span>
                  </div>
                  <div className="mt-1 h-1.5 w-full overflow-hidden rounded-full bg-ink-2">
                    <div className="h-full rounded-full bg-arcane" style={{ width: `${value}%` }} />
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
