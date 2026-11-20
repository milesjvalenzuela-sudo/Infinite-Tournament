# The Infinite Tournament — Version 2

This is the Next.js/Supabase website project. It includes account creation/sign-in, character registration, match viewing, story submission, public voting, brackets, canon archive, and an admin interface.

## Setup
1. Install Node.js 20 or newer.
2. Run `npm install`.
3. Copy `.env.example` to `.env.local` and fill in the Supabase project URL and publishable key.
4. Run `npm run dev`.

## Supabase
Run `supabase/TOURNAMENT_MIGRATION.sql` in Supabase SQL Editor after reviewing it. It adds compatibility columns and secure RPC functions used by the site.

The public voting feature uses a browser-generated voter token. It prevents casual repeat votes in the same browser, but it is not strong identity verification and can be bypassed by clearing browser storage or using another browser. Add CAPTCHA/rate limiting before treating voting as tamper-proof.

Admin access is controlled by `profiles.role = 'admin'`. Promote your own profile only after creating your account, using the one-time SQL statement documented at the bottom of the migration file.

## Deployment
Push the project to GitHub, then import/update the project in Vercel. Configure:
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`

Never put a Supabase secret/service-role key in browser code or a `NEXT_PUBLIC_` variable.
