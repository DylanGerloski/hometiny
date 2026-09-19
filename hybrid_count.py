"""Would a small model help placed BEHIND the built in matcher? A count of ours, not a score.

From the harness's own per case verdicts (each run's eval log: a case is wrong when it is listed FAILED), for the
cases the built in matcher `assistant` got wrong: how many each model entrant got right, and how many of the
matcher's misses were a NO MATCH (its trace has no tool call, so a fallback agent would be asked at all)
against a WRONG ACTION (it matched and did the wrong thing, where a fallback never fires).

Needs PyYAML (the harness's own requirements install it). lfm2-350m did not run, so it has no count.

  python hybrid_count.py
"""
import glob
import json
import pathlib
import re

import yaml

HERE = pathlib.Path(__file__).parent
MODELS = ["needle3", "functiongemma-270m", "lfm2-350m"]


def run(entrant: str) -> pathlib.Path | None:
    found = sorted(glob.glob(str(HERE / "runs" / entrant / "*" / "logs" / "eval.txt")))
    return pathlib.Path(found[-1]).parent.parent if found else None


def cases(entrant: str) -> tuple[set[str], set[str]] | None:
    r = run(entrant)
    if r is None:
        return None
    folder = next((r / "report").glob(f"*/{entrant}"))
    every = {p.stem for p in folder.glob("*.yaml") if p.name != "_scrape_context.yaml"}
    text = (r / "logs" / "eval.txt").read_text(encoding="utf-8", errors="replace")
    failed = set(re.findall(rf"test_expected_states\[{re.escape(entrant)}/(.+?)\.yaml\]", text))
    return every, failed


def no_match(entrant: str, case: str) -> bool:
    r = run(entrant)
    f = next((r / "report").glob(f"*/{entrant}/{case}.yaml"))
    trace = (yaml.safe_load(f.read_text(encoding="utf-8")).get("context") or {}).get("conversation_trace") or []
    return not any(ev.get("event_type") == "tool_call" for ev in trace)


def main() -> None:
    every, failed = cases("assistant")
    misses = sorted(failed)
    nm = [c for c in misses if no_match("assistant", c)]
    out = {"assistant_cases": len(every), "assistant_wrong": len(misses), "wrong_no_match": len(nm),
           "wrong_action": len(misses) - len(nm), "models": {}}
    for m in MODELS:
        got = cases(m)
        if got is None:
            out["models"][m] = "did not run"
            continue
        m_every, m_failed = got
        right = {c for c in m_every if c not in m_failed}
        out["models"][m] = {
            "right_of_matcher_wrong": len(right & set(misses)),
            "right_of_matcher_no_match": len(right & set(nm)),
        }
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
