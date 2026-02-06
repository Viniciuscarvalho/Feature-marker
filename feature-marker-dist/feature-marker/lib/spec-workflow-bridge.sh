#!/usr/bin/env bash
# spec-workflow-bridge.sh - Bridge functions between spec-workflow and feature-marker
set -euo pipefail

# Get the spec-workflow output directory
get_spec_workflow_specs_dir() {
  local project_root="${1:-.}"
  local config_file="${project_root}/.claude/spec-workflow/config.yaml"

  # Default path
  local specs_dir="./specs"

  # Try to read from config if it exists
  if [[ -f "$config_file" ]]; then
    local configured_path
    configured_path=$(grep -E "^\s*specs:" "$config_file" | sed 's/.*specs:\s*"\?\([^"]*\)"\?.*/\1/' || echo "")
    if [[ -n "$configured_path" ]]; then
      specs_dir="$configured_path"
    fi
  fi

  echo "$specs_dir"
}

# Find the latest spec file for a given topic
find_latest_spec() {
  local specs_dir="$1"
  local topic="$2"

  # Look for spec files matching the topic
  local spec_file
  spec_file=$(find "$specs_dir" -name "*${topic}*-spec.md" -type f 2>/dev/null | sort -r | head -1)

  if [[ -n "$spec_file" ]] && [[ -f "$spec_file" ]]; then
    echo "$spec_file"
    return 0
  fi

  return 1
}

# Extract section content from a spec file
extract_spec_section() {
  local spec_file="$1"
  local section_name="$2"

  # Use awk to extract content between section headers
  awk -v section="$section_name" '
    /^## / {
      if (found) exit;
      if ($0 ~ section) found=1;
      next
    }
    found { print }
  ' "$spec_file"
}

# Convert spec-workflow spec to Feature-Marker PRD format
convert_spec_to_prd() {
  local spec_file="$1"
  local output_file="$2"
  local feature_name="$3"

  # Extract relevant sections from spec
  local title
  title=$(head -1 "$spec_file" | sed 's/^# //')

  local purpose
  purpose=$(extract_spec_section "$spec_file" "Purpose")

  local problem
  problem=$(extract_spec_section "$spec_file" "Problem Statement")

  local goals
  goals=$(extract_spec_section "$spec_file" "Goals")

  local non_goals
  non_goals=$(extract_spec_section "$spec_file" "Non-Goals")

  local requirements
  requirements=$(extract_spec_section "$spec_file" "Requirements")

  # Generate PRD
  cat > "$output_file" << EOF
# PRD: ${title}

## Overview

${purpose}

## Problem Statement

${problem}

## Goals

${goals}

## Non-Goals (Out of Scope)

${non_goals}

## Requirements

${requirements}

---

*Generated from spec-workflow spec: $(basename "$spec_file")*
*Date: $(date +%Y-%m-%d)*
EOF

  echo "✓ Generated PRD: $output_file"
}

# Convert spec-workflow spec to Feature-Marker TechSpec format
convert_spec_to_techspec() {
  local spec_file="$1"
  local output_file="$2"
  local feature_name="$3"

  # Extract relevant sections from spec
  local title
  title=$(head -1 "$spec_file" | sed 's/^# //')

  local tldr
  tldr=$(extract_spec_section "$spec_file" "TL;DR")

  local architecture
  architecture=$(extract_spec_section "$spec_file" "Architecture")

  local data_model
  data_model=$(extract_spec_section "$spec_file" "Data Model")

  local api_changes
  api_changes=$(extract_spec_section "$spec_file" "API Changes")

  local component_design
  component_design=$(extract_spec_section "$spec_file" "Component Design")

  local error_handling
  error_handling=$(extract_spec_section "$spec_file" "Error Handling")

  local risks
  risks=$(extract_spec_section "$spec_file" "Risks")

  # Generate TechSpec
  cat > "$output_file" << EOF
# Technical Specification: ${title}

## Summary

${tldr}

## Architecture & Design

${architecture}

### Data Model

${data_model}

### API Changes

${api_changes}

### Component Design

${component_design}

## Error Handling

${error_handling}

## Risks & Mitigations

${risks}

---

*Generated from spec-workflow spec: $(basename "$spec_file")*
*Date: $(date +%Y-%m-%d)*
EOF

  echo "✓ Generated TechSpec: $output_file"
}

# Convert spec-workflow Implementation Steps to Feature-Marker tasks.md format
convert_spec_to_tasks() {
  local spec_file="$1"
  local output_dir="$2"
  local feature_name="$3"

  local tasks_file="${output_dir}/tasks.md"

  # Extract Implementation Steps table
  local impl_steps
  impl_steps=$(extract_spec_section "$spec_file" "Implementation Steps")

  # Extract testing plan
  local testing
  testing=$(extract_spec_section "$spec_file" "Validation")

  # Extract acceptance criteria
  local acceptance
  acceptance=$(extract_spec_section "$spec_file" "Acceptance Criteria")

  # Generate tasks.md
  cat > "$tasks_file" << EOF
# Tasks: ${feature_name}

## Implementation Steps

${impl_steps}

## Testing Plan

${testing}

## Acceptance Criteria

${acceptance}

---

*Generated from spec-workflow spec: $(basename "$spec_file")*
*Date: $(date +%Y-%m-%d)*
EOF

  echo "✓ Generated tasks.md: $tasks_file"

  # Also generate individual task files if we can parse the table
  generate_individual_task_files "$spec_file" "$output_dir"
}

# Generate individual task files from Implementation Steps
generate_individual_task_files() {
  local spec_file="$1"
  local output_dir="$2"

  # Parse the Implementation Steps table and create individual task files
  local task_num=1
  local in_table=false

  while IFS= read -r line; do
    # Detect table start (after header row)
    if [[ "$line" =~ ^\|.*Step.*Task.*\| ]]; then
      in_table=true
      continue
    fi

    # Skip separator row
    if [[ "$line" =~ ^\|[-:]+\| ]]; then
      continue
    fi

    # Process table rows
    if [[ "$in_table" == true ]] && [[ "$line" =~ ^\| ]]; then
      # Extract columns: | Step | Task | Description | Depends On |
      local task_name
      local task_desc
      local depends_on

      task_name=$(echo "$line" | cut -d'|' -f3 | xargs)
      task_desc=$(echo "$line" | cut -d'|' -f4 | xargs)
      depends_on=$(echo "$line" | cut -d'|' -f5 | xargs)

      if [[ -n "$task_name" ]] && [[ "$task_name" != "Task" ]]; then
        local task_file="${output_dir}/${task_num}_task.md"

        cat > "$task_file" << EOF
# Task ${task_num}: ${task_name}

## Description

${task_desc}

## Dependencies

${depends_on:-None}

## Status

- [ ] Not started

## Notes

*Auto-generated from spec-workflow*
EOF

        ((task_num++))
      fi
    fi

    # Detect table end
    if [[ "$in_table" == true ]] && [[ ! "$line" =~ ^\| ]] && [[ -n "$line" ]]; then
      break
    fi
  done < "$spec_file"

  if [[ $task_num -gt 1 ]]; then
    echo "✓ Generated $((task_num - 1)) individual task files"
  fi
}

# Main conversion function: spec -> PRD + TechSpec + Tasks
convert_spec_to_feature_marker() {
  local spec_file="$1"
  local feature_name="$2"
  local output_base="${3:-./tasks}"

  local output_dir="${output_base}/prd-${feature_name}"

  # Validate spec file exists
  if [[ ! -f "$spec_file" ]]; then
    echo "Error: Spec file not found: $spec_file" >&2
    return 1
  fi

  # Create output directory
  mkdir -p "$output_dir"

  echo "Converting spec-workflow spec to Feature-Marker format..."
  echo "  Source: $spec_file"
  echo "  Output: $output_dir"
  echo ""

  # Convert to each format
  convert_spec_to_prd "$spec_file" "${output_dir}/prd.md" "$feature_name"
  convert_spec_to_techspec "$spec_file" "${output_dir}/techspec.md" "$feature_name"
  convert_spec_to_tasks "$spec_file" "$output_dir" "$feature_name"

  echo ""
  echo "✓ Conversion complete!"
  echo ""
  echo "Generated files:"
  ls -la "$output_dir"/*.md 2>/dev/null || true

  return 0
}

# Check if worktree was created by spec-workflow
get_spec_workflow_worktree() {
  local spec_file="$1"

  # Extract worktree from spec frontmatter
  local worktree
  worktree=$(grep -E "^worktree:" "$spec_file" 2>/dev/null | sed 's/worktree:\s*//' | xargs)

  if [[ -n "$worktree" ]]; then
    echo "$worktree"
    return 0
  fi

  return 1
}

# Check if branch was created by spec-workflow
get_spec_workflow_branch() {
  local spec_file="$1"

  # Extract branch from spec frontmatter
  local branch
  branch=$(grep -E "^branch:" "$spec_file" 2>/dev/null | sed 's/branch:\s*//' | xargs)

  if [[ -n "$branch" ]]; then
    echo "$branch"
    return 0
  fi

  return 1
}

# Export functions
export -f get_spec_workflow_specs_dir
export -f find_latest_spec
export -f extract_spec_section
export -f convert_spec_to_prd
export -f convert_spec_to_techspec
export -f convert_spec_to_tasks
export -f convert_spec_to_feature_marker
export -f get_spec_workflow_worktree
export -f get_spec_workflow_branch
