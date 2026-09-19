#!/usr/bin/env bash
# HomeTiny: one entrant through the Home LLM Leaderboard's OWN collect and eval, on a CPU-only runner.
# Usage: ci_run.sh <entrant> <dataset> [pytest -k filter]
#   entrant: needle3 | functiongemma-270m | lfm2-350m | assistant | retrieval-baseline
#   dataset: assist-mini (run of record) | assist (adapter debugging only, with a -k filter)
# Nothing here pushes, forks, opens a pull request or posts: the only network use is cloning two public
# repositories at pinned commits, installing packages, and downloading open weights.
set -euo pipefail

ENTRANT="$1"
DATASET="$2"
KFILTER="${3:-}"
LEADERBOARD_SHA=45e9ac2e998f3308007322aada2eae92afd198c2
SYNTHETIC_HOME_SHA=9d0a92c364e76dfbf84758c20d99fe8c827ca3fb
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${RUNNER_TEMP:-/tmp}/hometiny"
OUT="$WORK/out"
LOGS="$OUT/logs"
mkdir -p "$WORK" "$LOGS"
export NEEDLE_TELEMETRY=0 DO_NOT_TRACK=1

stamp() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" | tee -a "$LOGS/timeline.txt"; }

clone_at() {  # <url> <dir> <sha>
  git init -q "$2"
  git -C "$2" remote add origin "$1"
  git -C "$2" remote set-url --push origin DISABLED
  git -C "$2" fetch -q --depth 1 origin "$3"
  git -C "$2" checkout -q FETCH_HEAD
}

stamp "start entrant=$ENTRANT dataset=$DATASET k=${KFILTER:-none}"
clone_at https://github.com/allenporter/home-assistant-datasets "$WORK/home-assistant-datasets" "$LEADERBOARD_SHA"
clone_at https://github.com/allenporter/home-assistant-synthetic-home "$WORK/home-assistant-synthetic-home" "$SYNTHETIC_HOME_SHA"
cd "$WORK/home-assistant-datasets"

# The docs' own layout: every custom component linked into one custom_components directory on PYTHONPATH.
mkdir -p custom_components
# A regular package, or the test plugin's own testing_config/custom_components (which has an __init__) wins the import.
touch custom_components/__init__.py
ln -sfn "$WORK/home-assistant-synthetic-home/custom_components/synthetic_home" custom_components/synthetic_home
ln -sfn "$HERE/custom_components/hometiny_needle" custom_components/hometiny_needle
ln -sfn "$HERE/custom_components/hometiny_retrieval" custom_components/hometiny_retrieval
cp "$HERE"/models/*.yaml models/
# OLLAMA_URL set: the models are served by an Ollama outside this machine (the emulated guest reaches the
# host's native Ollama); unset: this script installs and serves Ollama here, as on the hosted runner.
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
printf 'ollama_url: %s\n' "$OLLAMA" > secrets.yaml
export PYTHONPATH="$PWD"

stamp "install harness"
# uv: already present, else pip (the hosted runner's setup-python), else uv's own installer (a stock Ubuntu,
# where only python3 exists and pip refuses system installs).
export PATH="$HOME/.local/bin:$PATH"
command -v uv > /dev/null || python -m pip install -q uv 2> /dev/null \
  || { curl -LsSf https://astral.sh/uv/install.sh | sh > "$LOGS/uv_install.txt" 2>&1; }
uv venv -q --python 3.14 .venv
uv pip install -q --python .venv/bin/python -r requirements_dev.txt -r requirements_eval.txt --prerelease=allow
PY=.venv/bin/python
HA_VERSION="$(uv pip freeze --python "$PY" | sed -n 's/^homeassistant==//p')"
REPORT_DIR="reports/$DATASET/$HA_VERSION"
{
  echo "leaderboard_commit: $LEADERBOARD_SHA"
  echo "synthetic_home_commit: $SYNTHETIC_HOME_SHA"
  echo "homeassistant: $HA_VERSION"
  echo "python: $($PY --version 2>&1)"
  echo "runner_cpu: $(nproc) x $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
  echo "runner_mem_kb: $(grep MemTotal /proc/meminfo | awk '{print $2}')"
  echo "gpu: none"
} > "$LOGS/pins.txt"

case "$ENTRANT" in
  functiongemma-270m|lfm2-350m)
    TAG="$(sed -n 's/^  model: //p' "models/$ENTRANT.yaml")"
    if [ -z "${OLLAMA_URL:-}" ]; then
      stamp "install ollama"
      curl -fsSL https://ollama.com/install.sh | sh > "$LOGS/ollama_install.txt" 2>&1
      (ollama serve > "$LOGS/ollama_serve.txt" 2>&1 &)
      for _ in $(seq 30); do curl -sf "$OLLAMA/api/version" > /dev/null && break; sleep 1; done
      if [ "$ENTRANT" = lfm2-350m ]; then
        # Ollama 0.34.2's pull of hf.co/ tags refuses Hugging Face's redirect to its xet CDN ('blocked redirect
        # to a different host', run 35424249021). So fetch the same GGUF at a pinned revision, check its sha256
        # against Hugging Face's own LFS oid, and create it under the SAME tag, so models/lfm2-350m.yaml is unchanged.
        GGUF_URL=https://huggingface.co/LiquidAI/LFM2-350M-GGUF/resolve/8fdc9d526b7ed346b19257551b05816c7912ecc2/LFM2-350M-Q4_K_M.gguf
        GGUF_SHA=a4d000c7064bd3b2e42c6845836286a899a4e79cf1791da1a6797b58d575957d
        stamp "fetch gguf for $TAG"
        curl -fsSL -o "$WORK/lfm2.gguf" "$GGUF_URL"
        echo "$GGUF_SHA  $WORK/lfm2.gguf" | sha256sum -c - > "$LOGS/gguf_sha256.txt"
        echo "FROM $WORK/lfm2.gguf" > "$WORK/Modelfile"
        ollama create "$TAG" -f "$WORK/Modelfile" > "$LOGS/pull.txt" 2>&1
        ollama show --modelfile "$TAG" > "$LOGS/ollama_modelfile.txt" 2>&1
      else
        stamp "pull $TAG"
        ollama pull "$TAG" > "$LOGS/pull.txt" 2>&1
      fi
    fi
    echo "ollama: $(curl -s "$OLLAMA/api/version")" >> "$LOGS/pins.txt"
    echo "ollama_served_from: $OLLAMA" >> "$LOGS/pins.txt"
    curl -s "$OLLAMA/api/tags" > "$LOGS/ollama_tags.json"
    curl -s "$OLLAMA/api/show" -d "{\"model\":\"$TAG\"}" > "$LOGS/ollama_show.json"
    # Setup gate, before any assist-mini case: the served model must declare tool support and
    # answer one toy tool request (not from the dataset) with a tool call. A failure here is a failed setup, no
    # try spent, never a score.
    "$PY" -c "import json,sys; c=json.load(open(sys.argv[1])).get('capabilities') or []; print('capabilities:', c); sys.exit(0 if 'tools' in c else 1)" "$LOGS/ollama_show.json" > "$LOGS/setup_gate.txt" 2>&1 \
      || { stamp "SETUP GATE FAILED: no tools capability"; exit 3; }
    curl -s "$OLLAMA/api/chat" -d "{\"model\":\"$TAG\",\"stream\":false,\"messages\":[{\"role\":\"user\",\"content\":\"What time is it right now?\"}],\"tools\":[{\"type\":\"function\",\"function\":{\"name\":\"get_time\",\"description\":\"Get the current time\",\"parameters\":{\"type\":\"object\",\"properties\":{}}}}]}" > "$LOGS/setup_toy_call.json"
    "$PY" -c "import json,sys; m=json.load(open(sys.argv[1])).get('message') or {}; t=m.get('tool_calls'); print('toy tool_calls:', t); sys.exit(0 if t else 1)" "$LOGS/setup_toy_call.json" >> "$LOGS/setup_gate.txt" 2>&1 \
      || { stamp "SETUP GATE FAILED: toy request answered without a tool call"; exit 3; }
    stamp "setup gate passed"
    ;;
  needle3)
    stamp "install needle"
    uv pip install -q --python "$PY" cactus-needle==3.0.1
    "$PY" -c "import needle; a = needle.Needle(tools=[{'name': 'noop', 'description': 'warm the cache', 'parameters': {'type': 'object', 'properties': {}}}]); print(a.complete('warm up'))" > "$LOGS/needle_warm.txt" 2>&1
    echo "cactus_needle: $(uv pip freeze --python "$PY" | sed -n 's/^cactus-needle==//p')" >> "$LOGS/pins.txt"
    find ~/.cache -name '*.cact' -exec sha256sum {} \; >> "$LOGS/pins.txt" 2>/dev/null || true
    ;;
esac
uv pip freeze --python "$PY" > "$LOGS/pip_freeze.txt"

# T5: every connect() the collect run makes to a non-loopback address is logged; the models are local, so this should be empty.
sudo apt-get install -y -qq strace > /dev/null 2>&1 || true
PYTEST_ARGS=(home_assistant_datasets/tool/assist/collect "--models=$ENTRANT" "--dataset=datasets/$DATASET/" "--model_output_dir=$REPORT_DIR" -p no:cacheprovider -q)
[ -n "$KFILTER" ] && PYTEST_ARGS+=(-k "$KFILTER")
# The job is killed at its timeout-minutes; collect is stopped first (SIGINT, so pytest ends cleanly) so that eval
# and the copy below still run on the cases already written. A stopped collect exits 124 and is never a run of record.
COLLECT_MINUTES="${COLLECT_MINUTES:-105}"
save_report() { mkdir -p "$OUT/report"; cp -r "$REPORT_DIR" "$OUT/report/" 2>/dev/null || true; }
trap save_report EXIT
stamp "collect begin limit=${COLLECT_MINUTES}m"
set +e
if command -v strace > /dev/null; then
  timeout --signal=INT --kill-after=60 "${COLLECT_MINUTES}m" strace -f -qq -e trace=connect -o "$LOGS/connect_trace.txt" "$PY" -m pytest "${PYTEST_ARGS[@]}" > "$LOGS/collect.txt" 2>&1
else
  timeout --signal=INT --kill-after=60 "${COLLECT_MINUTES}m" "$PY" -m pytest "${PYTEST_ARGS[@]}" > "$LOGS/collect.txt" 2>&1
fi
COLLECT_EXIT=$?
set -e
stamp "collect end exit=$COLLECT_EXIT"
{
  echo "NEEDLE_TELEMETRY=$NEEDLE_TELEMETRY"
  echo "DO_NOT_TRACK=$DO_NOT_TRACK"
  echo "entrant=$ENTRANT"
  if [ -f "$LOGS/connect_trace.txt" ]; then
    echo "outbound connects during collect (non-loopback AF_INET/AF_INET6):"
    grep -E 'AF_INET6?' "$LOGS/connect_trace.txt" | grep -v -E '127\.0\.0\.1|inet_pton\(AF_INET6, "::1"|::ffff:127' || echo "none"
  else
    echo "strace unavailable: outbound connects NOT checked"
  fi
} > "$LOGS/network_check.txt"

stamp "eval begin"
set +e
"$PY" -m pytest home_assistant_datasets/tool/assist/eval "--model_output_dir=$REPORT_DIR" -p no:cacheprovider -q > "$LOGS/eval.txt" 2>&1
EVAL_EXIT=$?
set -e
stamp "eval end exit=$EVAL_EXIT"

save_report
echo "collect_exit=$COLLECT_EXIT eval_exit=$EVAL_EXIT" > "$OUT/exit_codes.txt"
stamp "done"
