INFINITE TOURNAMENT V9 - REMOVE INACTIVE MATCHES FROM THE SITE

WHAT CHANGED
- Matchups page shows only scheduled, open, writing, and voting matches.
- Brackets page shows only active matches and hides rounds with no active matches.
- Admin active-match list and countdown ignore closed/completed matches.
- Opening an old closed/completed match URL shows an inactive notice instead of the old matchup and stories.
- No database rows are deleted. Canon archive, votes, submissions, and match history remain stored.

INSTALLATION
1. Extract this ZIP.
2. Copy everything inside itv4 into the root of your existing GitHub repository, replacing files.
3. Commit and push with GitHub Desktop. Vercel should deploy automatically.
4. No SQL migration is required for this update.
