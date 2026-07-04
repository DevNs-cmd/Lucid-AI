"use client";

import { useState, FormEvent } from "react";
import { useRouter } from "next/navigation";

const GENRES = ["Fantasy", "Sci-Fi", "Mystery", "Horror", "Romance", "Post-Apocalyptic"];

export function NewWorldForm() {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [title, setTitle] = useState("");
  const [genre, setGenre] = useState(GENRES[0]);
  const [premise, setPremise] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    const res = await fetch("/api/worlds", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title, genre, premise }),
    });
    const data = await res.json();
    setLoading(false);
    if (!res.ok) {
      setError(data.error || "Something went wrong.");
      return;
    }
    router.push(`/world/${data.world.id}`);
  }

  if (!open) {
    return (
      <button
        onClick={() => setOpen(true)}
        className="glass-panel glow-border w-full rounded-2xl border-dashed p-6 text-left text-parchment-dim transition-colors hover:text-parchment"
      >
        <span className="font-display text-lg text-arcane-bright">+ New world</span>
        <p className="mt-1 text-sm">Describe a premise. Lucid AI generates the rest.</p>
      </button>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="glass-panel glow-border rounded-2xl p-6">
      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <label className="mb-1.5 block text-xs text-parchment-dim">World title</label>
          <input
            required
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="The Ashen Court"
            className="w-full rounded-lg border border-white/10 bg-ink-2 px-3.5 py-2.5 text-sm text-parchment outline-none focus:border-arcane"
          />
        </div>
        <div>
          <label className="mb-1.5 block text-xs text-parchment-dim">Genre</label>
          <select
            value={genre}
            onChange={(e) => setGenre(e.target.value)}
            className="w-full rounded-lg border border-white/10 bg-ink-2 px-3.5 py-2.5 text-sm text-parchment outline-none focus:border-arcane"
          >
            {GENRES.map((g) => (
              <option key={g} value={g}>
                {g}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="mt-4">
        <label className="mb-1.5 block text-xs text-parchment-dim">Premise</label>
        <textarea
          required
          value={premise}
          onChange={(e) => setPremise(e.target.value)}
          rows={3}
          placeholder="A dethroned queen returns to her city in disguise, seeking whoever betrayed her..."
          className="w-full rounded-lg border border-white/10 bg-ink-2 px-3.5 py-2.5 text-sm text-parchment outline-none focus:border-arcane"
        />
      </div>

      {error && <p className="mt-3 text-sm text-danger">{error}</p>}

      <div className="mt-5 flex gap-3">
        <button
          type="submit"
          disabled={loading}
          className="rounded-lg bg-arcane px-5 py-2.5 text-sm font-medium text-white shadow-[0_0_20px_rgba(139,92,246,0.4)] transition-opacity hover:opacity-90 disabled:opacity-50"
        >
          {loading ? "Generating your world…" : "Generate opening scene"}
        </button>
        <button
          type="button"
          onClick={() => setOpen(false)}
          className="rounded-lg border border-white/10 px-5 py-2.5 text-sm text-parchment-dim hover:text-parchment"
        >
          Cancel
        </button>
      </div>
    </form>
  );
}
