"use client";
import {useEffect,useState} from "react";
import {supabase} from "@/lib/supabase";
import TournamentCountdown from "../tournament-countdown";

type Match = {id:string;round_id:string;round_number:number;bracket_stage:string;status:string;character_a_id:string;character_b_id:string;winner_character_id:string|null;a_name:string;b_name:string;winner_name:string|null};
function BracketStage({title,matches}:{title:string;matches:Match[]}) {
  const roundNumbers=[...new Set(matches.map(m=>m.round_number))].sort((a,b)=>a-b);
  if(!matches.length)return null;
  return <section className="section">
    <h2>{title}</h2>
    <div className="bracket-scroll"><div className="bracket-columns" style={{gridTemplateColumns:`repeat(${roundNumbers.length}, minmax(170px, 1fr))`}}>
      {roundNumbers.map((round)=> <div className="bracket-round" key={round}>
        <p className="bracket-round-title">Round {round}</p>
        {matches.filter(m=>m.round_number===round).map(m=><div className="bracket-pair" key={m.id}>
          <div className={m.winner_character_id===m.character_a_id?"bracket-name winner":"bracket-name"}>{m.a_name||"TBD"}</div>
          <div className="bracket-name bottom">{m.winner_character_id===m.character_b_id?<strong>{m.b_name||"TBD"}</strong>:(m.b_name||"TBD")}</div>
          {m.status!=="closed"&&<span className="bracket-live">{m.status}</span>}
        </div>)}
      </div>)}
    </div></div>
  </section>;
}
export default function Brackets(){
 const [matches,setMatches]=useState<Match[]>([]);const [msg,setMsg]=useState("Loading brackets…");const [finished,setFinished]=useState(false);
 useEffect(()=>{(async()=>{
  const {data:state,error:stateError}=await supabase.from("tournament_state").select("current_tournament_id").eq("singleton",true).single();
  if(stateError||!state){setMsg(stateError?.message||"Tournament state is unavailable. Apply the V8 migration first.");return;}
  const [{data:r,error:re},{data:m,error:me}]=await Promise.all([
   supabase.from("tournament_rounds").select("id,round_number,bracket_stage").eq("tournament_id",state.current_tournament_id).order("round_number"),
   supabase.from("matches").select("*").eq("tournament_id",state.current_tournament_id).order("created_at")
  ]);
  if(re||me){setMsg(re?.message||me?.message||"Could not load brackets");return;}
  if(!(r||[]).length||!(m||[]).length){setMsg("The tournament bracket hasn’t been generated yet.");return;}
  const ids=[...new Set((m||[]).flatMap(x=>[x.character_a_id,x.character_b_id,x.winner_character_id]).filter(Boolean))];
  const {data:c}=ids.length?await supabase.from("characters").select("id,name,losses,status").in("id",ids):{data:[] as any[]};
  const names=Object.fromEntries((c||[]).map(x=>[x.id,x.name]));
  const enriched=(m||[]).map(x=>({...x,round_number:(r||[]).find(y=>y.id===x.round_id)?.round_number||0,a_name:names[x.character_a_id],b_name:names[x.character_b_id],winner_name:names[x.winner_character_id]}));
  const finals=enriched.filter(x=>x.bracket_stage==="grand_final"&&x.status==="closed");
  const eliminatedFinalist=finals.some(f=>(c||[]).some(ch=>(ch.id===f.character_a_id||ch.id===f.character_b_id)&&(ch.status==="eliminated"||Number(ch.losses)>=2)));
  if(eliminatedFinalist){setFinished(true);setMsg("The Grand Final is complete. This bracket has been cleared. An administrator can generate the next tournament bracket when ready.");return;}
  setMatches(enriched);setMsg("");
 })();},[]);
 return <main className="shell page"><p className="eyebrow">DOUBLE ELIMINATION</p><h1>Tournament brackets</h1><p className="muted">Characters begin in the Winners Bracket. A first loss sends them to the Elimination Bracket; a second loss eliminates them. Earlier rounds remain visible until the Grand Final is decided.</p><TournamentCountdown/>{msg&&<p className="notice">{msg}</p>}{!finished&&matches.length>0&&<>
  <BracketStage title="Winners Bracket" matches={matches.filter(m=>m.bracket_stage==="winners")}/>
  <BracketStage title="Elimination Bracket" matches={matches.filter(m=>m.bracket_stage==="elimination")}/>
  <BracketStage title="Grand Final" matches={matches.filter(m=>m.bracket_stage==="grand_final")}/>
 </>}</main>;
}
