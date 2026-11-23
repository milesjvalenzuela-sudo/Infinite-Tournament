"use client";

import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";

type ClockState = { target: number | null; label: string; note: string };

function formatRemaining(ms: number) {
  const total = Math.max(0, Math.floor(ms / 1000));
  const days = Math.floor(total / 86400);
  const hours = Math.floor((total % 86400) / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const seconds = total % 60;
  return `${days}d ${hours}h ${minutes}m ${seconds}s`;
}

export default function TournamentCountdown() {
  const [clock, setClock] = useState<ClockState>({ target: null, label: "Tournament countdown", note: "Waiting for the administrator to create the bracket." });
  const [now, setNow] = useState(Date.now());

  useEffect(() => {
    let alive = true;
    const load = async () => {
      const { data: state, error: stateError } = await supabase.from("tournament_state").select("current_tournament_id").eq("singleton", true).single();
      if (stateError || !state) {
        if (alive) setClock({ target: null, label: "Tournament countdown", note: "Countdown is temporarily unavailable. Apply the V8 database migration first." });
        return;
      }
      const [{ data: active, error: activeError }, { data: rounds, error: roundsError }] = await Promise.all([
        supabase.from("matches").select("id,closes_at,status").eq("tournament_id", state.current_tournament_id).in("status", ["scheduled", "open", "writing", "voting"]).not("closes_at", "is", null).order("closes_at", { ascending: true }).limit(1),
        supabase.from("tournament_rounds").select("starts_at,round_number").eq("tournament_id", state.current_tournament_id).order("round_number", { ascending: false }).limit(1),
      ]);
      if (!alive) return;
      if (activeError || roundsError) {
        setClock({ target: null, label: "Tournament countdown", note: "Countdown is temporarily unavailable." });
        return;
      }
      if (active?.length) {
        setClock({ target: new Date(active[0].closes_at).getTime(), label: "Current round closes in", note: "Matches are accepting stories or votes until the deadline. Results are processed automatically." });
        return;
      }
      if (rounds?.length) {
        const next = new Date(rounds[0].starts_at).getTime() + 3 * 24 * 60 * 60 * 1000;
        setClock({ target: next, label: "Next round eligible to begin in", note: "The next round starts after the three-day interval and once every current match is closed." });
        return;
      }
      setClock({ target: null, label: "Tournament countdown", note: "Waiting for the administrator to create the bracket." });
    };
    load();
    const refresh = window.setInterval(load, 60_000);
    const ticker = window.setInterval(() => setNow(Date.now()), 1000);
    return () => { alive = false; window.clearInterval(refresh); window.clearInterval(ticker); };
  }, []);

  return <section className="panel countdown-panel">
    <p className="eyebrow">TOURNAMENT CLOCK</p>
    <h2>{clock.label}</h2>
    <div className="countdown-time">{clock.target === null ? "—" : formatRemaining(clock.target - now)}</div>
    <p className="muted tiny">{clock.note}</p>
  </section>;
}
