# Sillage

A mobile-first community app for perfume enthusiasts — share what you're
wearing today, build a personal fragrance collection, explore notes and
scent families, and get a daily recommendation from your own collection
based on the weather and what's coming up on the calendar.

Built with **React Native + Expo Router**, **TypeScript**, and
**Supabase** (Postgres + Auth + Storage + Realtime).

## Features

- **Auth & profiles** — email/password sign-up with an onboarding flow
  (username, bio, city, and optional device-location capture for weather).
- **Collections** — mark fragrances owned / wishlist / tried, rate them,
  add personal notes and bottle size.
- **Fragrance detail pages** — top/mid/base note pyramid, an animated
  accord chart, season & occasion suitability, and which of your friends
  own it.
- **Social feed** — post "what I'm wearing today" with a photo, caption,
  mood, occasion, and an auto-captured weather snapshot. Likes, comments,
  following, all live via Supabase Realtime.
- **Smart recommendations** — a scoring engine (`src/features/recommendations/scoring.ts`)
  that recommends a fragrance from **your own collection** based on live
  weather, the current season, and upcoming holidays/occasions (or one you
  request on demand, like "date night"). Surfaced as the "Your scent for
  today" card on Home.
- **Discovery** — browse or search fragrances by note, accord, brand, or
  occasion.

## Tech stack

| | |
|---|---|
| App framework | Expo (SDK 57) + Expo Router (file-based navigation) |
| Language | TypeScript, strict mode |
| Backend | Supabase — Postgres, Auth, Storage, Realtime |
| Data fetching | TanStack Query (React Query) |
| Animation | react-native-reanimated |
| Styling | Themed `StyleSheet` design system (no CSS-in-JS library) |
| Weather | Open-Meteo (no API key) — swappable to OpenWeatherMap |
| Fonts | Fraunces (display/serif) + Manrope (body/UI) |

## Project structure

```
perfume-app/
├─ app/                     # expo-router routes — thin wrappers only
│  ├─ _layout.tsx           # root providers + Stack
│  ├─ index.tsx             # auth-gated entry redirect
│  ├─ (auth)/               # sign-in, sign-up, onboarding
│  ├─ (tabs)/               # Home, Discover, Feed, Collection, Profile
│  ├─ fragrance/[id].tsx    # fragrance detail
│  ├─ user/[username].tsx   # another user's profile
│  ├─ wear/[id].tsx         # a single feed post + comments
│  ├─ compose.tsx           # "what I'm wearing today" composer
│  └─ edit-profile.tsx
├─ src/
│  ├─ features/             # one folder per domain — api / hooks / components
│  │  ├─ auth/  profiles/  fragrances/  collection/
│  │  ├─ feed/  discovery/
│  │  └─ recommendations/   # the scoring engine — see below
│  ├─ components/ui/        # shared design-system primitives
│  ├─ theme/                # colors, typography, spacing, motion tokens
│  └─ lib/                  # supabase client, env, react-query, storage
├─ supabase/
│  ├─ migrations/           # 0001…0009, applied in order
│  └─ seed.sql              # 20 real fragrances with full note/accord data
```

Each feature folder exposes its public surface through an `index.ts`
barrel; routes in `app/` compose features together but hold no business
logic of their own.

## Setup

### 1. Create a Supabase project

Create a project at [supabase.com](https://supabase.com) (or run one
locally with the [Supabase CLI](https://supabase.com/docs/guides/local-development)).
You'll need its **Project URL** and **anon/publishable key** from
*Project Settings → API*.

### 2. Apply the database schema

The schema lives in `supabase/migrations/` as 9 plain SQL files, plus
`supabase/seed.sql` with the catalog data. Apply them in one of these ways:

**Using the Supabase CLI** (recommended):
```bash
supabase link --project-ref <your-project-ref>
supabase db push          # applies supabase/migrations/*.sql in order
psql "$(supabase db url --linked)" -f supabase/seed.sql
```

**Using `psql` directly**, if you have your project's connection string
(*Project Settings → Database → Connection string*):
```bash
for f in supabase/migrations/*.sql; do psql "$DATABASE_URL" -f "$f"; done
psql "$DATABASE_URL" -f supabase/seed.sql
```

**Using the Supabase Dashboard's SQL Editor** — paste each file from
`supabase/migrations/` in numeric order, then `supabase/seed.sql`, running
each one before moving to the next (they're ordered because later files
depend on earlier ones — e.g. RLS policies reference tables from prior
migrations).

This creates the full schema (profiles, fragrances, notes, accords,
collections, the social graph, recommendation tables), row-level security
on every table, the counter/rating triggers, and 4 RPCs the app calls
directly (`get_feed`, `toggle_like`, `search_fragrances`,
`friends_who_own`). It also seeds 24 accords, 11 occasions, 86 notes, and
20 real fragrances (Chanel No. 5, Dior Sauvage, Creed Aventus, Tom Ford
Black Orchid, and 16 more) with their full pyramids and scent profiles.

> The migrations were verified end-to-end against a local Postgres —
> applied cleanly from a blank database, then exercised with real inserts
> to confirm RLS boundaries (owner-only collections, followers-only wear
> visibility) and every RPC behave correctly.

### 3. Configure environment variables

```bash
cp .env.example .env
```

Fill in:

```bash
EXPO_PUBLIC_SUPABASE_URL=https://your-project-ref.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=your-anon-key

# Weather — Open-Meteo needs no key and is the default.
EXPO_PUBLIC_WEATHER_PROVIDER=open-meteo
# Only if you switch the line above to `openweathermap`:
EXPO_PUBLIC_OPENWEATHERMAP_API_KEY=
```

Weather provider is swappable without touching app code — see
`src/features/recommendations/api/weatherApi.ts`.

### 4. Install and run

```bash
npm install
npm start          # then press i / a / w, or scan the QR code with Expo Go
```

Other scripts:

```bash
npm run typecheck  # tsc --noEmit
npm run lint       # eslint .
npm test           # jest — unit tests for the recommendation engine
```

## The recommendation engine

`src/features/recommendations/scoring.ts` scores every fragrance in the
user's **owned** collection (never the whole catalog) against the current
context, and the top score becomes the "Your scent for today" card:

```
score = weather × 0.30 + season × 0.20 + occasion × 0.30 + personalRating × 0.20
        − freshnessPenalty × 0.25
        + signatureBias (+4 if it's your declared signature scent)
```

- **weather** — live temperature/condition (Open-Meteo) mapped to a 0-100
  affinity per accord family (`weatherProfile.ts`): light citrus/aquatic
  scents score high in heat, warm amber/woody/gourmand score high in cold,
  interpolated smoothly by actual temperature rather than fixed buckets.
- **season** — the fragrance's own `fragrance_seasons` score for the
  current meteorological season (hemisphere-aware, via the user's saved
  latitude).
- **occasion** — matches the fragrance's `fragrance_occasions` tags
  against whatever's "active": either an auto-detected upcoming holiday
  within its lead window (`occasions.ts` computes real dates for movable
  holidays like Easter and Mother's/Father's Day), or a single occasion the
  user explicitly requested (the Home screen's "date night" / "office"
  quick-request chips).
- **personalRating** — the user's own 0-10 rating for that bottle.
- **freshnessPenalty** — discourages recommending the same fragrance worn
  yesterday; decays to zero over 5 days.

All weights are exported (`DEFAULT_WEIGHTS`) rather than hardcoded, and
every term is unit tested in isolation —
`src/features/recommendations/__tests__/`.

Today's computed pick is cached in `daily_recommendations` (one row per
user per day) so revisiting Home doesn't recompute — or re-prompt for
location — until tomorrow.

## Notes on scope

- **Collections are private by design.** RLS on `collection_items`
  restricts rows to their owner; another user's profile shows their
  *public wear posts* and signature scent, not their full collection.
  "Which of your friends own this" on a fragrance's detail page uses a
  narrow `SECURITY DEFINER` RPC (`friends_who_own`) that only returns
  profile rows for people you follow, never raw collection data.
- **Weather** falls back from live device location → the coordinates saved
  on your profile during onboarding → no weather signal at all (the
  scoring function treats that as neutral, not a failure).
- `src/lib/supabase/database.types.ts` is hand-written to mirror the
  migrations exactly (including accurate `Relationships` per table, which
  `@supabase/postgrest-js` requires for typed queries). Once your project
  is live, regenerate it for a guaranteed match:
  ```bash
  npx supabase gen types typescript --project-id <ref> > src/lib/supabase/database.types.ts
  ```
