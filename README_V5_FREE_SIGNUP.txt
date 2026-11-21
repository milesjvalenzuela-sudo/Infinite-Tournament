INFINITE TOURNAMENT V5 — FREE SIGNUP (NO CONFIRMATION EMAILS)

WHY THIS UPDATE
The built-in Supabase email sender has a very low rate limit. This update prepares the account page for password-based signup without email confirmation. The confirmation setting itself MUST be changed in the Supabase dashboard; website code cannot change a project's Auth settings.

REQUIRED SUPABASE SETTING (DO THIS ONCE)
1. Open your Supabase project.
2. Open Authentication.
3. Go to Sign In / Providers (the exact label may appear as Sign In Methods).
4. Open the Email provider settings.
5. Turn OFF “Confirm email” / “Email confirmations”.
6. Save the change.

After this setting is off, new signups should receive a session immediately and the website will send them to /characters. Existing users can continue signing in with their email and password.

IMPORTANT TRADEOFF
With email confirmation disabled, anyone can register using an email address they do not own. This removes the confirmation-email rate-limit problem, but email ownership is not verified. Password recovery by email may not work for an address the user does not control. Keep database permissions and the existing ownership checks enabled. Do not expose the Supabase service-role key in the website.

DEPLOY
1. Extract this ZIP.
2. Copy everything inside the extracted folder into your local infinite-tournament repository, replacing existing files.
3. In GitHub Desktop, commit the changes (for example: “Enable no-confirmation signup”) and Push origin.
4. Wait for Vercel's deployment to say Ready.
5. Turn off email confirmation in Supabase as described above.

DATABASE MIGRATIONS
No new SQL migration is needed for this account-page change. Do not rerun the tournament, auto-matchmaking, or writer-submission migrations.
