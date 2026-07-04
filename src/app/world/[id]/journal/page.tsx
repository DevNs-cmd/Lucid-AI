"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { Nav } from "@/components/Nav";
import type { StoryEvent, World } from "@/lib/db";

export default function JournalPage() {
  const { id } = useParams<{ id: string }>();
  const [events, setEvents] = useState<StoryEvent[]>([]);
  const [world, setWorld] = useState<World | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch(`/api/worlds/${id}/journal`)
      .then((r) => r.json())
      .then((data) => {
        setEvents(data.events || []);
        setWorld(data.world || null);
      })
      .finally(() => setLoading(false));
  }, [id]);

  return (
    <>
      <Nav />
      <main className="flex-1 px-6 py-10">
        <div className="mx-auto max-w-2xl">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs uppercase tracking-[0.3em] text-arcane-bright">Story Journal</p>
              <h1 className="mt-1 font-display text-3xl text-parchment">{world?.title || "…"}</h1>
            </div>
            <Link
              href={`/world/${id}`}
              className="rounded-full border border-white/10 px-4 py-1.5 text-sm text-parchment-dim hover:border-arcane/50 hover:text-parchment"
            >
              Back to story
            </Link>
          </div>

          {loading ? (
            <p className="mt-8 text-parchment-dim">Loading your history…</p>
          ) : (
            <ol className="mt-8 space-y-6 border-l border-white/10 pl-6">
              {events.map((e) => (
                <li key={e.id} className="relative">
                  <span
                    className={`absolute -left-[29px] top-1.5 h-2.5 w-2.5 rounded-full ${
                      e.type === "choice" ? "bg-arcane-bright" : "bg-gold"
                    }`}
                  />
                  <p className="text-[11px] uppercase tracking-wider text-parchment-dim/60">
                    {new Date(e.createdAt).toLocaleString()} · {e.type === "choice" ? "Your choice" : "Story"}
                  </p>
                  <p className="mt-1 whitespace-pre-line text-sm leading-relaxed text-parchment">
                    {e.text}
                  </p>
                </li>
              ))}
            </ol>
          )}
        </div>
      </main>
    </>
  );
}
