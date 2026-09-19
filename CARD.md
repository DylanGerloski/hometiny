# Can a 35 MB model run your house?

The Home LLM Leaderboard is empty below about 8 GB of VRAM. The smallest row on it is a 1.7B model. So
when a 35 MB tool calling model shipped that its makers say runs on a phone's CPU, nobody could say what it
does with the voice commands Home Assistant actually gets, and the thread asking about it had no numbers to
point at.

We ran the small models through the leaderboard's own assist-mini test set, with the leaderboard's own
harness and scoring, and put two things that use no model at all beside them.

## Results

Short answer: not Needle 3, not on this test. It scored 5.6%, under Home Assistant's own built in matcher
and under 60 lines of word matching. In 168 of 196 requests it made a call that Home Assistant refused,
because it named a device, a room or a device type that is not in the house. FunctionGemma 270M, more
than eight times its size on disk, scored 9.4%, and the two intervals overlap.

| Entrant | What it is | Size on disk | Score | CI | Good of n | Time for all 196 | Runner CPU |
|---|---|---|---|---|---|---|---|
| assistant | Home Assistant's built in matcher, no model | none | 65.3% | 6.7 | 128 of 196 | 3 m 29 s | AMD EPYC 7763 |
| hometiny-retrieval-baseline | about 60 lines of word matching, no model | none | 36.7% | 6.7 | 72 of 196 | 1 m 58 s | Intel Xeon Platinum 8573C |
| functiongemma-270m | FunctionGemma 270M through Ollama | 300.8 MB | 9.4% | 4.1 | 18 of 192 | 73 m 55 s | AMD EPYC 9V45 |
| needle3 | Cactus Needle 3, 2 bit archive | 35.3 MB | 5.6% | 3.2 | 11 of 196 | 11 m 9 s | AMD EPYC 7763 |

Time for all 196 is the wall time of the harness's whole collect step on a 2 core hosted runner, including
Home Assistant's own setup for every case, so the two rows with no model show that overhead. It is not a
time per request. GitHub gave the runs three different CPU models, named in the last column, so read the
times as rough sizes, not as a race.

Every run and its log is listed in RESULTS.md.

## How to read this

Every score is the harness's own number for that entrant. We wrote no scorer. All four entrants ran at the
same commit, on the same Home Assistant version, on the same kind of hosted runner (2 cores, no GPU),
so their scores can be compared with each other. Rows on the public leaderboard were run at other Home Assistant versions and are not like for like.

The two entrants with no model are the interesting part of the table. One is Home Assistant's own built in
matcher, which every user already has. The other is about 60 lines of word matching we wrote, which picks
the tool whose description shares the most words with the request and fills its arguments from the names of
the devices in the house. If a model cannot clear those, its size is not the thing holding it back.

Could a small model still help if it only took the requests the matcher gets wrong? We counted, from the
harness's own verdict on each case. This is a count of ours, not a score. The built in matcher got 68 of
the 196 wrong. Needle 3 got 4 of those 68 right, and FunctionGemma 270M got 6. So placed behind the matcher,
neither would lift it by more than the matcher's own interval of 6.7 points. RESULTS.md has the full count.

## Method

Harness: allenporter/home-assistant-datasets at commit 45e9ac2, dataset `datasets/assist-mini`, 196 tasks,
Home Assistant 2026.9.2, Python 3.14.7. Each entrant is a Home Assistant conversation agent with one config
file, which is the only thing this harness scores. Temperature and prompt are the integration defaults.
Each entrant ran once, and that run was declared before it was dispatched, so no score here is the better
of two tries. The scripts and configs to rerun it are in the repository.

Needle 3 gets one turn per request: it writes no prose, so there is no answer to wait for after a tool
runs. We tried feeding Home Assistant's tool result back to it, as its documentation suggests, and it read
the result as a new request and undid its own action. Every call it makes in its one turn is executed.

## Limits

- n = 196 tasks (192 scored for functiongemma-270m, below), and each score carries the confidence interval the leaderboard prints. At this n a few points
  either way is noise.
- The machines are GitHub hosted x86 runners, 2 cores, no GPU, a fresh one per run. They are not a Raspberry Pi,
  and nothing here measures speed on one. GitHub gave the runs three different CPU models (the last column), so
  a timing on one CPU for every entrant was not possible here. The only timing printed is the whole collect step's wall time, overhead included.
- Quantisation, as each run reports it: Needle 3 runs the published 2 bit archive, FunctionGemma 270M is
  Q8_0, as Ollama reports it in the run log.
- LFM2-350M is not in the table because it did not run. Ollama 0.34.2 refused to pull it from Hugging Face
  ("blocked redirect to a different host"). We then loaded Liquid's own GGUF at a pinned revision, checked
  against its published sha256, with `ollama create`. Ollama gave it a plain chat template ("using
  autodetected template chatml") and listed its capabilities as `completion` only, with no tool support. This
  test needs tool calls, so the run stopped before its first task. We did not write a template for it
  ourselves, because a template of ours would then be scored as Liquid's model.
- Temperature is each integration's default, not tuned by us.
- In 4 of its 196 requests FunctionGemma repeated itself until Ollama stopped it ("token repeat limit
  reached"). The harness writes no output for such a case, so its n is 192. Counted as wrong, the score
  would be 18 of 196, 9.2%.
- Out of range cases are counted separately and never scored as zero. Count per entrant: assistant 0,
  hometiny-retrieval-baseline 0, needle3 0, functiongemma-270m 0.
- Rows on the live leaderboard were run at different Home Assistant versions than ours, so they are not
  like for like. The nearest prior for a very small model is llama3.2-1b at 4.1 percent, 2 of 49, in the
  repository's archive on a 2024 version of assist-mini.
- No vendor took part in this run or reviewed it.

Needle is built by the Cactus Compute team: Ndubuaku, Mosoyan, Mroz, Cylich, Kumar, Sandhu, Shemet and Lee,
2026, https://github.com/cactus-compute/needle
