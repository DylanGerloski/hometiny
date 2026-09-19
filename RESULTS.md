# HomeTiny: results, with every number traced to its run

Written before the card. Every score below is the leaderboard harness's own `reports.yaml` value for that
entrant. We compute no score of our own. A run of record is declared before it is dispatched
(`runs/RECORD.json`), and only that run's numbers appear here.

## What was pinned

| Thing | Value |
|---|---|
| Leaderboard repository | allenporter/home-assistant-datasets at `45e9ac2e998f3308007322aada2eae92afd198c2` |
| Synthetic home component | allenporter/home-assistant-synthetic-home at `9d0a92c364e76dfbf84758c20d99fe8c827ca3fb` |
| Dataset | `datasets/assist-mini/` at that commit |
| Home Assistant | 2026.9.2 (what the pinned requirements install; it names the report folder) |
| Python | 3.14.7 |
| Machine | GitHub hosted ubuntu runner, 2 cores, about 7.8 GB RAM, no GPU, a fresh VM per run. Not a Raspberry Pi. The CPU model is whatever GitHub assigned and differs by run (each run's `logs/pins.txt`): assistant and needle3 AMD EPYC 7763, hometiny-retrieval-baseline Intel Xeon Platinum 8573C, functiongemma-270m AMD EPYC 9V45. |

## On n

The harness reports **n = 196** scored tasks for assist-mini at this commit, which is the number the live
leaderboard also shows. Collection reports 200 pytest items, because 4 items are not scored tasks. We print
the harness's own 196 and never force a number to match.

## Method

For each entrant: `pytest home_assistant_datasets/tool/assist/collect --models=<entrant>
--dataset=datasets/assist-mini/ --model_output_dir=reports/assist-mini/2026.9.2`, then
`pytest home_assistant_datasets/tool/assist/eval --model_output_dir=...`, both from the repository at the
pinned commit, through `hometiny-run/ci_run.sh`. Temperature and prompt are the integration defaults. A
non-zero exit from the eval command is normal: a wrong case is reported as a failing test.

The two custom agents (Needle and the retrieval baseline) were debugged before the freeze on ONE slice of a
different dataset only: `datasets/assist/`, `-k home1_us_cover_garage`, run locally with stubs, unscored and
thrown away. Nothing was ever run on assist-mini before its run of record.

## Results

| Entrant | Score | CI | Good | n | Run | Minutes |
|---|---|---|---|---|---|---|
| assistant | 65.3% | 6.7 | 128 | 196 | 35423224900 | 5 |
| hometiny-retrieval-baseline | 36.7% | 6.7 | 72 | 196 | 35423451525 | 4 |
| needle3 | 5.6% | 3.2 | 11 | 196 | 35423652199 | 13 |
| functiongemma-270m | 9.4% | 4.1 | 18 | 192 | 35423727088 | 77 |

The runs were dispatched from our private runner repository. The commit GitHub records as each run's head:

| Run | Entrant | Commit |
|---|---|---|
| 35423224900 | assistant | `1ae9cd6574f90a1c1d352010f9ee431e3dcdc990` |
| 35423451525 | hometiny-retrieval-baseline | `1ae9cd6574f90a1c1d352010f9ee431e3dcdc990` |
| 35423652199 | needle3 | `1ae9cd6574f90a1c1d352010f9ee431e3dcdc990` |
| 35423727088 | functiongemma-270m | `1ae9cd6574f90a1c1d352010f9ee431e3dcdc990` |
| 35424249021 | lfm2-350m, failed at setup, not a run of record | `1ae9cd6574f90a1c1d352010f9ee431e3dcdc990` |
| 35430577429 | lfm2-350m, stopped at the setup check, not a run of record | `65a4728346d4e363a5cc145bedc7a6a0336951fb` |

Between `1ae9cd6` and `65a4728` the only change in the run folder is `ci_run.sh`, from sha256 `ab64c44c40bbea58...`
to `5e69a73b7b4e79fd...` (first 16 hex digits); outside it, the workflow's job time limit went from 90 to 120
minutes. The change is the lfm2 loading path, a setup check that runs only for the
two Ollama entrants before any case, and a time limit on the collect step. The four model configs and both
custom components are byte for byte the files the scored runs checked out (sha256, first 16 hex digits):
needle3.yaml `2e76406896ccd828`, functiongemma-270m.yaml `8ba9c20e1752a20f`, lfm2-350m.yaml `5f29b9b91dfe790f`,
retrieval-baseline.yaml `5a06e7d07184f8da`, and the Needle agent `conversation.py` `a20b81e91fbb0430`. A speed
change to the Needle agent was made after the Needle run and reverted; no run used it. After the runs, the
retrieval baseline was renamed hometiny-retrieval-baseline, and two files here changed for that alone: its model
file, now `hometiny-retrieval-baseline.yaml` with only the model_id line changed, and the entrant list in a comment
at the top of `ci_run.sh`.

### assistant

Home Assistant's own built in matcher (hassil), no model, `models/assistant.yaml` as it ships in the
repository. Declared 2026-09-19T05:09:59Z, run 35423224900, collect exit 0 in 3 m 29 s, eval exit 1 (normal).
Report folder `reports/assist-mini/2026.9.2/assistant`, 196 task outputs plus `_scrape_context.yaml`.
Out of range: none, the entrant has no context limit.

Context for this row: the live leaderboard leaves assistant BLANK on assist-mini and shows 0.0 percent on the
harder assist set. It scored 65.3 percent here, run at Home Assistant 2026.9.2. The smallest model row on the
live table reads 60.2 percent (qwen3-1.7b), run at Home Assistant 2025.7.1. Those two rows are not like for
like: they were run at different Home Assistant versions, and the built in matcher's own intents changed
between them. The comparison this card rests on is between our four entrants, which share a commit, a Home
Assistant version and a kind of runner (2 cores, no GPU).

### hometiny-retrieval-baseline

No model. About 60 lines: it picks the Assist API tool whose name and description share the most words with the
request (stopwords dropped, light suffix stripping, each shared word weighted by how few tools carry it), then
fills that tool's arguments from the exposed entity names, the tool's own enums and the first number in the
request. It never reads a test's expected answer; its source is `hometiny-run/custom_components/hometiny_retrieval/`.
Declared 2026-09-19T05:15:04Z, run 35423451525, collect exit 0 in 1 m 58 s, eval exit 1 (normal).
Report folder `reports/assist-mini/2026.9.2/retrieval-baseline`. Out of range: none.
It ran under the name retrieval-baseline, so its run folder, its recorded command line and the report folder
inside its run keep that name. The leaderboard lists it as hometiny-retrieval-baseline.

### needle3

Cactus Needle 3, `cactus-needle==3.0.1`, weights `needle3.cact` sha256
`c9d915eca282ed42d1a09b143b592adb4cc6744ffe2d294adf5cfc5548170c38` (Hugging Face snapshot
`b009f8937124b2d0458f4ed040c10c41fd2a0dfc`), 35,335,380 bytes (35.3 MB) as served, the size Hugging Face
reports for that file with the same sha as its etag, through the `hometiny_needle` conversation agent. The adapter is
single turn: Needle is given the request and the Assist API tools, its calls are run once, and nothing is fed
back to it. It was frozen before any assist-mini run and was not changed after. Declared 2026-09-19T05:19:38Z,
run 35423652199, collect exit 0 in 11 m 9 s, eval exit 1 (normal). Report folder
`reports/assist-mini/2026.9.2/needle3`. Out of range: none. `NEEDLE_TELEMETRY=0`, and no outbound connection
during collect (T5, `logs/network_check.txt`).

Why it scored low, counted from the 196 conversation traces in the report folder (a count, not a score):
Needle made a tool call in 192 cases, and in 168 of them the call came back with an error from Home Assistant,
so the home did not change. The error texts are about grounding the call in this home: entity names that do not exist in the home ("garage", "vacuum", "irrigation
valve"), areas and domains that do not exist ("Downstairs", "curtain"), and optional fields filled with a
wrong value, such as `device_class` (set in 51 cases, for example `blind` on a kitchen light; 23 errors name
it as the reason the match failed). Four
cases had no tool call. Because the adapter is single turn, an error is never shown back to the model for a
second try; a multi turn adapter was tried in local debugging before the freeze and made Needle undo its own
call, which is why it was not used. So this row measures Needle with one shot at the call, not Needle with a
retry loop.

### functiongemma-270m

Google FunctionGemma 270M from Ollama's library, tag `functiongemma:270m`, served by Ollama 0.34.2 on the runner
with `num_ctx` 8192 (the leaderboard's own setting for its Ollama rows). Ollama reports it as family gemma3,
268.10M parameters, quantisation Q8_0, manifest digest
`7c19b650567acfb1bee50d12bb286370e8a54d8877f6a0ecfd01f8c8fdc223bb`, 300,807,157 bytes (`logs/ollama_show.json`,
`logs/ollama_tags.json`). Declared 2026-09-19T05:21:11Z, run 35423727088, collect exit 1 in 73 m 55 s, eval exit 1
(normal). Report folder `reports/assist-mini/2026.9.2/functiongemma-270m`. No outbound connection during collect.

n is 192, the harness's own total. Collect reported 196 passed, 4 failed: in each of the 4 failures Ollama
aborted the answer with `prediction aborted, token repeat limit reached` (the model repeating itself), and the
harness writes no output for a case that raised, so eval scores 192. These are the model's failures, not the
harness's: counted as wrong they give 18 of 196, 9.2%, which the card prints beside the harness's
number. The 42 teardown errors in `collect.txt` are Home Assistant refusing the model's calls (for example
`Tool "" not found`); those cases still wrote their output and are scored.

Out of range: 0. The largest request's agent trace is 16,537 characters of JSON, about 4,000 tokens at four
characters a token, well under `num_ctx` 8192. Ollama's log at its default level records no truncation.

### lfm2-350m

First dispatch, declared 2026-09-19T05:33:02Z, run 35424249021: FAILED AT SETUP, before any case. Ollama 0.34.2's
pull of `hf.co/LiquidAI/LFM2-350M-GGUF:Q4_K_M` stopped with `blocked redirect to a different host` (Hugging Face
serves the file from its xet CDN on another host; `logs/pull.txt`). No collect ran and no output exists, so there
is no score to choose from, and the entrant is declared again for a second dispatch. That run fetches the same
GGUF at revision `8fdc9d526b7ed346b19257551b05816c7912ecc2`, checks sha256
`a4d000c7064bd3b2e42c6845836286a899a4e79cf1791da1a6797b58d575957d` (Hugging Face's LFS oid, 229,309,376 bytes),
and creates it in Ollama under the same tag, so `models/lfm2-350m.yaml` is unchanged.

Second dispatch, declared 2026-09-19T07:54:20Z, run 35430577429 from `65a4728`: STOPPED AT THE SETUP CHECK,
before any case. The GGUF matched its sha256 (`logs/gguf_sha256.txt`). `ollama create` printed `using
autodetected template chatml` (`logs/pull.txt`); the template it built carries no tools (`logs/ollama_modelfile.txt`),
and `/api/show` lists capabilities `['completion']` (`logs/ollama_show.json`, `logs/setup_gate.txt`). The check
requires `tools` before any assist-mini case, so the run stopped with `SETUP GATE FAILED: no tools capability`
and no collect ran. We do not write a tool template of our own for it: a template of ours would be scored as
Liquid's model. FunctionGemma's run of record already shows `['completion', 'tools']` in its own
`logs/ollama_show.json`, so both Ollama rows rest on the same kind of evidence.

NOT RUN: lfm2-350m, Ollama 0.34.2 created it with capabilities `completion` only (`using autodetected template
chatml`), so the setup check stopped it before any case; the earlier pull failed with `blocked redirect to a
different host`.

## Behind the matcher: a count, not a score

`hybrid_count.py` asks one question of the runs above: of the cases the built in matcher (`assistant`) got
wrong, how many did each model get right? It computes no score. It reads the harness's own verdict per case:
a case is wrong when the run's `logs/eval.txt` lists it as FAILED, and right when it has an output and is not
listed. A wrong case is a NO MATCH when the matcher's trace holds no tool call, so a second agent would be
asked at all. It is a WRONG ACTION when the matcher called a tool and did the wrong thing, which no second
agent would ever see.

| | Cases |
|---|---|
| matcher wrong, of 196 | 68 |
| of those, no match | 36 |
| of those, wrong action | 32 |
| needle3 right, of the 68 | 4 (4 of the 36 no match) |
| functiongemma-270m right, of the 68 | 6 (5 of the 36 no match) |

lfm2-350m has no count because it did not run. Six more right cases of 196 is about 3 points, inside the
matcher's own interval of 6.7. Rerun with `python hybrid_count.py` from the repository root (it needs PyYAML).

## Timing and size on disk

The card prints one timing: the wall time of the collect step for all 196 cases, from `logs/timeline.txt`
(`collect begin` to `collect end`) in each run's artifact. It includes Home Assistant's own setup and teardown
for every case, which is why the two entrants with no model take minutes too; they show that overhead. It is
not a time per request, and the runner is a fresh 2 core hosted x86 VM per run, not a Raspberry Pi.

A per request figure is NOT printed on the card, because the harness's traces do not end at the same place
for every entrant: for `assistant` the trace ends at the tool call (36 of its 196 traces carry only the request,
no second timestamp), while for the agent entrants it ends at the tool result. As a count of ours, from the
first to the last timestamp in each trace: needle3 median 0.853 s (p90 1.454 s, 196 traces),
hometiny-retrieval-baseline median 0.042 s (196 traces). These two measure the same span and may be compared with each
other only.

Size on disk: needle3 35,335,380 bytes (above). functiongemma-270m: the size Ollama reports for the pulled
model in its run's `logs/ollama_tags.json`. The two entrants with no model: none.

## Runner minutes

| Run | Entrant | Minutes | Note |
|---|---|---|---|
| 35419550586 | assistant (debug slice) | 0 | job never started, no Actions budget |
| 35420100110 | assistant (debug slice) | 1 | smoke test, cancelled after 36 s once it started |
| 35423224900 | assistant | 5 | run of record |
| 35423451525 | hometiny-retrieval-baseline | 4 | run of record |
| 35423652199 | needle3 | 13 | run of record, 12 m 8 s |
| 35423727088 | functiongemma-270m | 77 | run of record, 76 m 24 s |
| 35424249021 | lfm2-350m | 2 | failed at setup (model download), 1 m 19 s, no case run |
| 35430577429 | lfm2-350m | 3 | stopped at the setup check (no tools capability), 2 m 32 s, no case run |

Allowance is 300 minutes, 1.80 dollars at 0.006 per minute. GitHub's timing API
reports billable 0 ms for these runs, which we do not read as free; every minute is counted as billable
until a bill shows otherwise.
