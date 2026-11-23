INFINITE TOURNAMENT V8 - COUNTDOWN, RESULTS, AND CLOSED-MATCH HANDLING

WHAT CHANGED
- The active Matchups page, Brackets page, and admin active-match list show only scheduled/open/writing/voting matches. Closed/completed matches disappear from active views and direct matchup links show an inactive notice; canon archive records remain preserved.
- Closed matches remain in the bracket history and their winning story remains in the canon archive.
- Admins can create the opening bracket from the Admin page.
- A three-day countdown is shown on the home page, bracket page, and admin page.
- Supabase pg_cron runs an hourly server-side clock. It processes expired matches and creates the next round after the three-day interval once every match in the current round is closed.
- A sole submitted story wins automatically when the match is closed.
- If both writers submit and votes exist, the story with the most votes wins (a tie is resolved by earliest submission).
- If both writers submit and no votes exist, the database randomly selects one of the two stories once and saves that result as a 50/50 coin flip.
- A match with no submissions is not silently decided. It remains unresolved and blocks the next round; no automatic winner is invented.
- The reset function now deletes unarchived match activity while retaining archived match rows and their canon records.

INSTALLATION
1. Unzip this project and copy the contents of the itv4 folder into the root of your existing GitHub repository, replacing files when asked.
2. In Supabase, open SQL Editor and run:
   supabase/TOURNAMENT_CLOCK_AND_RESULTS_MIGRATION.sql
   Run it after the V7 migrations and the manual compatibility fixes already applied to your database.
3. In GitHub Desktop, commit the changes and push them to GitHub.
4. Vercel should deploy the pushed version automatically.
5. In Supabase SQL Editor, verify the scheduled clock exists:
   select jobid, jobname, schedule, active
   from cron.job
   where jobname = 'infinite-tournament-clock';
6. Open /admin and use “Create bracket and start tournament”. The countdown begins when the first round is created.

IMPORTANT NOTES
- Do not rerun old V7 migrations after applying this migration; use this V8 migration for the new clock/results behavior.
- The hourly database job is server-side; it does not depend on someone keeping the website open.
- The countdown shown in the browser is a display of the database deadlines, not the scheduler itself.
- The current pairing system uses random pairings within the appropriate loss tier. An odd character count can leave one character without a matchup in that round; that character remains eligible for a later round.
- No database schema or SQL migration can be verified against your live Supabase project from this ZIP alone. Review any SQL error and share its exact text before retrying.
- The migration assigns existing tournament rows to a current tournament ID. Resetting rotates that ID, so archived matches from previous tournaments remain stored but do not appear in the new tournament's bracket or countdown.
