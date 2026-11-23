import Link from "next/link";
import TournamentCountdown from "./tournament-countdown";

export default function Home() {
  return <main className="shell">
    <section className="hero">
      <p className="eyebrow">THE ARENA IS OPEN</p>
      <h1>One arena.<br/><em>Infinite</em> possibilities.</h1>
      <p className="intro">Original characters. Writer-crafted battles. A public vote decides which story becomes canon. Enter your character and fight your way through the brackets.</p>
      <div className="actions"><Link className="button primary" href="/account">Enter the tournament</Link><Link className="button secondary" href="/brackets">View brackets</Link></div>
      <div className="hero-mark">IT</div>
    </section>
    <section className="section"><TournamentCountdown /></section>
    <section className="section" id="how">
      <p className="eyebrow">HOW THE TOURNAMENT WORKS</p>
      <div className="grid four">
        <article className="panel"><b>01</b><h2>Register a character</h2><p>Writers submit original competitors to the shared pool.</p></article>
        <article className="panel"><b>02</b><h2>Write the battle</h2><p>Each writer writes a version of the matchup with their own character winning.</p></article>
        <article className="panel"><b>03</b><h2>Public vote</h2><p>Anyone can vote on which story is more compelling. The winner becomes canon.</p></article>
        <article className="panel"><b>04</b><h2>Survive twice</h2><p>Double elimination: one loss drops a character to the Elimination Bracket; a second loss removes them.</p></article>
      </div>
    </section>
    <footer>THE INFINITE TOURNAMENT · A COMMUNITY STORY COMPETITION</footer>
  </main>;
}
