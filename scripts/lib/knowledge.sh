#!/bin/bash
# lib/knowledge.sh — Structured knowledge base (Phase C)
#
# Shell-side learning system. Zero extra Claude invocations.
# Records error patterns with structured metadata, derives behavioral
# rules that change orchestrator behavior (not just prompts).
#
# Storage: .orchestrator/knowledge-base.json
#          .orchestrator/behavioral-rules.json

set -euo pipefail

KB_DIR="${CONFIG_DIR:-.orchestrator}"
KB_FILE="$KB_DIR/knowledge-base.json"
KB_RULES_FILE="$KB_DIR/behavioral-rules.json"

kb_init() {
  mkdir -p "$KB_DIR"

  if [ ! -f "$KB_FILE" ]; then
    node -e "
      require('fs').writeFileSync('$KB_FILE', JSON.stringify({
        version: '1.0.0',
        created_at: new Date().toISOString(),
        patterns: [],
        rules: []
      }, null, 2));
    "
  fi

  if [ ! -f "$KB_RULES_FILE" ]; then
    echo '{"rules":[],"derived_at":null}' > "$KB_RULES_FILE"
  fi

  # Migrate existing error-patterns.json if present
  local legacy="$KB_DIR/error-patterns.json"
  if [ -f "$legacy" ]; then
    local count
    count=$(node -p "JSON.parse(require('fs').readFileSync('$legacy','utf-8')).length" 2>/dev/null || echo "0")
    if [ "$count" -gt 0 ]; then
      node -e "
        const fs = require('fs');
        const legacy = JSON.parse(fs.readFileSync('$legacy', 'utf-8'));
        const kb = JSON.parse(fs.readFileSync('$KB_FILE', 'utf-8'));
        for (const entry of legacy) {
          const existing = kb.patterns.find(p =>
            p.category === entry.phase && p.signature === entry.error
          );
          if (existing) {
            existing.frequency++;
            existing.last_seen = entry.timestamp;
            if (!existing.affected_features.includes(entry.feature_id))
              existing.affected_features.push(entry.feature_id);
          } else {
            kb.patterns.push({
              id: 'err-' + String(kb.patterns.length + 1).padStart(3, '0'),
              category: entry.phase || 'unknown',
              signature: entry.error || '',
              frequency: 1,
              first_seen: entry.timestamp,
              last_seen: entry.timestamp,
              resolution: '',
              prevention: entry.suggestion || '',
              affected_features: [entry.feature_id]
            });
          }
        }
        fs.writeFileSync('$KB_FILE', JSON.stringify(kb, null, 2));
      " 2>/dev/null || true
    fi
  fi
}

kb_record_pattern() {
  local feat_id="$1"
  local category="$2"
  local signature="$3"
  local resolution="${4:-}"
  local prevention="${5:-}"

  [ ! -f "$KB_FILE" ] && kb_init

  node -e "
    const fs = require('fs');
    const kb = JSON.parse(fs.readFileSync('$KB_FILE', 'utf-8'));
    const now = new Date().toISOString();

    // Deduplicate by category + signature substring match
    const existing = kb.patterns.find(p =>
      p.category === $(printf '%s' "$category" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())") &&
      p.signature === $(printf '%s' "$signature" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())")
    );

    if (existing) {
      existing.frequency++;
      existing.last_seen = now;
      if (!existing.affected_features.includes('$feat_id'))
        existing.affected_features.push('$feat_id');
      if ($(printf '%s' "$resolution" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())"))
        existing.resolution = $(printf '%s' "$resolution" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())");
      if ($(printf '%s' "$prevention" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())"))
        existing.prevention = $(printf '%s' "$prevention" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())");
    } else {
      kb.patterns.push({
        id: 'err-' + String(kb.patterns.length + 1).padStart(3, '0'),
        category: $(printf '%s' "$category" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())"),
        signature: $(printf '%s' "$signature" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())"),
        frequency: 1,
        first_seen: now,
        last_seen: now,
        resolution: $(printf '%s' "$resolution" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())"),
        prevention: $(printf '%s' "$prevention" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())"),
        affected_features: ['$feat_id']
      });
    }

    fs.writeFileSync('$KB_FILE', JSON.stringify(kb, null, 2));
  " 2>/dev/null || true
}

kb_query() {
  local error_text="$1"

  [ ! -f "$KB_FILE" ] && echo "[]" && return

  node -e "
    const fs = require('fs');
    const kb = JSON.parse(fs.readFileSync('$KB_FILE', 'utf-8'));
    const query = $(printf '%s' "$error_text" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())").toLowerCase();

    const matches = kb.patterns.filter(p =>
      query.includes(p.signature.toLowerCase()) ||
      p.signature.toLowerCase().includes(query.substring(0, 50))
    );

    console.log(JSON.stringify(matches));
  " 2>/dev/null || echo "[]"
}

kb_derive_rules() {
  [ ! -f "$KB_FILE" ] && return

  node -e "
    const fs = require('fs');
    const kb = JSON.parse(fs.readFileSync('$KB_FILE', 'utf-8'));
    const rules = [];

    // Group patterns by category
    const byCategory = {};
    for (const p of kb.patterns) {
      if (!byCategory[p.category]) byCategory[p.category] = [];
      byCategory[p.category].push(p);
    }

    // Generate rules for recurring patterns (frequency >= 2)
    for (const [category, patterns] of Object.entries(byCategory)) {
      const totalFreq = patterns.reduce((sum, p) => sum + p.frequency, 0);
      if (totalFreq < 2) continue;

      const preventions = patterns
        .filter(p => p.prevention)
        .map(p => p.prevention);

      const instruction = preventions.length > 0
        ? preventions[0]
        : 'Review ' + category + ' errors before proceeding — this category has failed ' + totalFreq + ' times.';

      rules.push({
        id: 'rule-' + String(rules.length + 1).padStart(3, '0'),
        trigger: { category, min_frequency: 2 },
        action: 'inject_behavioral_warning',
        instruction,
        source_patterns: patterns.map(p => p.id),
        total_frequency: totalFreq,
        affected_features: [...new Set(patterns.flatMap(p => p.affected_features))]
      });
    }

    const result = { rules, derived_at: new Date().toISOString() };
    fs.writeFileSync('$KB_RULES_FILE', JSON.stringify(result, null, 2));

    // Also update kb.rules
    kb.rules = rules;
    fs.writeFileSync('$KB_FILE', JSON.stringify(kb, null, 2));
  " 2>/dev/null || true
}

kb_apply_rules() {
  local context_file="$1"

  if [ ! -f "$KB_RULES_FILE" ]; then
    # Fall back to legacy error-patterns.json injection
    if [ -f "$KB_DIR/error-patterns.json" ]; then
      local count
      count=$(node -p "JSON.parse(require('fs').readFileSync('$KB_DIR/error-patterns.json','utf-8')).length" 2>/dev/null || echo "0")
      if [ "$count" -gt 0 ]; then
        {
          echo ""
          echo "## Known Error Patterns (avoid these)"
          node -e "
            const p = JSON.parse(require('fs').readFileSync('$KB_DIR/error-patterns.json','utf-8'));
            p.forEach(e => console.log('- [' + e.feature_id + '] ' + e.phase + ': ' + e.error));
          " 2>/dev/null || true
        } >> "$context_file"
      fi
    fi
    return
  fi

  local rule_count
  rule_count=$(node -p "JSON.parse(require('fs').readFileSync('$KB_RULES_FILE','utf-8')).rules.length" 2>/dev/null || echo "0")

  if [ "$rule_count" -gt 0 ]; then
    {
      echo ""
      echo "## Behavioral Rules (derived from past errors)"
      echo "These rules are generated from recurring error patterns. Follow them to avoid known failure modes."
      echo ""
      node -e "
        const rules = JSON.parse(require('fs').readFileSync('$KB_RULES_FILE','utf-8')).rules.filter(r => !r.disabled);
        rules.forEach((r, i) => {
          console.log((i+1) + '. **' + r.trigger.category + '** (seen ' + r.total_frequency + 'x): ' + r.instruction);
        });
      " 2>/dev/null || true
    } >> "$context_file"
  fi

  # Also include raw patterns for reference (compact form)
  if [ -f "$KB_FILE" ]; then
    local pattern_count
    pattern_count=$(node -p "JSON.parse(require('fs').readFileSync('$KB_FILE','utf-8')).patterns.length" 2>/dev/null || echo "0")
    if [ "$pattern_count" -gt 0 ]; then
      {
        echo ""
        echo "## Error Pattern History"
        node -e "
          const kb = JSON.parse(require('fs').readFileSync('$KB_FILE','utf-8'));
          kb.patterns.slice(-5).forEach(p => {
            console.log('- [' + p.category + '] ' + p.signature.substring(0, 80) + ' (x' + p.frequency + ')');
          });
        " 2>/dev/null || true
      } >> "$context_file"
    fi
  fi
}

kb_get_rules() {
  if [ -f "$KB_RULES_FILE" ]; then
    cat "$KB_RULES_FILE"
  else
    echo '{"rules":[]}'
  fi
}

# ── Skill-mode functions (Phase F) ──────────────────────────────
# Used by /kb-rules skill for interactive rule management.

kb_toggle_rule() {
  local rule_id="$1"

  [ ! -f "$KB_RULES_FILE" ] && echo "No rules file" && return 1

  node -e "
    const fs = require('fs');
    const data = JSON.parse(fs.readFileSync('$KB_RULES_FILE', 'utf-8'));
    const rule = data.rules.find(r => r.id === '$rule_id');
    if (!rule) { console.error('Rule not found: $rule_id'); process.exit(1); }
    if (rule.disabled) {
      delete rule.disabled;
      console.log('enabled');
    } else {
      rule.disabled = true;
      console.log('disabled');
    }
    fs.writeFileSync('$KB_RULES_FILE', JSON.stringify(data, null, 2));
  " 2>/dev/null
}

kb_edit_rule() {
  local rule_id="$1"
  local new_instruction="$2"

  [ ! -f "$KB_RULES_FILE" ] && echo "No rules file" && return 1

  node -e "
    const fs = require('fs');
    const data = JSON.parse(fs.readFileSync('$KB_RULES_FILE', 'utf-8'));
    const rule = data.rules.find(r => r.id === '$rule_id');
    if (!rule) { console.error('Rule not found: $rule_id'); process.exit(1); }
    const old = rule.instruction;
    rule.instruction = $(printf '%s' "$new_instruction" | node -p "JSON.stringify(require('fs').readFileSync('/dev/stdin','utf-8').trim())");
    fs.writeFileSync('$KB_RULES_FILE', JSON.stringify(data, null, 2));
    console.log(JSON.stringify({ old, new: rule.instruction }));
  " 2>/dev/null
}

kb_prune_rules() {
  local min_frequency="${1:-2}"
  local max_age_days="${2:-30}"

  [ ! -f "$KB_RULES_FILE" ] && echo '{"pruned":0,"remaining":0}' && return

  node -e "
    const fs = require('fs');
    const data = JSON.parse(fs.readFileSync('$KB_RULES_FILE', 'utf-8'));
    const kb = fs.existsSync('$KB_FILE') ? JSON.parse(fs.readFileSync('$KB_FILE', 'utf-8')) : { patterns: [] };
    const cutoff = Date.now() - ($max_age_days * 86400000);
    const before = data.rules.length;

    data.rules = data.rules.filter(rule => {
      if (rule.total_frequency < $min_frequency) return false;
      const sourcePatterns = kb.patterns.filter(p => (rule.source_patterns || []).includes(p.id));
      const allStale = sourcePatterns.length > 0 && sourcePatterns.every(p => new Date(p.last_seen).getTime() < cutoff);
      if (allStale && rule.disabled) return false;
      return true;
    });

    fs.writeFileSync('$KB_RULES_FILE', JSON.stringify(data, null, 2));
    console.log(JSON.stringify({ pruned: before - data.rules.length, remaining: data.rules.length }));
  " 2>/dev/null
}

kb_export_rules() {
  local format="${1:-md}"

  [ ! -f "$KB_RULES_FILE" ] && echo "No rules to export" && return

  if [ "$format" = "json" ]; then
    node -e "
      const fs = require('fs');
      const data = JSON.parse(fs.readFileSync('$KB_RULES_FILE', 'utf-8'));
      console.log(JSON.stringify({
        exported_at: new Date().toISOString(),
        rules: data.rules.map(r => ({
          id: r.id,
          category: r.trigger.category,
          instruction: r.instruction,
          total_frequency: r.total_frequency,
          disabled: !!r.disabled,
          source_patterns: r.source_patterns || []
        }))
      }, null, 2));
    " 2>/dev/null
  else
    node -e "
      const fs = require('fs');
      const data = JSON.parse(fs.readFileSync('$KB_RULES_FILE', 'utf-8'));
      console.log('## Behavioral Rules (auto-derived from orchestrator error patterns)');
      console.log('');
      data.rules.forEach((r, i) => {
        const status = r.disabled ? ', disabled' : '';
        console.log((i + 1) + '. **' + r.trigger.category + '** (seen ' + r.total_frequency + 'x' + status + '): ' + r.instruction);
      });
      console.log('');
      console.log('_Generated by feature-marker knowledge base. Last derived: ' + (data.derived_at || 'unknown') + '_');
    " 2>/dev/null
  fi
}
