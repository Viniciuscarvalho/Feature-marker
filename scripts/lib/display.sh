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
  local done_n="$1" pr_n="$2" ready_n="$3" failed_n="$4" total_time="$5" processed="$6"

  echo ""
  echo "  ┌──────────────────────────────────────┐"
  echo "  │  Orchestrator Summary                │"
  echo "  ├──────────────────────────────────────┤"
  printf "  │  Done:    %-26s │\n" "$done_n"
  printf "  │  PR:      %-26s │\n" "$pr_n"
  printf "  │  Ready:   %-26s │\n" "$ready_n"
  printf "  │  Failed:  %-26s │\n" "$failed_n"
  echo "  ├──────────────────────────────────────┤"
  printf "  │  Total:   %-26s │\n" "${total_time}s"
  local avg=0
  [ "$processed" -gt 0 ] && avg=$((total_time / processed))
  printf "  │  Avg:     %-26s │\n" "${avg}s/feature"
  echo "  └──────────────────────────────────────┘"
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
