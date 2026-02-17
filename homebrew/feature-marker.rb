# typed: false
# frozen_string_literal: true

# Homebrew formula for feature-marker
# Install: brew install viniciuscarvalho/tap/feature-marker
class FeatureMarker < Formula
  desc "AI-powered feature development workflow automation for Claude Code"
  homepage "https://github.com/Viniciuscarvalho/Feature-marker"
  url "https://github.com/Viniciuscarvalho/Feature-marker/archive/refs/heads/main.tar.gz"
  sha256 "5d172be26ccf6f5c68f03a7fb8eadb1c0b602687f2f77f4244362299ac0acd83"
  version "5.1.0"
  license "MIT"
  head "https://github.com/Viniciuscarvalho/Feature-marker.git", branch: "main"

  # TUI requires Rust
  depends_on "rust" => :build if build.with? "tui"

  option "with-tui", "Build and install the TUI application"

  def install
    # Install skill files
    skill_dir = prefix/"skill"
    skill_dir.install Dir["feature-marker-dist/feature-marker/*"]

    # Install agent file
    agents_dir = prefix/"agents"
    agents_dir.mkpath
    agents_dir.install "feature-marker-dist/agents/feature-marker.md"

    # Create wrapper script
    (bin/"feature-marker-install").write <<~EOS
      #!/usr/bin/env bash
      set -euo pipefail

      SKILL_SRC="#{prefix}/skill"
      AGENT_SRC="#{prefix}/agents/feature-marker.md"
      SKILL_DST="${HOME}/.claude/skills/feature-marker"
      AGENT_DST="${HOME}/.claude/agents/feature-marker.md"

      echo "Installing feature-marker to ~/.claude..."

      # Create directories
      mkdir -p "${SKILL_DST}"
      mkdir -p "$(dirname "${AGENT_DST}")"

      # Copy files
      if command -v rsync &> /dev/null; then
        rsync -a --delete "${SKILL_SRC}/" "${SKILL_DST}/"
      else
        rm -rf "${SKILL_DST}"
        cp -R "${SKILL_SRC}" "${SKILL_DST}"
      fi
      cp -f "${AGENT_SRC}" "${AGENT_DST}"

      # Set permissions
      chmod +x "${SKILL_DST}/feature-marker.sh" 2>/dev/null || true
      chmod +x "${SKILL_DST}/lib/"*.sh 2>/dev/null || true

      echo ""
      echo "✓ feature-marker installed successfully!"
      echo ""
      echo "Usage in Claude Code:"
      echo "  /feature-marker <feature-slug>"
      echo ""
      echo "Example:"
      echo "  /feature-marker prd-user-authentication"
    EOS

    # Create uninstall script
    (bin/"feature-marker-uninstall").write <<~EOS
      #!/usr/bin/env bash
      set -euo pipefail

      SKILL_DST="${HOME}/.claude/skills/feature-marker"
      AGENT_DST="${HOME}/.claude/agents/feature-marker.md"

      echo "Uninstalling feature-marker from ~/.claude..."

      if [[ -d "${SKILL_DST}" ]]; then
        rm -rf "${SKILL_DST}"
        echo "✓ Skill removed"
      fi

      if [[ -f "${AGENT_DST}" ]]; then
        rm -f "${AGENT_DST}"
        echo "✓ Agent removed"
      fi

      echo ""
      echo "feature-marker has been uninstalled."
    EOS

    # Build TUI if requested
    if build.with? "tui"
      cd "feature-marker-tui" do
        system "cargo", "build", "--release"
        bin.install "target/release/feature-marker-tui"
      end
    end
  end

  def post_install
    ohai "Run 'feature-marker-install' to install the skill to ~/.claude"
  end

  def caveats
    <<~EOS
      To complete installation, run:
        feature-marker-install

      This will install the feature-marker skill to ~/.claude

      Prerequisites:
        Make sure you have these commands in ~/.claude/commands/:
        - create-prd.md
        - generate-spec.md
        - generate-tasks.md

        Get these from: https://github.com/Viniciuscarvalho/mindkit

      Usage in Claude Code:
        /feature-marker <feature-slug>

      Example:
        /feature-marker prd-user-authentication
    EOS
  end

  test do
    assert_match "feature-marker", shell_output("#{bin}/feature-marker-install --help 2>&1 || true")
  end
end
