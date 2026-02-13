# Homebrew Installation for feature-marker

## Quick Install

```bash
# Add the tap
brew tap viniciuscarvalho/tap

# Install feature-marker
brew install feature-marker

# Complete installation to ~/.claude
feature-marker-install
```

## Options

```bash
# Install with TUI (requires Rust)
brew install feature-marker --with-tui
```

## Commands

| Command | Description |
|---------|-------------|
| `feature-marker-install` | Install skill to ~/.claude |
| `feature-marker-uninstall` | Remove skill from ~/.claude |
| `feature-marker-tui` | Launch TUI (if installed with --with-tui) |

## Creating Your Own Tap

If you want to create your own Homebrew tap:

1. Create a GitHub repository named `homebrew-tap`

2. Copy the formula:
   ```bash
   cp homebrew/feature-marker.rb /path/to/homebrew-tap/Formula/
   ```

3. Update the SHA256 hash in the formula after creating a release:
   ```bash
   # Download the release tarball
   curl -sL https://github.com/Viniciuscarvalho/Feature-marker/archive/refs/tags/v4.0.0.tar.gz | shasum -a 256
   ```

4. Push to your tap repository

5. Users can then install with:
   ```bash
   brew tap yourusername/tap
   brew install feature-marker
   ```

## Manual Installation

If you prefer not to use Homebrew:

```bash
git clone https://github.com/Viniciuscarvalho/Feature-marker.git
cd Feature-marker
./feature-marker-dist/feature-marker/install.sh
```

## Uninstall

```bash
# Remove the skill from ~/.claude
feature-marker-uninstall

# Uninstall from Homebrew
brew uninstall feature-marker
brew untap viniciuscarvalho/tap
```
