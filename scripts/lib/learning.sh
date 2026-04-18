#!/bin/bash
# lib/learning.sh — Layered error learning store (ADR-008 PR-C, ADR-009 PR-F)
#
# 3-tier store:
#   feature : $STATE_DIR/{feat_id}/learned.json
#   project : $ROOT_DIR/.claude/feature-state/learned.json
#   global  : ~/.claude/feature-marker/learned/learned.json
#
# Entry schema (all fields):
#   id, pattern, fix, tier, created_at, last_seen, hits,
#   success_count, failure_count, confidence, ttl_days,
#   archived, promotion_candidate
#
# ADR-009 PR-F additions:
#   - learning_write appends embedding vector to learned.embeddings.jsonl
#     when local_model.enabled=true and backend=embedding
#   - learning_read falls back to cosine-similarity retrieval when
#     backend=embedding and a local model is reachable
#
# JSON manipulation uses node -e (Node.js is a declared runtime dependency).

# ── Tier path helpers ────────────────────────────────────────────────

_learning_feature_path() {
  local feat_id="$1"
  echo "$STATE_DIR/$feat_id/learned.json"
}

_learning_project_path() {
  echo "$ROOT_DIR/.claude/feature-state/learned.json"
}

_learning_global_path() {
  echo "$HOME/.claude/feature-marker/learned/learned.json"
}

_learning_ensure_file() {
  local path="$1"
  local dir
  dir=$(dirname "$path")
  mkdir -p "$dir"
  [ ! -f "$path" ] && echo '[]' > "$path"
}

# Path to the embedding sidecar file alongside a learned.json store.
_learning_embeddings_path() {
  local store_path="$1"
  echo "${store_path%.json}.embeddings.jsonl"
}

# Append an embedding vector to the sidecar JSONL file.
# Usage: _learning_write_embedding <store_path> <learn_id> <embedding_json_array>
_learning_write_embedding() {
  local store_path="$1"
  local learn_id="$2"
  local embedding="$3"

  [ -z "$embedding" ] || [ "$embedding" = "[]" ] && return

  local emb_path
  emb_path=$(_learning_embeddings_path "$store_path")

  node -e "
    const fs = require('fs');
    const line = JSON.stringify({ id: '${learn_id}', embedding: ${embedding} });
    fs.appendFileSync('${emb_path}', line + '\n');
  " 2>/dev/null || true
}

# Cosine similarity search against the embeddings sidecar.
# Usage: _learning_cosine_search <store_path> <query_embedding_json> <threshold>
# Prints the learn_id of the best match, or empty string if none exceeds threshold.
_learning_cosine_search() {
  local store_path="$1"
  local query_embedding="$2"
  local threshold="${3:-0.85}"

  local emb_path
  emb_path=$(_learning_embeddings_path "$store_path")
  [ ! -f "$emb_path" ] && echo "" && return

  node -e "
    const fs = require('fs');
    const lines = fs.readFileSync('${emb_path}', 'utf-8').trim().split('\n').filter(Boolean);
    const query = ${query_embedding};
    if (!Array.isArray(query) || query.length === 0) { process.stdout.write(''); process.exit(0); }

    function cosine(a, b) {
      let dot = 0, na = 0, nb = 0;
      const len = Math.min(a.length, b.length);
      for (let i = 0; i < len; i++) { dot += a[i]*b[i]; na += a[i]*a[i]; nb += b[i]*b[i]; }
      return na === 0 || nb === 0 ? 0 : dot / (Math.sqrt(na) * Math.sqrt(nb));
    }

    let bestId = '', bestSim = ${threshold};
    for (const line of lines) {
      try {
        const e = JSON.parse(line);
        const sim = cosine(query, e.embedding || []);
        if (sim > bestSim) { bestSim = sim; bestId = e.id; }
      } catch(_) {}
    }
    process.stdout.write(bestId);
  " 2>/dev/null || echo ""
}

# ── learning_ttl_sweep ───────────────────────────────────────────────
# Usage: learning_ttl_sweep <tier> <path>
# Moves entries whose TTL has expired to {dir}/_archive/ttl-<timestamp>.json.

learning_ttl_sweep() {
  local tier="$1"
  local path="$2"

  [ ! -f "$path" ] && return

  local dir
  dir=$(dirname "$path")
  local archive_dir="$dir/_archive"
  mkdir -p "$archive_dir"

  node -e "
    const fs = require('fs');
    const path = '$path';
    const archiveDir = '$archive_dir';
    let entries;
    try { entries = JSON.parse(fs.readFileSync(path, 'utf-8')); } catch(e) { entries = []; }

    const now = Date.now();
    const active = [];
    const expired = [];

    entries.forEach(e => {
      if (e.archived) { active.push(e); return; }
      const ttl = (e.ttl_days || 90) * 86400 * 1000;
      const created = new Date(e.created_at).getTime();
      if (now - created > ttl) {
        expired.push(e);
      } else {
        active.push(e);
      }
    });

    if (expired.length > 0) {
      const ts = new Date().toISOString().replace(/[:.]/g, '-');
      fs.writeFileSync(
        archiveDir + '/ttl-' + ts + '.json',
        JSON.stringify(expired, null, 2)
      );
      fs.writeFileSync(path, JSON.stringify(active, null, 2));
    }
  " 2>/dev/null || true
}

# ── learning_read ─────────────────────────────────────────────────────
# Usage: learning_read <feat_id> <error_sig>
# Walks feature → project → global tiers looking for a matching pattern.
# Prints the first matching entry as JSON, or empty string if none found.

learning_read() {
  local feat_id="$1"
  local error_sig="$2"

  local feat_path project_path global_path
  feat_path=$(_learning_feature_path "$feat_id")
  project_path=$(_learning_project_path)
  global_path=$(_learning_global_path)

  # Exact-match pass (always attempted first regardless of backend)
  local exact_result
  exact_result=$(node -e "
    const fs = require('fs');
    const sig = $(node -p "JSON.stringify('$error_sig')" 2>/dev/null || echo "\"\"");

    function readTier(p) {
      try { return JSON.parse(fs.readFileSync(p, 'utf-8')); } catch(e) { return []; }
    }

    const tiers = ['$feat_path', '$project_path', '$global_path'];
    for (const p of tiers) {
      const entries = readTier(p);
      const match = entries.find(e => !e.archived && e.pattern === sig);
      if (match) {
        console.log(JSON.stringify(match));
        process.exit(0);
      }
    }
    console.log('');
  " 2>/dev/null || echo "")

  if [ -n "$exact_result" ]; then
    echo "$exact_result"
    return 0
  fi

  # ADR-009 PR-F: cosine-similarity fallback when backend=embedding
  local similarity_backend="${CFG_LEARNING_SIMILARITY_BACKEND:-exact}"
  if [ "$similarity_backend" = "embedding" ] && [ "${LOCAL_MODEL_ENABLED:-false}" = "true" ]; then
    local query_embedding
    query_embedding=$(local_model::embed "$error_sig")

    if [ -n "$query_embedding" ] && [ "$query_embedding" != "[]" ]; then
      local sim_threshold="${CFG_LEARNING_SIMILARITY_THRESHOLD:-0.85}"

      for tier_path in "$project_path" "$global_path" "$feat_path"; do
        [ ! -f "$tier_path" ] && continue
        local matched_id
        matched_id=$(_learning_cosine_search "$tier_path" "$query_embedding" "$sim_threshold")
        if [ -n "$matched_id" ]; then
          node -p "
            try {
              const entries = JSON.parse(require('fs').readFileSync('$tier_path','utf-8'));
              const m = entries.find(e => e.id === '$matched_id' && !e.archived);
              m ? JSON.stringify(m) : '';
            } catch(e) { ''; }
          " 2>/dev/null || echo ""
          return 0
        fi
      done
    fi
  fi

  echo ""
}

# ── learning_write ────────────────────────────────────────────────────
# Usage: learning_write <feat_id> <error_sig> <fix>
# Writes a new entry to the project tier (or updates existing if pattern matches).
# Generates id: learn-<random hex>.

learning_write() {
  local feat_id="$1"
  local error_sig="$2"
  local fix="$3"

  local project_path
  project_path=$(_learning_project_path)
  _learning_ensure_file "$project_path"

  local ttl_days="${CFG_LEARNING_TTL_DAYS:-90}"

  node -e "
    const fs = require('fs');
    const path = '$project_path';
    const sig = $(node -p "JSON.stringify('$error_sig')" 2>/dev/null || echo "\"\"");
    const fix = $(node -p "JSON.stringify('$fix')" 2>/dev/null || echo "\"\"");

    let entries;
    try { entries = JSON.parse(fs.readFileSync(path, 'utf-8')); } catch(e) { entries = []; }

    const existing = entries.find(e => !e.archived && e.pattern === sig);
    const now = new Date().toISOString();

    if (existing) {
      existing.hits = (existing.hits || 0) + 1;
      existing.last_seen = now;
      existing.fix = fix;
    } else {
      const rand = Math.random().toString(16).slice(2, 10);
      entries.push({
        id: 'learn-' + rand,
        pattern: sig,
        fix: fix,
        tier: 'project',
        created_at: now,
        last_seen: now,
        hits: 1,
        success_count: 0,
        failure_count: 0,
        confidence: 0.5,
        ttl_days: $ttl_days,
        archived: false,
        promotion_candidate: false
      });
    }

    fs.writeFileSync(path, JSON.stringify(entries, null, 2));
  " 2>/dev/null || true

  # ADR-009 PR-F: append embedding vector to sidecar when local model enabled
  if [ "${LOCAL_MODEL_ENABLED:-false}" = "true" ] && \
     [ "${CFG_LEARNING_SIMILARITY_BACKEND:-exact}" = "embedding" ]; then
    local new_id
    new_id=$(node -p "
      try {
        const entries = JSON.parse(require('fs').readFileSync('$project_path','utf-8'));
        const sig = $(node -p "JSON.stringify('$error_sig')" 2>/dev/null || echo "\"\"");
        const m = entries.find(e => !e.archived && e.pattern === sig);
        m ? m.id : '';
      } catch(e) { ''; }
    " 2>/dev/null || echo "")
    if [ -n "$new_id" ]; then
      local embedding
      embedding=$(local_model::embed "$error_sig")
      _learning_write_embedding "$project_path" "$new_id" "$embedding"
    fi
  fi
}

# ── learning_verify ───────────────────────────────────────────────────
# Usage: learning_verify <learn_id> <success:true|false> <tier_path>
# Updates success_count/failure_count/confidence.
# Auto-archives if confidence < 0.5 AND hits >= 3.
# Marks promotion_candidate = true if confidence >= 0.8 AND hits >= 3.

learning_verify() {
  local learn_id="$1"
  local success="$2"
  local tier_path="$3"

  [ ! -f "$tier_path" ] && return

  node -e "
    const fs = require('fs');
    const path = '$tier_path';
    let entries;
    try { entries = JSON.parse(fs.readFileSync(path, 'utf-8')); } catch(e) { return; }

    const e = entries.find(e => e.id === '$learn_id');
    if (!e) return;

    if ('$success' === 'true') {
      e.success_count = (e.success_count || 0) + 1;
    } else {
      e.failure_count = (e.failure_count || 0) + 1;
    }

    const total = e.success_count + e.failure_count;
    e.confidence = total > 0 ? e.success_count / total : 0.5;
    e.last_seen = new Date().toISOString();

    if (e.confidence < 0.5 && e.hits >= 3) {
      e.archived = true;
    }

    if (e.confidence >= 0.8 && e.hits >= 3) {
      e.promotion_candidate = true;
    }

    fs.writeFileSync(path, JSON.stringify(entries, null, 2));
  " 2>/dev/null || true
}

# ── learning_prune_sweep ──────────────────────────────────────────────
# Usage: learning_prune_sweep <tier_path>
# Archives entries that meet prune criteria:
#   confidence < 0.5 AND hits >= 3

learning_prune_sweep() {
  local tier_path="$1"

  [ ! -f "$tier_path" ] && return

  local dir
  dir=$(dirname "$tier_path")
  local archive_dir="$dir/_archive"
  mkdir -p "$archive_dir"

  node -e "
    const fs = require('fs');
    let entries;
    try { entries = JSON.parse(fs.readFileSync('$tier_path', 'utf-8')); } catch(e) { entries = []; }

    const pruned = [];
    const kept = entries.map(e => {
      if (!e.archived && e.confidence < 0.5 && (e.hits || 0) >= 3) {
        e.archived = true;
        pruned.push(e);
      }
      return e;
    });

    if (pruned.length > 0) {
      const ts = new Date().toISOString().replace(/[:.]/g, '-');
      fs.writeFileSync(
        '$archive_dir/pruned-' + ts + '.json',
        JSON.stringify(pruned, null, 2)
      );
    }
    fs.writeFileSync('$tier_path', JSON.stringify(kept, null, 2));
  " 2>/dev/null || true
}

# ── learning_list ─────────────────────────────────────────────────────
# Usage: learning_list <tier_path> <candidates_only:true|false>
# Lists entries from the given tier path.
# If candidates_only=true, only entries with promotion_candidate=true are shown.

learning_list() {
  local tier_path="$1"
  local candidates_only="${2:-false}"

  if [ ! -f "$tier_path" ]; then
    info "No learning data at: $tier_path"
    return
  fi

  node -e "
    const fs = require('fs');
    let entries;
    try { entries = JSON.parse(fs.readFileSync('$tier_path', 'utf-8')); } catch(e) { entries = []; }

    const candidatesOnly = '$candidates_only' === 'true';
    const filtered = entries.filter(e => {
      if (e.archived) return false;
      if (candidatesOnly && !e.promotion_candidate) return false;
      return true;
    });

    if (filtered.length === 0) {
      console.log('  No entries' + (candidatesOnly ? ' (no promotion candidates)' : '') + '.');
      return;
    }

    filtered.forEach(e => {
      const conf = (e.confidence * 100).toFixed(0) + '%';
      const cand = e.promotion_candidate ? ' [candidate]' : '';
      console.log('  ' + e.id + cand);
      console.log('    pattern   : ' + e.pattern.substring(0, 60));
      console.log('    fix       : ' + e.fix.substring(0, 60));
      console.log('    hits      : ' + e.hits + '  success: ' + e.success_count + '  failure: ' + e.failure_count);
      console.log('    confidence: ' + conf + '  tier: ' + e.tier);
      console.log('    last_seen : ' + e.last_seen);
      console.log('');
    });
  " 2>/dev/null || true
}

# ── learning_archive ──────────────────────────────────────────────────
# Usage: learning_archive <learn_id> <tier_path>
# Sets archived=true on the entry and moves it to {dir}/_archive/manual-<id>.json.

learning_archive() {
  local learn_id="$1"
  local tier_path="$2"

  [ ! -f "$tier_path" ] && { err "No learning file at: $tier_path"; return 1; }

  local dir
  dir=$(dirname "$tier_path")
  local archive_dir="$dir/_archive"
  mkdir -p "$archive_dir"

  node -e "
    const fs = require('fs');
    let entries;
    try { entries = JSON.parse(fs.readFileSync('$tier_path', 'utf-8')); } catch(e) { entries = []; }

    const entry = entries.find(e => e.id === '$learn_id');
    if (!entry) {
      console.error('Entry not found: $learn_id');
      process.exit(1);
    }

    entry.archived = true;
    entry.archived_at = new Date().toISOString();

    fs.writeFileSync(
      '$archive_dir/manual-$learn_id.json',
      JSON.stringify([entry], null, 2)
    );
    fs.writeFileSync('$tier_path', JSON.stringify(entries, null, 2));
    console.log('  Archived: $learn_id');
  " 2>/dev/null || true
}

# ── learning_promote ──────────────────────────────────────────────────
# Usage: learning_promote <learn_id> <from_tier_path> <global_path>
# Copies the entry from from_tier_path into the global tier.
# Updates the entry's tier field to "global".

learning_promote() {
  local learn_id="$1"
  local from_tier_path="$2"
  local global_path="$3"

  [ ! -f "$from_tier_path" ] && { err "Source tier not found: $from_tier_path"; return 1; }

  _learning_ensure_file "$global_path"

  node -e "
    const fs = require('fs');
    let src;
    try { src = JSON.parse(fs.readFileSync('$from_tier_path', 'utf-8')); } catch(e) { src = []; }

    const entry = src.find(e => e.id === '$learn_id');
    if (!entry) {
      console.error('Entry not found: $learn_id');
      process.exit(1);
    }

    let global;
    try { global = JSON.parse(fs.readFileSync('$global_path', 'utf-8')); } catch(e) { global = []; }

    const already = global.find(e => e.id === entry.id);
    if (already) {
      console.log('  Already in global tier: $learn_id');
      process.exit(0);
    }

    const promoted = Object.assign({}, entry, {
      tier: 'global',
      promoted_at: new Date().toISOString(),
      promotion_candidate: false
    });
    global.push(promoted);
    fs.writeFileSync('$global_path', JSON.stringify(global, null, 2));
    console.log('  Promoted to global: $learn_id');
  " 2>/dev/null || true
}
