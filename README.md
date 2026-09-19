# HomeTiny

The missing no-GPU tier of the Home LLM Leaderboard. We ran the tool calling models under 400M
parameters through Home Assistant's own assist-mini test set, using the
leaderboard's own harness and scoring, and set them beside two baselines that use no model at all.

The result card is [CARD.md](CARD.md). Every number on it is traced to a run log in
[RESULTS.md](RESULTS.md). What we read before naming a vendor is in [TERMS.md](TERMS.md).

## The entrants

| Entrant | What it is |
|---|---|
| needle3 | Cactus Compute Needle 3, the published 2 bit archive, through cactus-needle 3.0.1 |
| functiongemma-270m | Google FunctionGemma 270M, from Ollama's library |
| lfm2-350m | Liquid AI LFM2-350M, Q4_K_M GGUF, served by Ollama. Did not run: see the card's Limits |
| assistant | Home Assistant's own built in matcher, no model at all |
| retrieval-baseline | about 60 lines of word matching over the same tools, no model at all |

## How to rerun it

On an x86 Linux machine with git, curl and Python 3 (the runs used GitHub's hosted Ubuntu runner):

```sh
git clone https://github.com/DylanGerloski/hometiny
cd hometiny
bash hometiny-run/ci_run.sh <entrant> assist-mini
```

`<entrant>` is one of `assistant`, `retrieval-baseline`, `needle3`, `functiongemma-270m`. (`lfm2-350m` stops
at the script's setup check, as the card explains.) The
script clones the leaderboard repository and Home Assistant's synthetic home at their pinned commits into
`/tmp/hometiny`, installs the leaderboard's own requirements with uv (Python 3.14, which uv fetches if it is
missing), fetches the model, and runs the repository's own collect and eval commands. It scores nothing
itself. The two Ollama entrants install Ollama with its official script, which needs sudo. The report and
logs land in `/tmp/hometiny/out`, in the same layout as each run's folder under `runs/`.

`python hybrid_count.py` reruns the count in RESULTS.md of what each model gets right behind the built in matcher.

## Limits

The runs are on GitHub hosted x86 Linux runners, 2 cores, no GPU, a fresh one per run, so they say
nothing about speed on a real Raspberry Pi. Scores come from the leaderboard's harness, not from us. No
vendor took part in the runs or reviewed them.

## License

MIT
