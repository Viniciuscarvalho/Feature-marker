#!/bin/bash
# lib/display.sh — Terminal progress and formatting

display_feature_status() {
  local feat_id="$1"
  local title="$2"
  local priority="$3"
  local status="$4"
  local agent="${5:-feature-marker}"

  printf "  %-14s %-6s %-20s %s\n" "$feat_id" "$priority" "$status" "$agent"
}

display_feature_result() {
  local feat_id="$1"
  local status
  status=$(wt_get_status "$feat_id")
  local phase=""

  if [ -f "$STATE_DIR/$feat_id/status.json" ]; then
    phase=$(node -p "JSON.parse(require('fs').readFileSync('$STATE_DIR/$feat_id/status.json','utf-8')).phase" 2>/dev/null || echo "")
  fi

  echo "  $feat_id: $status ($phase)"
}

display_backlog() {
  local backlog_file="$1"

  local total ready blocked done_count
  total=$(node -p "JSON.parse(require('fs').readFileSync('$backlog_file','utf-8')).length" 2>/dev/null || echo "0")
  ready=$(node -p "JSON.parse(require('fs').readFileSync('$backlog_file','utf-8')).filter(i=>i.status==='backlog').length" 2>/dev/null || echo "0")
  blocked=$(node -p "JSON.parse(require('fs').readFileSync('$backlog_file','utf-8')).filter(i=>i.status==='blocked').length" 2>/dev/null || echo "0")
  done_count=$(node -p "JSON.parse(require('fs').readFileSync('$backlog_file','utf-8')).filter(i=>i.status==='done').length" 2>/dev/null || echo "0")

  echo ""
  echo "  Backlog: $total features"
  echo "    Ready:   $ready"
  echo "    Blocked: $blocked"
  echo "    Done:    $done_count"
}

# display_backlog_table [active_feat_id]
# Prints a live table of all features in STATE_DIR with status, phase, and token cost.
display_backlog_table() {
  local active_feat="${1:-}"
  [ ! -d "$STATE_DIR" ] && return
  local _g="${C_GREEN:-}" _r="${C_RED:-}" _y="${C_YELLOW:-}" \
        _cy="${C_CYAN:-}" _d="${C_DIM:-}" _bo="${C_BOLD:-}" _nc="${C_NC:-}"
  node -e "
    const fs = require('fs'), path = require('path');
    const sd = '$STATE_DIR', active = '$active_feat';
    const G='$_g', R='$_r', Y='$_y', CY='$_cy', D='$_d', BO='$_bo', NC='$_nc';
    let dirs;
    try { dirs = fs.readdirSync(sd).filter(d => fs.existsSync(path.join(sd,d,'status.json'))); }
    catch(e) { process.exit(0); }
    if (!dirs.length) process.exit(0);
    const features = dirs.map(d => {
      const s = JSON.parse(fs.readFileSync(path.join(sd,d,'status.json'),'utf-8'));
      let tokens = 0;
      try { tokens = JSON.parse(fs.readFileSync(path.join(sd,d,'cost.json'),'utf-8')).cumulative_tokens||0; } catch(e){}
      return { id: d, status: s.status, phase: s.phase||'pending', tokens };
    });
    const doneN = features.filter(f=>f.status==='done'||f.status==='pr-created').length;
    const totalTok = features.reduce((s,f)=>s+f.tokens,0);
    const fmtTok = n => n>=1000 ? Math.round(n/1000)+'k' : (n||'—');
    // icon() returns a single colored glyph (1 visible char + ANSI codes).
    // Status cell = icon(1) + space(1) + label(≤10 padded) = 12 visible chars.
    const icon = f => {
      if (f.id===active||f.status==='in-progress') return CY+'→'+NC;
      if (f.status==='done'||f.status==='pr-created') return G+'✓'+NC;
      if (f.status==='failed') return R+'✗'+NC;
      if (f.status==='paused') return Y+'⏸'+NC;
      return D+'·'+NC;
    };
    const hdrText = '  BACKLOG  ['+doneN+'/'+features.length+' done]'+(totalTok?' — ~'+fmtTok(totalTok)+' tokens':'');
    const W = 64;
    const pad = (s,n) => String(s).substring(0,n).padEnd(n);
    console.log('');
    console.log('  ┌'+'─'.repeat(W)+'┐');
    console.log('  │  '+BO+CY+hdrText+NC+' '.repeat(Math.max(0,W-2-hdrText.length))+'│');
    console.log('  ├'+'─'.repeat(16)+'┬'+'─'.repeat(14)+'┬'+'─'.repeat(14)+'┬'+'─'.repeat(18)+'┤');
    console.log('  │  '+pad('Feature',14)+'│  '+pad('Status',12)+'│  '+pad('Phase',12)+'│  '+pad('Tokens',14)+'│');
    console.log('  ├'+'─'.repeat(16)+'┼'+'─'.repeat(14)+'┼'+'─'.repeat(14)+'┼'+'─'.repeat(18)+'┤');
    for (const f of features) {
      const ico = icon(f);
      const statusLabel = (f.status==='pr-created'?'pr-created':f.status).substring(0,10).padEnd(10);
      const pl = (f.phase).substring(0,12).padEnd(12);
      const tl = String(fmtTok(f.tokens)).padStart(14);
      console.log('  │  '+pad(f.id,14)+'│  '+ico+' '+statusLabel+'│  '+pl+'│  '+tl+'  │');
    }
    console.log('  └'+'─'.repeat(16)+'┴'+'─'.repeat(14)+'┴'+'─'.repeat(14)+'┴'+'─'.repeat(18)+'┘');
  " 2>/dev/null || true
}

draw_progress_bar() {
  local current="$1"
  local total="$2"
  local width="${3:-20}"

  [ "$total" -eq 0 ] && total=1
  local filled=$((current * width / total))
  local empty=$((width - filled))

  printf '%s%s' "$(printf '█%.0s' $(seq 1 $filled 2>/dev/null) || true)" "$(printf '░%.0s' $(seq 1 $empty 2>/dev/null) || true)"
}

display_summary() {
  local done_n="$1" pr_n="$2" ready_n="$3" failed_n="$4" total_time="$5" processed="$6" ran_n="${7:-$6}" paused_n="${8:-0}"

  echo ""
  echo "  ┌──────────────────────────────────────┐"
  echo "  │  Orchestrator Summary                │"
  echo "  ├──────────────────────────────────────┤"
  printf "  │  Done:    %-26s │\n" "$done_n"
  printf "  │  PR:      %-26s │\n" "$pr_n"
  printf "  │  Ready:   %-26s │\n" "$ready_n"
  printf "  │  Failed:  %-26s │\n" "$failed_n"
  printf "  │  Paused:  %-26s │\n" "$paused_n"
  echo "  ├──────────────────────────────────────┤"
  printf "  │  Ran this session: %-17s │\n" "$ran_n"
  echo "  ├──────────────────────────────────────┤"
  printf "  │  Total:   %-26s │\n" "${total_time}s"
  local avg=0
  [ "${ran_n:-0}" -gt 0 ] && avg=$((total_time / ran_n))
  printf "  │  Avg:     %-26s │\n" "${avg}s/feature"
  echo "  └──────────────────────────────────────┘"
}

# display_paused_handoff <feat_id> <attempts> [pause_reason_path]
# Prints a plain-text guidance block when Phase 3 is exhausted.
# PR B upgrades this to a boxed ANSI variant.
display_paused_handoff() {
  local feat_id="$1" attempts="$2" pause_reason_path="${3:-}"

  local resume_cmd="feature-marker-orchestrate --resume-paused $feat_id --ack"
  local trail_path=""
  if [ -n "$pause_reason_path" ] && [ -f "$pause_reason_path" ]; then
    trail_path=$(node -p "
      try { JSON.parse(require('fs').readFileSync('$pause_reason_path','utf-8')).trail_path || ''; }
      catch(e) { ''; }
    " 2>/dev/null || echo "")
  fi

  echo ""
  printf "  ${C_YELLOW:-}⏸${C_NC:-}  %s — Phase 3 paused after %s fix attempt(s)\n" "$feat_id" "$attempts"
  echo "     Tests still failing. Review the attempt trail and fix manually."
  echo ""
  [ -n "$trail_path" ] && echo "     Trail: $trail_path"
  printf "     Resume: ${C_CYAN:-}%s${C_NC:-}\n" "$resume_cmd"
  echo ""
  echo "     Backlog continues with the next ready feature."
  echo ""
}

display_routing() {
  local routing_file="$1"

  [ ! -f "$routing_file" ] && return

  local count
  count=$(node -p "JSON.parse(require('fs').readFileSync('$routing_file','utf-8')).length" 2>/dev/null || echo "0")
  [ "$count" -eq 0 ] && return

  echo ""
  echo "  Task Routing:"
  node -e "
    const r = JSON.parse(require('fs').readFileSync('$routing_file','utf-8'));
    r.forEach(t => {
      const agent = t.agent === 'feature-marker' ? 'feature-marker (generic)' : t.agent;
      console.log('    Task ' + t.task_id + ': ' + t.title.substring(0,35).padEnd(35) + ' -> ' + agent);
    });
  " 2>/dev/null || true
}

# display_next_steps <feat_id> <exit_code> <next_feat_id> <autonomy> [model] [adapter]
# Prints an actionable "what next" box after each feature completes.
display_next_steps() {
  local feat_id="$1" exit_code="$2" next_feat="${3:-}" autonomy="${4:-full_auto}" model="${5:-}" _adapter="${6:-}"

  local cmd="feature-marker-orchestrate run --autonomy $autonomy"
  [ -n "$model" ] && [ "$model" != "default" ] && [ "$model" != "opusplan" ] && cmd="$cmd --model $model"

  local W=62
  local inner=$((W - 4))  # content width between "  │  " and "  │"

  echo ""
  if [ "$exit_code" -ne 0 ]; then
    printf "  ${C_YELLOW:-}⚠${C_NC:-}  %s exited with errors (code %s) — review log before continuing.\n" "$feat_id" "$exit_code"
  fi
  printf "  ┌%s┐\n" "$(printf '─%.0s' $(seq 1 $W))"
  if [ -n "$next_feat" ]; then
    printf "  │  ${C_GREEN:-}%-*s${C_NC:-}│\n" "$inner" "$feat_id → done.  Next: $next_feat"
    printf "  │  %-*s│\n" "$inner" ""
    printf "  │  %-*s│\n" "$inner" "Continue with the same command:"
    printf "  │  %-*s│\n" "$inner" ""
    printf "  │    ${C_CYAN:-}%-*s${C_NC:-}│\n" "$((inner - 2))" "$cmd"
  else
    printf "  │  ${C_GREEN:-}%-*s${C_NC:-}│\n" "$inner" "All features complete."
    printf "  │  %-*s│\n" "$inner" ""
    printf "  │  %-*s│\n" "$inner" "Run: feature-marker-orchestrate status"
  fi
  printf "  └%s┘\n" "$(printf '─%.0s' $(seq 1 $W))"
  echo ""
}

# display_live_phase <feat_id> <start_epoch>
# Reads $STATE_DIR/$feat_id/status.json and cost.json to emit a one-line
# live status during a Claude run. Gracefully omits missing segments.
display_live_phase() {
  local feat_id="$1" start_epoch="${2:-0}"
  local status_file="$STATE_DIR/$feat_id/status.json"
  local cost_file="$STATE_DIR/$feat_id/cost.json"

  local phase="" task_seg="" tokens="?" elapsed=""

  if [ -f "$status_file" ]; then
    phase=$(node -p "
      try {
        const s = JSON.parse(require('fs').readFileSync('$status_file','utf-8'));
        s.phase || '?';
      } catch(e) { '?'; }
    " 2>/dev/null || echo "?")
    task_seg=$(node -p "
      try {
        const s = JSON.parse(require('fs').readFileSync('$status_file','utf-8'));
        (s.task_index && s.total_tasks) ? ' · task ' + s.task_index + '/' + s.total_tasks : '';
      } catch(e) { ''; }
    " 2>/dev/null || echo "")
  fi

  if [ -f "$cost_file" ]; then
    tokens=$(node -p "
      try {
        const t = JSON.parse(require('fs').readFileSync('$cost_file','utf-8')).cumulative_tokens || 0;
        '~' + (t >= 1000 ? Math.round(t/1000)+'k' : t);
      } catch(e) { '?' }
    " 2>/dev/null || echo "?")
  fi

  if [ "$start_epoch" -gt 0 ] 2>/dev/null; then
    local now secs
    now=$(date +%s)
    secs=$(( now - start_epoch ))
    elapsed=" · $(( secs / 60 ))m$(( secs % 60 ))s"
  fi

  printf "  ${C_CYAN:-}→${C_NC:-}  %s  •  Phase %s%s  •  %s tokens%s\n" \
    "$feat_id" "${phase:-?}" "$task_seg" "$tokens" "$elapsed"
}
