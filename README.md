# Lucid AI

This is a **fully functional, end-to-end working version** of the Lucid AI core loop:
sign up → log in → create a world → the Story AI generates an opening scene + an NPC →
make choices → the story continues, NPC relationship/emotion updates → everything logs
to a Story Journal → create characters with stats and an AI-generated portrait.

It runs **right now, with zero setup and no API keys**, using a built-in mock AI
generator. When the real API keys are provided, you flip one switch (below) and the
entire app starts using real AI generation instead — no other code changes needed.

---

## 1. Run it (every teammate, first time)

```bash
npm install
npm run dev
```

Open http://localhost:3000 — sign up, and play through. Data is stored locally in
`data/db.json` (auto-created, gitignored — everyone has their own local data, so you
won't step on each other's test accounts).

## 2. Going live with real AI (once API keys are provided)

1. Copy `.env.example` to `.env.local`
2. Paste in **either** `OPENAI_API_KEY` or `ANTHROPIC_API_KEY`
3. Restart the dev server

That's it. Look at `src/lib/ai.ts` — it's the **only** file that talks to an AI
provider. Every "AI module" from the spec (Story AI, NPC AI, Memory AI, Emotion AI,
Relationship AI, Image AI) is a function in that one file. If your team gets a
different/custom AI backend later, this is the only file to edit.

## 3. What's actually implemented

| Spec feature | Status |
|---|---|
| Sign up / Log in (sessions via secure cookie) | working |
| Dashboard — list + create worlds | working |
| Story AI — opening scene + branching choices | working (mock or real, see above) |
| NPC AI — persistent NPC, personality-aware | working |
| Memory AI — full choice/scene history feeds every AI call | working |
| Relationship AI — trust score -100..100, shifts per choice | working |
| Emotion AI — NPC mood tag derived from relationship/context | working |
| Story Journal / Timeline — auto-logged chapter-by-chapter | working |
| Character Profile — stats + AI portrait | working |
| Image AI — portraits for NPCs, characters, world covers | working (DiceBear mock or real image API) |
| World AI (economy/politics/weather sim) | not built — out of MVP scope, see team plan |
| Voice AI, AI Cinematics, Multiplayer, Marketplace | not built — Phase 2 roadmap, intentionally cut for the deadline |

## 4. Project structure (so everyone knows where to work)

```
src/
  app/
    page.tsx                        Landing page
    login/, signup/                 Auth pages
    dashboard/                      World list + "new world" flow
    world/[id]/                     Story screen (the core game loop)
    world/[id]/journal/             Story timeline
    world/[id]/character/[id]/      Character profile
    api/                            All backend routes (auth, worlds, advance, journal, characters)
  components/                       Reusable UI (Nav, WorldCard, NpcPanel, forms)
  lib/
    db.ts                           Data layer — swap this for Postgres later, nothing else changes
    auth.ts                         Password hashing + session cookies
    ai.ts                           THE AI ORCHESTRATOR — all AI calls live here
```

## 5. Swapping the data layer for a real database later

Right now `src/lib/db.ts` reads/writes a JSON file so the whole team can run this with
zero setup. When you're ready to move to Postgres/Supabase (recommended next step per
the team plan), only this one file needs to change — every route and page calls
`db.getWorld()`, `db.createUser()`, etc., and doesn't know or care how it's stored.

## 6. Next steps for the team (see the full plan for day-by-day breakdown)

- Wire `.env.local` with real keys the moment they're provided
- Move `db.ts` to Postgres (Supabase recommended — fastest to set up)
- Add the "Should Have" features (world weather/time flags, illustrated cinematic
  moments for major story beats) if the Must-Haves are solid with days to spare
- Deploy to Vercel for the live demo URL
