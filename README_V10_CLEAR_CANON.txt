INFINITE TOURNAMENT V10 - ADMIN CLEAR CANON

WHAT CHANGED
- Adds an administrator-only "Clear entire canon archive" command to the admin page.
- Requires two confirmation prompts before running.
- Displays the number of archive entries removed.
- Deletes only rows from public.canon_archive. It does not delete matches, submissions, votes, characters, or writer accounts.

INSTALLATION
1. Extract this ZIP.
2. Copy everything inside itv4 into the root of your existing GitHub repository, replacing files.
3. In Supabase SQL Editor, run supabase/ADMIN_CLEAR_CANON_MIGRATION.sql once.
4. Commit and push the files with GitHub Desktop. Wait for Vercel to deploy.
5. The command appears in the Admin page for administrator accounts only.

WARNING
Clearing the canon archive is permanent. There is no undo. Underlying match and voting records remain in the database, but the public archive entries are removed.
