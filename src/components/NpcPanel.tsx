import type { NPC } from "@/lib/db";

const EMOTION_COLOR: Record<string, string> = {
  happy: "#6ee7b7",
  hopeful: "#93c5fd",
  neutral: "#b9b0d6",
  suspicious: "#facc15",
  angry: "#f87171",
  sad: "#a5b4fc",
  afraid: "#fb923c",
};

export function NpcPanel({ npc }: { npc: NPC }) {
  const pct = ((npc.relationship + 100) / 200) * 100;
  const color = EMOTION_COLOR[npc.emotion] || "#b9b0d6";

  return (
    <div className="glass-panel rounded-xl p-4">
      <div className="flex items-center gap-3">
        {npc.portraitUrl && (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={npc.portraitUrl} alt={npc.name} className="h-12 w-12 rounded-full bg-ink-2" />
        )}
        <div>
          <p className="text-sm font-medium text-parchment">{npc.name}</p>
          <p className="text-xs capitalize" style={{ color }}>
            {npc.emotion}
          </p>
        </div>
      </div>
      <p className="mt-2 text-xs text-parchment-dim">{npc.personality}</p>
      <div className="mt-3">
        <div className="flex justify-between text-[10px] uppercase tracking-wider text-parchment-dim/70">
          <span>Hostile</span>
          <span>Devoted</span>
        </div>
        <div className="mt-1 h-1.5 w-full overflow-hidden rounded-full bg-ink-2">
          <div
            className="h-full rounded-full bg-gradient-to-r from-danger via-gold to-success transition-all"
            style={{ width: `${pct}%` }}
          />
        </div>
      </div>
    </div>
  );
}
