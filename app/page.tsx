import Link from "next/link";

export default function Home() {
  return (
    <main className="site-shell">
      <nav className="topbar">
        <Link className="brand" href="/">INFINITE <span>TOURNAMENT</span></Link>
        <Link className="nav-link" href="/account">Writer sign in</Link>
      </nav>

      <section className="hero">
        <p className="eyebrow">THE ARENA IS OPEN</p>
        <h1>One arena.<br /><em>Infinite</em> possibilities.</h1>
        <p className="intro">
          Original characters. Writer-crafted battles. A public vote decides which story becomes canon.
          Enter your character and fight your way through the brackets.
        </p>
        <div className="actions">
          <Link className="button button-primary" href="/account">Enter the tournament</Link>
          <a className="button button-secondary" href="#how-it-works">How it works</a>
        </div>
        <div className="hero-mark" aria-hidden="true">IT</div>
      </section>

      <section className="rules" id="how-it-works">
        <p className="eyebrow">THE RULES OF THE ARENA</p>
        <div className="rule-grid">
          <article><b>01</b><h2>Submit a character</h2><p>Writers register original characters to compete in the shared tournament pool.</p></article>
          <article><b>02</b><h2>Write the battle</h2><p>Matched writers each write a version of the fight with their own character winning.</p></article>
          <article><b>03</b><h2>The public decides</h2><p>Everyone can vote. The winning story becomes the official canon result.</p></article>
          <article><b>04</b><h2>Survive the brackets</h2><p>A double-elimination format gives competitors a second chance before permanent elimination.</p></article>
        </div>
      </section>
      <footer>THE INFINITE TOURNAMENT <span>·</span> A COMMUNITY STORY COMPETITION</footer>
    </main>
  );
}
