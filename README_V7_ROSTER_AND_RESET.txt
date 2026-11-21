INFINITE TOURNAMENT V7 — CHARACTER ROSTER + TOURNAMENT RESET

WHAT CHANGED
- Writers can register as many characters as they want.
- Each writer can select exactly one of their characters for the current tournament.
- Writers can change their selected character until the tournament begins / before that character is in active tournament play.
- Match generation uses only selected characters.
- Admin panel has a Reset entire tournament button.
- Reset deletes current rounds, matchups, submissions, and votes; it preserves the canon archive as permanent history, keeps writer accounts and all registered character profiles, resets their tournament losses/status, and clears each writer's selection so they can choose again.

INSTALL
1. Extract this ZIP.
2. Open the extracted itv4 folder.
3. Copy EVERYTHING inside itv4 into the root of your existing GitHub repository, replacing files when asked. Do not copy the outer itv4 folder itself.
4. Commit and push to GitHub. Wait for Vercel to finish deploying.
5. In Supabase, open SQL Editor -> New query.
6. Open supabase/TOURNAMENT_ROSTER_AND_RESET_MIGRATION.sql from this project, copy the entire file into the SQL editor, and click Run.
7. If you use the automatic hourly matchmaking job, also rerun the updated supabase/AUTO_MATCHMAKING_MIGRATION.sql after step 6. This updates automatic matchmaking to use selected characters only. If you do not use the automatic job, this step is not needed.

IMPORTANT
- Do not rerun the old initial migrations just for this update.
- Run the new V7 migration once. It is safe to rerun.
- Reset permanently removes current match stories and votes. It preserves the canon archive as permanent history. It does not delete accounts or registered character profiles.
- Each writer must select a character on the Characters page before admin can generate the first round.
- The reset clears selections; writers must choose one character again for the next tournament.
