INFINITE TOURNAMENT V4 UPDATE

This update changes the matchup submission page:
- Signed-in writers only see characters they own that are actually in the matchup.
- Writers cannot submit another writer's character through the page.
- A writer cannot submit a second story for the same character in the same matchup.
- The submit button enforces the 100-character minimum before sending.
- The database function independently checks ownership, matchup membership, match status, and duplicate submissions. Do not rely on the browser alone for security.

SUPABASE
Run supabase/WRITER_SUBMISSION_SECURITY_MIGRATION.sql once in the Supabase SQL Editor. It replaces only the story-submission function and does not delete tournament data. You do NOT need to rerun TOURNAMENT_MIGRATION.sql or AUTO_MATCHMAKING_MIGRATION.sql for this update.

DEPLOY
Replace the files in your local GitHub repository with the contents of this ZIP, commit, and push. Vercel should deploy the pushed commit automatically.
