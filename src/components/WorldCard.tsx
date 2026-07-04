import Link from "next/link";
import type { World } from "@/lib/db";

export function WorldCard({ world }: { world: World }) {
  return (
    <Link
      href={`/world/${world.id}`}
      className="glass-panel glow-border group block overflow-hidden rounded-2xl transition-transform hover:-translate-y-1"
    >
      <div
        className="h-32 w-full bg-cover bg-center"
        style={{
          backgroundImage: world.coverUrl ? `url(${world.coverUrl})` : undefined,
          backgroundColor: "#191430",
        }}
      />
      <div className="p-5">
        <p className="text-xs uppercase tracking-wider text-arcane-bright">{world.genre}</p>
        <h3 className="mt-1 font-display text-lg text-parchment group-hover:text-arcane-bright">
          {world.title}
        </h3>
        <p className="mt-1.5 line-clamp-2 text-sm text-parchment-dim">{world.premise}</p>
        <p className="mt-3 text-xs text-parchment-dim/70">Chapter {world.chapter}</p>
      </div>
    </Link>
  );
}
