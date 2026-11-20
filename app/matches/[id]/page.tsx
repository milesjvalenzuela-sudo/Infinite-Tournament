"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { supabase, friendlyError } from "@/lib/supabase";

type Character = { id: string; name: string };
type Submission = {
  id: string;
  character_id: string;
  writer_id: string;
  content: string;
  created_at: string;
};

export default function MatchPage() {
  const params = useParams<{ id: string }>();
  const id = params.id;
  const [match, setMatch] = useState<any>(null);
  const [user, setUser] = useState<any>(null);
  const [submissions, setSubmissions] = useState<Submission[]>([]);
  const [story, setStory] = useState("");
  const [character, setCharacter] = useState("");
  const [myMatchCharacters, setMyMatchCharacters] = useState<Character[]>([]);
  const [message, setMessage] = useState("Loading matchup…");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  async function load() {
    setLoading(true);
    setMessage("");
    try {
      const [{ data: matchData, error: matchError }, { data: authData }, { data: submissionData, error: submissionError }] = await Promise.all([
        supabase.from("matches").select("*").eq("id", id).single(),
        supabase.auth.getUser(),
        supabase.from("submissions").select("*").eq("match_id", id).order("created_at"),
      ]);
      if (matchError) throw matchError;
      if (submissionError) throw submissionError;

      const currentUser = authData.user;
      const matchCharacterIds = [matchData.character_a_id, matchData.character_b_id].filter(Boolean);
      const [{ data: matchCharacters, error: namesError }, ownedResult] = await Promise.all([
        matchCharacterIds.length
          ? supabase.from("characters").select("id,name").in("id", matchCharacterIds)
          : Promise.resolve({ data: [], error: null } as any),
        currentUser && matchCharacterIds.length
          ? supabase.from("characters").select("id,name").eq("owner_id", currentUser.id).in("id", matchCharacterIds)
          : Promise.resolve({ data: [], error: null } as any),
      ]);
      if (namesError) throw namesError;
      if (ownedResult.error) throw ownedResult.error;

      const names = Object.fromEntries((matchCharacters || []).map((item: Character) => [item.id, item.name]));
      setMatch({
        ...matchData,
        a_name: names[matchData.character_a_id],
        b_name: names[matchData.character_b_id],
      });
      setUser(currentUser);
      setSubmissions((submissionData || []) as Submission[]);
      setMyMatchCharacters((ownedResult.data || []) as Character[]);
      setCharacter("");
    } catch (error) {
      setMessage(friendlyError(error));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
    // `id` identifies the matchup being viewed.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  const submittedCharacterIds = new Set(submissions.map((item) => item.character_id));
  const charactersStillNeedingStories = myMatchCharacters.filter((item) => !submittedCharacterIds.has(item.id));
  const matchupAcceptsStories = match && ["open", "writing"].includes(match.status);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!character) {
      setMessage("Choose one of your own characters in this matchup first.");
      return;
    }
    setSaving(true);
    setMessage("");
    try {
      const { error } = await supabase.rpc("submit_match_story", {
        p_match_id: id,
        p_character_id: character,
        p_content: story,
      });
      if (error) throw error;
      setStory("");
      setMessage("Your story was submitted successfully.");
      await load();
    } catch (error) {
      setMessage(friendlyError(error));
    } finally {
      setSaving(false);
    }
  }

  if (loading && !match) return <main className="shell page"><p>{message}</p></main>;
  if (!match) return <main className="shell page"><p className="notice">{message || "Matchup not found."}</p><Link href="/matches">Back to matchups</Link></main>;

  return (
    <main className="shell page">
      <Link href="/matches" className="back">← All matchups</Link>
      <p className="eyebrow">MATCHUP</p>
      <h1>{match.a_name || "Character A"} <em>vs.</em> {match.b_name || "Character B"}</h1>
      <p className="muted">Stage: {match.bracket_stage || "Tournament"} · Status: {match.status}</p>

      <section className="panel">
        <h2>Submit your version of the fight</h2>
        {!user ? (
          <p><Link href="/account">Sign in</Link> to submit a story for your character.</p>
        ) : !matchupAcceptsStories ? (
          <p className="muted">This matchup is not currently accepting stories.</p>
        ) : myMatchCharacters.length === 0 ? (
          <p className="muted">Neither character in this matchup belongs to your account, so you cannot submit a story here.</p>
        ) : charactersStillNeedingStories.length === 0 ? (
          <p className="muted">You have already submitted a story for each of your characters in this matchup.</p>
        ) : (
          <form onSubmit={submit}>
            <label htmlFor="your-character">Your character in this matchup</label>
            <select id="your-character" required value={character} onChange={(event) => setCharacter(event.target.value)}>
              <option value="">Choose your character</option>
              {charactersStillNeedingStories.map((item) => (
                <option key={item.id} value={item.id}>{item.name}</option>
              ))}
            </select>
            <label htmlFor="battle-story">Battle story</label>
            <textarea
              id="battle-story"
              required
              minLength={100}
              rows={12}
              value={story}
              onChange={(event) => setStory(event.target.value)}
              placeholder="Write the battle. Your character must win this version…"
            />
            <p className="muted tiny">Minimum 100 characters. You can only submit for a character registered to your account.</p>
            <button className="button primary" disabled={saving || !character || story.trim().length < 100}>
              {saving ? "Submitting…" : "Submit story"}
            </button>
          </form>
        )}
      </section>

      <section className="section">
        <h2>Submitted stories</h2>
        {submissions.length ? submissions.map((item) => (
          <article className="panel" key={item.id}>
            <p className="muted tiny">Submitted {new Date(item.created_at).toLocaleString()}</p>
            <p className="story">{item.content}</p>
          </article>
        )) : <p className="muted">No stories have been submitted yet.</p>}
      </section>
      {message && <p className="notice">{message}</p>}
    </main>
  );
}
