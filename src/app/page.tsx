import Link from "next/link";
import { Nav } from "@/components/Nav";

const FEATURES = [
  {
    title: "Story AI",
    desc: "Generates an evolving main plot, side quests, and dialogue that respond to every choice you make.",
  },
  {
    title: "NPC AI",
    desc: "Every character remembers what you did. Personality, mood, and history persist across the whole story.",
  },
  {
    title: "Relationship AI",
    desc: "Gifts, betrayals, promises, and fights all shift trust — and trust changes what NPCs will do for you.",
  },
  {
    title: "World AI",
    desc: "The setting keeps moving even when you're not looking: weather, politics, and events evolve on their own.",
  },
  {
    title: "Image AI",
    desc: "Characters, locations, and key moments are illustrated automatically as your story unfolds.",
  },
  {
    title: "Story Journal",
    desc: "Every chapter, quest, and turning point is logged automatically — your personal history of the world.",
  },
];

export default function LandingPage() {
  return (
    <>
      <Nav />
      <main className="flex-1">
        {/* Hero */}
        <section className="relative overflow-hidden px-6 pb-24 pt-20 sm:pt-28">
          <div
            className="pointer-events-none absolute -top-40 left-1/2 h-[540px] w-[900px] -translate-x-1/2 rounded-full opacity-30 blur-3xl"
            style={{ background: "radial-gradient(closest-side, #8B5CF6, transparent)" }}
          />
          <div className="relative mx-auto max-w-3xl text-center">
            <p className="mb-6 font-display text-sm uppercase tracking-[0.3em] text-arcane-bright">
              An AI-Powered Interactive Storytelling Platform
            </p>
            <h1 className="font-display text-4xl leading-tight text-parchment sm:text-6xl">
              You don&apos;t just read the story.
              <br />
              <span className="text-arcane-bright">You live it. You shape it.</span>
            </h1>
            <p className="mx-auto mt-6 max-w-xl text-lg text-parchment-dim">
              Every decision changes the world. Every character remembers you. No two journeys
              through Lucid AI are ever the same.
            </p>
            <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
              <Link
                href="/signup"
                className="rounded-full bg-arcane px-8 py-3 font-medium text-white shadow-[0_0_30px_rgba(139,92,246,0.5)] transition-transform hover:scale-105"
              >
                Begin your first world
              </Link>
              <Link
                href="/login"
                className="rounded-full border border-white/15 px-8 py-3 font-medium text-parchment-dim transition-colors hover:border-arcane/50 hover:text-parchment"
              >
                I already have a world
              </Link>
            </div>
          </div>
        </section>

        {/* Problem framing */}
        <section className="border-t border-white/5 px-6 py-20">
          <div className="mx-auto max-w-5xl">
            <p className="font-display text-sm uppercase tracking-[0.3em] text-arcane-bright">
              Why Lucid AI
            </p>
            <h2 className="mt-3 max-w-2xl font-display text-3xl text-parchment sm:text-4xl">
              Static stories end. Yours won&apos;t.
            </h2>
            <p className="mt-4 max-w-2xl text-parchment-dim">
              Streaming shows, novels, and scripted games all eventually repeat — the content is
              finite, or it doesn&apos;t remember you. Lucid AI generates an infinite, evolving
              world that keeps changing even after you log off, and keeps every promise you made.
            </p>
          </div>
        </section>

        {/* Features grid */}
        <section className="border-t border-white/5 px-6 py-20">
          <div className="mx-auto max-w-5xl">
            <p className="font-display text-sm uppercase tracking-[0.3em] text-arcane-bright">
              The engine underneath
            </p>
            <h2 className="mt-3 font-display text-3xl text-parchment sm:text-4xl">
              Six AI systems, one living story
            </h2>
            <div className="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
              {FEATURES.map((f) => (
                <div key={f.title} className="glass-panel glow-border rounded-2xl p-6">
                  <h3 className="font-display text-lg text-arcane-bright">{f.title}</h3>
                  <p className="mt-2 text-sm leading-relaxed text-parchment-dim">{f.desc}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* CTA */}
        <section className="border-t border-white/5 px-6 py-24 text-center">
          <h2 className="font-display text-3xl text-parchment sm:text-4xl">
            Infinite worlds. Infinite stories.
            <br />
            <span className="text-arcane-bright">Infinite you.</span>
          </h2>
          <Link
            href="/signup"
            className="mt-8 inline-block rounded-full bg-arcane px-8 py-3 font-medium text-white shadow-[0_0_30px_rgba(139,92,246,0.5)] transition-transform hover:scale-105"
          >
            Create your first character
          </Link>
        </section>
      </main>

      <footer className="border-t border-white/5 px-6 py-8 text-center text-xs text-parchment-dim/60">
        Lucid AI — built for the Lucid AI internship team.
      </footer>
    </>
  );
}
