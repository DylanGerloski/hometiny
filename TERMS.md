# TERMS: what was read, where, and what it permits

Read at source on 2026-09-19, twice, by two separate readers: once for the licences, and once more against the
sources the runs actually pulled.

## Finding
Publishing measured scores for every entrant is permitted. No licence or terms document below carries a clause on
benchmarks, evaluation results or comparisons.

| Entrant | Source actually used by the run | Licence | Publication clause | Read status |
|---|---|---|---|---|
| Needle 3 | PyPI `cactus-needle==3.0.1`, which fetches the published `needle3.cact` from https://huggingface.co/Cactus-Compute/needle3 | Apache-2.0 (weights and code), https://github.com/cactus-compute/needle/blob/main/LICENSE | silent | read whole |
| FunctionGemma 270M | Ollama library `functiongemma:270m`, https://ollama.com/library/functiongemma (anonymous registry manifest answered 200: no account used) | Gemma Terms of Use, last modified 2026-04-01, https://ai.google.dev/gemma/terms | silent; "publication" appears once, inside the definition of distributing the model | fetched whole, keyword scan |
| LFM2-350M | Hugging Face `LiquidAI/LFM2-350M-GGUF`, commit 8fdc9d526b7ed346b19257551b05816c7912ecc2, file `LFM2-350M-Q4_K_M.gguf` (not gated), fetched at that commit and created in Ollama with `ollama create`. Ollama's own library has no 350M tag. It did not run (the card's Limits), so no LFM2 score is published. | LFM Open License v1.0, https://huggingface.co/LiquidAI/LFM2-350M-GGUF/blob/main/LICENSE | silent | fetched whole; the GGUF repo's LICENSE is byte-identical to the base model repo's (10,596 bytes, same sha256) |
| assistant | built into Home Assistant (hassil), `models/assistant.yaml` in the leaderboard repo | Apache-2.0 (Home Assistant) | n/a | n/a |
| hometiny-retrieval-baseline | our own code, source in the pull request | same licence as the leaderboard repo's code | n/a | n/a |

## Conditions this build and the card obey
1. **No implied endorsement** (Gemma terms 4.2; LFM licence section 7). Models are named in plain text, no vendor logo,
   and the card's limits say no vendor took part in or reviewed the run.
2. **No weights are redistributed**, so the Gemma Notice file is not owed (terms 3.1). The runner pulls weights; the pull
   request carries configs, code and results only.
3. **Needle telemetry off**: `NEEDLE_TELEMETRY=0` and `DO_NOT_TRACK=1`, both, as the Needle README names them.
4. **Needle citation** (a request in its README, not a term) is included on the card.
5. **The dataset stays in the fork.** The leaderboard repository has no LICENSE file at its root (pyproject declares
   Apache-2.0 for the package). The card quotes at most five test utterances and copies no dataset file.

## The leaderboard's contribution rule
docs/eval.md, verbatim: "You can commit these and send a PR to update the official leaderboard." No CONTRIBUTING file.
Pinned commit: 45e9ac2e998f3308007322aada2eae92afd198c2.
