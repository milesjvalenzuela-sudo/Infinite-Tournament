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

## Automatic matchmaking (Version 3 update)

After the original `supabase/TOURNAMENT_MIGRATION.sql` has been run, run
`supabase/AUTO_MATCHMAKING_MIGRATION.sql` in the Supabase SQL Editor. It installs
an hourly scheduled check that creates a new Winners Bracket round when at least
two undefeated characters are eligible, or an Elimination Bracket round when at
least two one-loss characters are eligible. It waits until all existing matches
are closed and at least three days have passed since the previous round. Pairings
prefer opponents who have not faced each other before. If the eligible count is
odd, one character sits out.

This is an automatic matchmaking foundation, not a complete implementation of
the grand-final reset or every double-elimination edge case. Admins still review
and close matches. The Supabase project must have the `pg_cron` extension available.

## Make your account an administrator

After signing up, run this once in Supabase SQL Editor, replacing the email with
the exact email used for your tournament account:

```sql
update public.profiles
set role = 'admin'
where id = (select id from auth.users where email = 'YOUR_EMAIL_ADDRESS');
```

Then sign out and sign back in, and visit `/admin` on your deployed website.


## V5: Free signup without confirmation emails
See `README_V5_FREE_SIGNUP.txt`. This requires turning off Supabase Email confirmation in the dashboard. No SQL migration is needed. Disabling confirmation means email addresses are not verified.
