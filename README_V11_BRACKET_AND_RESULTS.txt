INFINITE TOURNAMENT V11 — BRACKET DISPLAY, LIVE VOTE COUNTS, AND RESULTS

WHAT CHANGED
- Brackets now display character names on bracket lines rather than matchup rectangles.
- Winners Bracket, Elimination Bracket, and Grand Final are shown separately.
- Closed rounds remain visible while the tournament is ongoing.
- Once a Grand Final match has a finalist eliminated (two losses), the bracket display is cleared and shows that the tournament is complete. Historical match and canon records remain in Supabase.
- Active matchup detail pages show the current vote count beside each submitted story and refresh every 15 seconds.
- The active Matchups page shows recent completed results and winners.
- A closed matchup's direct page shows who won and how the result was decided.

INSTALL
1. Extract this ZIP and copy everything inside itv4 into your existing GitHub repository folder, replacing files.
2. In Supabase SQL Editor, run supabase/BRACKET_DISPLAY_AND_VOTE_COUNTS_MIGRATION.sql once.
3. Commit and push in GitHub Desktop. Wait for Vercel to deploy.

IMPORTANT LIMITATION
The existing V10 database matchmaking function pairs eligible characters round by round. It does not store explicit feeder-slot links between each pair of matches. This update presents the actual recorded double-elimination rounds in a traditional bracket-style visual, but does not add seeded bracket-slot routing. The existing double-elimination result/loss rules remain in place.
