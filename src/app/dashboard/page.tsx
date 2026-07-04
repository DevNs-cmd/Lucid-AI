import { redirect } from "next/navigation";
import { getSessionUserId } from "@/lib/auth";
import { db } from "@/lib/db";
import { Nav } from "@/components/Nav";
import { NewWorldForm } from "@/components/NewWorldForm";
import { WorldCard } from "@/components/WorldCard";

export default async function DashboardPage() {
  const userId = await getSessionUserId();
  if (!userId) redirect("/login");

  const user = db.getUserById(userId);
  const worlds = db.getWorldsByUser(userId).sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));

  return (
    <>
      <Nav />
      <main className="flex-1 px-6 py-12">
        <div className="mx-auto max-w-5xl">
          <div className="flex flex-wrap items-end justify-between gap-4">
            <div>
              <p className="font-display text-sm uppercase tracking-[0.3em] text-arcane-bright">
                Welcome back
              </p>
              <h1 className="mt-1 font-display text-3xl text-parchment">{user?.name}&apos;s worlds</h1>
            </div>
          </div>

          <div className="mt-10">
            <NewWorldForm />
          </div>

          <div className="mt-10">
            {worlds.length === 0 ? (
              <div className="glass-panel rounded-2xl p-10 text-center text-parchment-dim">
                No worlds yet. Create your first one above — Lucid AI will generate the opening
                scene, your first NPC, and a cover image instantly.
              </div>
            ) : (
              <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
                {worlds.map((w) => (
                  <WorldCard key={w.id} world={w} />
                ))}
              </div>
            )}
          </div>
        </div>
      </main>
    </>
  );
}
