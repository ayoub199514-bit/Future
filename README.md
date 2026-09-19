# FURI Mining Algeria v4

## GitHub Pages
The deployable entry point is now **`/index.html` at repository root**.
This avoids GitHub Pages continuing to serve an older `app/index.html`/v2 page when the Pages source is `main` + root.

Expected project URL:
`https://ayoub199514-bit.github.io/Future/`

## Supabase
1. Create/open your Supabase project.
2. Run `supabase/migrations/001_v3.sql` in SQL Editor.
3. Edit **root `config.js`** with only:
   - Supabase Project URL
   - Supabase Publishable Key
4. Never place a Service Role Key, database password, private key, or seed phrase in this repository.

## GitHub Pages settings
Repository **Settings → Pages → Build and deployment**:
- Source: Deploy from a branch
- Branch: `main`
- Folder: `/ (root)`

After saving, wait for the Pages deployment to complete, then hard-refresh the site.

## Current scope
- Algeria-only profile rules in the database.
- 18+ validation.
- Supabase Auth.
- Profiles and dynamic age.
- RLS and admin role separation.
- Plans and FURI ledger UI.
- **Real USDT settlement is not enabled yet.**

Before enabling real-money deposits/withdrawals, add a server-side settlement layer, transaction monitoring, idempotency, audit logging, withdrawal authorization, reserve controls, and applicable legal/compliance review.
