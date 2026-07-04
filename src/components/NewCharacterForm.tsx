"use client";

import { useState, FormEvent } from "react";

export function NewCharacterForm({ worldId, onCreated }: { worldId: string; onCreated: () => void }) {
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [archetype, setArchetype] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    const res = await fetch(`/api/worlds/${worldId}/characters`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name, archetype }),
    });
    setLoading(false);
    if (res.ok) {
      setName("");
      setArchetype("");
      setOpen(false);
      onCreated();
    }
  }

  if (!open) {
    return (
      <button onClick={() => setOpen(true)} className="text-sm text-arcane-bright hover:underline">
        + Create a character
      </button>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="glass-panel flex flex-wrap items-end gap-3 rounded-xl p-4">
      <div>
        <label className="mb-1 block text-xs text-parchment-dim">Name</label>
        <input
          required
          value={name}
          onChange={(e) => setName(e.target.value)}
          className="rounded-lg border border-white/10 bg-ink-2 px-3 py-2 text-sm text-parchment outline-none focus:border-arcane"
        />
      </div>
      <div>
        <label className="mb-1 block text-xs text-parchment-dim">Archetype</label>
        <input
          required
          placeholder="Rogue diplomat"
          value={archetype}
          onChange={(e) => setArchetype(e.target.value)}
          className="rounded-lg border border-white/10 bg-ink-2 px-3 py-2 text-sm text-parchment outline-none focus:border-arcane"
        />
      </div>
      <button
        type="submit"
        disabled={loading}
        className="rounded-lg bg-arcane px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
      >
        {loading ? "Creating…" : "Create"}
      </button>
      <button type="button" onClick={() => setOpen(false)} className="text-sm text-parchment-dim">
        Cancel
      </button>
    </form>
  );
}
