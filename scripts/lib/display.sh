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
  node -e "
    const fs = require('fs'), path = require('path');
    const sd = '$STATE_DIR', active = '$active_feat';
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
    const icon = f => {
      if (f.id===active||f.status==='in-progress') return '→';
      if (f.status==='done'||f.status==='pr-created') return '✓';
      if (f.status==='failed') return '✗';
      if (f.status==='paused') return '⏸';
      return '·';
    };
    const hdr = '  BACKLOG  ['+doneN+'/'+features.length+' done]'+(totalTok?' — ~'+fmtTok(totalTok)+' tokens':'');
    const W = 64;
    const pad = (s,n) => String(s).substring(0,n).padEnd(n);
    console.log('');
    console.log('  ┌'+'─'.repeat(W)+'┐');
    console.log('  │  '+hdr.padEnd(W-2)+'│');
    console.log('  ├'+'─'.repeat(16)+'┬'+'─'.repeat(14)+'┬'+'─'.repeat(14)+'┬'+'─'.repeat(18)+'┤');
    console.log('  │  '+pad('Feature',14)+'│  '+pad('Status',12)+'│  '+pad('Phase',12)+'│  '+pad('Tokens',14)+'│');
    console.log('  ├'+'─'.repeat(16)+'┼'+'─'.repeat(14)+'┼'+'─'.repeat(14)+'┼'+'─'.repeat(18)+'┤');
    for (const f of features) {
      const ico = icon(f);
      const sl = (ico+' '+(f.status==='pr-created'?'pr-created':f.status)).substring(0,12).padEnd(12);
      const pl = (f.phase).substring(0,12).padEnd(12);
      const tl = String(fmtTok(f.tokens)).padStart(14);
      console.log('  │  '+pad(f.id,14)+'│  '+sl+'│  '+pl+'│  '+tl+'  │');
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
# Prints a boxed guidance block when Phase 3 fix budget is exhausted.
# Uses FM_YELLOW / FM_BOLD / FM_RESET when colors are initialized.
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

  local y="${FM_YELLOW:-}" b="${FM_BOLD:-}" r="${FM_RESET:-}"

  echo ""
  printf "  %s┌──────────────────────────────────────────────────────────┐%s\n" "$y" "$r"
  printf "  %s│%s  %s⏸  %s — Phase 3 paused%s\n" "$y" "$r" "$b" "$feat_id" "$r"
  printf "  %s│%s\n" "$y" "$r"
  printf "  %s│%s  Exhausted %s fix attempt(s). Tests still failing.\n" "$y" "$r" "$attempts"
  printf "  %s│%s  Review the attempt trail and fix manually.\n" "$y" "$r"
  if [ -n "$trail_path" ]; then
    printf "  %s│%s\n" "$y" "$r"
    printf "  %s│%s  Trail: %s\n" "$y" "$r" "$trail_path"
  fi
  printf "  %s│%s\n" "$y" "$r"
  printf "  %s│%s  Resume: %s\n" "$y" "$r" "$resume_cmd"
  printf "  %s│%s  Backlog continues with the next ready feature.\n" "$y" "$r"
  printf "  %s└──────────────────────────────────────────────────────────┘%s\n" "$y" "$r"
  echo ""
}

# display_fullauto_banner
# Boxed warning printed once when AUTONOMY=full_auto — bypassPermissions active.
display_fullauto_banner() {
  local y="${FM_YELLOW:-}" b="${FM_BOLD:-}" r="${FM_RESET:-}"
  echo ""
  printf "  %s┌──────────────────────────────────────────────────────────┐%s\n" "$y" "$r"
  printf "  %s│%s  %s⚠  FULL_AUTO — bypassPermissions mode%s\n" "$y" "$r" "$b" "$r"
  printf "  %s│%s  File writes, bash commands, network — no prompts.\n" "$y" "$r"
  printf "  %s│%s  Phase 3 Ralph Loop active — learning store captures.\n" "$y" "$r"
  printf "  %s└──────────────────────────────────────────────────────────┘%s\n" "$y" "$r"
  echo ""
}

# display_invocation_header <feat_id> <autonomy> <model> <agent> <wt_path> <log_file>
# Printed before Claude is invoked. Shows feature, mode, and artifact paths.
display_invocation_header() {
  local feat_id="$1" autonomy="$2" model="${3:-default}" agent="$4" wt_path="$5" log_file="$6"
  local c="${FM_CYAN:-}" b="${FM_BOLD:-}" d="${FM_DIM:-}" r="${FM_RESET:-}"
  [ -z "$model" ] && model="default"

  echo ""
  printf "  %s▶%s  %s%s%s\n" "$c" "$r" "$b" "$feat_id" "$r"
  printf "  %s│%s  Autonomy : %s\n" "$d" "$r" "$autonomy"
  printf "  %s│%s  Model    : %s\n" "$d" "$r" "$model"
  printf "  %s│%s  Agent    : %s\n" "$d" "$r" "$agent"
  if [ "$autonomy" = "full_auto" ]; then
    printf "  %s│%s  Artifacts: %s/tasks/prd-%s/\n" "$d" "$r" "$wt_path" "$feat_id"
    printf "  %s│%s  Log      : %s\n" "$d" "$r" "$log_file"
    printf "  %s│%s  %s(output buffered — watcher prints progress below)%s\n" "$d" "$r" "$d" "$r"
  fi
  echo ""
}

# _watcher_format_tick <elapsed_s> <changed_files_space_sep> <current_phase> <interactive> <style>
# Formats a single heartbeat line. Extracted for testability.
# style: "classic" for old [progress] format; anything else for new format.
# interactive: "1" for TTY-rich output, "0" for log-safe plain text.
_watcher_format_tick() {
  local elapsed="$1" changed_files="$2" current_phase="$3" interactive="${4:-0}" style="${5:-}"

  local phase_label=""
  if declare -f fm_phase_label &>/dev/null && [ -n "$current_phase" ]; then
    phase_label=$(fm_phase_label "$current_phase" 2>/dev/null || echo "?")
  fi

  if [ "$style" = "classic" ]; then
    if [ -n "$changed_files" ]; then
      printf '  [progress] %ds elapsed — files written: %s\n' "$elapsed" "$changed_files"
    else
      printf '  [progress] %ds elapsed — Claude working (no new files)\n' "$elapsed"
    fi
    return
  fi

  local phase_hdr=""
  if [ -n "$current_phase" ] && [ -n "$phase_label" ]; then
    phase_hdr="[Phase ${current_phase}/4 · ${phase_label}] "
  fi

  if [ "$interactive" = "1" ]; then
    local c="${FM_CYAN:-}" d="${FM_DIM:-}" r="${FM_RESET:-}"
    if [ -n "$changed_files" ]; then
      printf '  %s▶%s %s%ds · wrote %s\n' "$c" "$r" "$phase_hdr" "$elapsed" \
        "$(printf '%s' "$changed_files" | sed 's/[[:space:]]*$//')"
    else
      printf '  %s·%s %s%ds\n' "$d" "$r" "$phase_hdr" "$elapsed"
    fi
  else
    if [ -n "$changed_files" ]; then
      printf '  [fm] phase=%s elapsed=%ds files=%s\n' \
        "${current_phase:-?}" "$elapsed" \
        "$(printf '%s' "$changed_files" | sed 's/[[:space:]]*$//' | tr ' ' ',')"
    else
      printf '  [fm] phase=%s elapsed=%ds\n' "${current_phase:-?}" "$elapsed"
    fi
  fi
}
export -f _watcher_format_tick

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
    printf "  ⚠  %s exited with errors (code %s) — review log before continuing.\n" "$feat_id" "$exit_code"
  fi
  printf "  ┌%s┐\n" "$(printf '─%.0s' $(seq 1 $W))"
  if [ -n "$next_feat" ]; then
    printf "  │  %-*s│\n" "$inner" "$feat_id → done.  Next: $next_feat"
    printf "  │  %-*s│\n" "$inner" ""
    printf "  │  %-*s│\n" "$inner" "Continue with the same command:"
    printf "  │  %-*s│\n" "$inner" ""
    printf "  │    %-*s│\n" "$((inner - 2))" "$cmd"
  else
    printf "  │  %-*s│\n" "$inner" "All features complete."
    printf "  │  %-*s│\n" "$inner" ""
    printf "  │  %-*s│\n" "$inner" "Run: feature-marker-orchestrate status"
  fi
  printf "  └%s┘\n" "$(printf '─%.0s' $(seq 1 $W))"
  echo ""
}
