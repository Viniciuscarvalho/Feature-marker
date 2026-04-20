# typed: false
# frozen_string_literal: true

# Homebrew formula for feature-marker
# Install: brew install viniciuscarvalho/tap/feature-marker
class FeatureMarker < Formula
  desc "AI-powered feature development automation — skill + orchestrator"
  homepage "https://github.com/Viniciuscarvalho/Feature-marker"
  url "https://github.com/Viniciuscarvalho/Feature-marker/archive/refs/tags/v7.5.0.tar.gz"
  sha256 "54ff0cc2294c0d7dbfa2e844cf591cf38513ae23259a27dbcf56a0abfcc4eebd"
  version "7.5.0"
  license "MIT"
  head "https://github.com/Viniciuscarvalho/Feature-marker.git", branch: "main"

  depends_on "jq"
  depends_on "node"

  def install
    # ── Existing skill installation ──────────────────
    skill_dir = prefix/"skill"
    skill_dir.install Dir["feature-marker-dist/feature-marker/*"]

    agents_dir = prefix/"agents"
    agents_dir.mkpath
    agents_dir.install "feature-marker-dist/agents/feature-marker.md"

    # Install existing bin scripts
    (bin/"feature-marker-install").write <<~EOS
      #!/usr/bin/env bash
      set -euo pipefail

      SKILL_SRC="#{prefix}/skill"
      AGENT_SRC="#{prefix}/agents/feature-marker.md"
      SKILL_DST="${HOME}/.claude/skills/feature-marker"
      AGENT_DST="${HOME}/.claude/agents/feature-marker.md"

      echo "Installing feature-marker to ~/.claude..."
      mkdir -p "${SKILL_DST}" "$(dirname "${AGENT_DST}")"

      if command -v rsync &> /dev/null; then
        rsync -a --delete "${SKILL_SRC}/" "${SKILL_DST}/"
      else
        rm -rf "${SKILL_DST}"
        cp -R "${SKILL_SRC}" "${SKILL_DST}"
      fi
      cp -f "${AGENT_SRC}" "${AGENT_DST}"

      chmod +x "${SKILL_DST}/feature-marker.sh" 2>/dev/null || true
      chmod +x "${SKILL_DST}/lib/"*.sh 2>/dev/null || true

      echo "✓ feature-marker skill installed to ~/.claude"
    EOS

    (bin/"feature-marker-uninstall").write <<~EOS
      #!/usr/bin/env bash
      set -euo pipefail

      rm -rf "${HOME}/.claude/skills/feature-marker"
      rm -f "${HOME}/.claude/agents/feature-marker.md"
      echo "✓ feature-marker uninstalled from ~/.claude"
    EOS

    # ── Orchestrator installation (new) ──────────────
    # Install orchestrator scripts to libexec (not in PATH)
    libexec_orch = libexec/"orchestrator"
    libexec_orch.install "scripts/orchestrate.sh"
    libexec_orch.install Dir["scripts/lib"]
    libexec_orch.install Dir["scripts/adapters"]
    libexec_orch.install "scripts/agent-discovery.sh"
    libexec_orch.install "scripts/route-tasks.sh"
    libexec_orch.install "scripts/parse-config.js"
    libexec_orch.install "scripts/status-writer.js"
    libexec_orch.install "scripts/environment-discovery.sh"
    libexec_orch.install "scripts/feedback-collector.sh"
    libexec_orch.install Dir["scripts/templates"]

    # Make all scripts executable
    (libexec_orch).glob("**/*.sh").each { |f| f.chmod 0755 }

    # Install wrapper to bin (this goes in PATH)
    (bin/"feature-marker-orchestrate").write <<~EOS
      #!/bin/bash
      set -euo pipefail
      WRAPPER_PATH="$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")"
      BIN_DIR="$(cd "$(dirname "$WRAPPER_PATH")" && pwd)"
      LIBEXEC_DIR="$(cd "$BIN_DIR/../libexec/orchestrator" 2>/dev/null && pwd)"
      if [ -z "$LIBEXEC_DIR" ] || [ ! -f "$LIBEXEC_DIR/orchestrate.sh" ]; then
        echo "x Cannot find orchestrator scripts." >&2
        exit 1
      fi
      export ORCHESTRATOR_HOME="$LIBEXEC_DIR"
      exec bash "$LIBEXEC_DIR/orchestrate.sh" "$@"
    EOS
  end

  def caveats
    <<~EOS
      Feature-marker skill installed to:
        #{prefix}/skill/

      To complete skill setup, run:
        feature-marker-install

      Orchestrator available as:
        feature-marker-orchestrate init      # scaffold config in your project
        feature-marker-orchestrate           # run the loop
        feature-marker-orchestrate status    # check state
        feature-marker-orchestrate --help    # see all options

      Dependencies (installed automatically):
        jq   — JSON processing
        node — JavaScript runtime
    EOS
  end

  test do
    # Test skill files exist
    assert_predicate prefix/"skill/SKILL.md", :exist?

    # Test orchestrator wrapper works
    assert_match "Usage:", shell_output("#{bin}/feature-marker-orchestrate --help")

    # Test init creates config in a temp dir
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        system "git", "init"
        system "#{bin}/feature-marker-orchestrate", "init"
        assert_predicate Pathname(dir)/".orchestrator/config.yaml", :exist?
        assert_predicate Pathname(dir)/".env.example", :exist?
      end
    end
  end
end
