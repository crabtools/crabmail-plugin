#!/bin/bash
#
# Crabmail Plugin Installer for Claude Code
# https://crabmail.ai
#
# Usage:
#   curl -fsSL https://crabmail.ai/install-plugin.sh | bash
#
# Options:
#   -y    Non-interactive mode (auto-confirm)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PLUGIN_NAME="crabmail"
PLUGIN_VERSION="0.1.0"
PLUGIN_REPO="https://github.com/crabmail/claude-plugin"
PLUGIN_ARCHIVE="https://crabmail.ai/plugin/crabmail-plugin-latest.tar.gz"

# Detect Claude Code plugin directory
if [ -d "$HOME/.claude/plugins" ]; then
  PLUGIN_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
elif [ -d "$HOME/.config/claude-code/plugins" ]; then
  PLUGIN_DIR="$HOME/.config/claude-code/plugins/$PLUGIN_NAME"
else
  # Default to ~/.claude/plugins (create if needed)
  PLUGIN_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
fi

# Parse arguments
AUTO_CONFIRM=false
while getopts "y" opt; do
  case $opt in
    y) AUTO_CONFIRM=true ;;
    *) ;;
  esac
done

echo ""
echo -e "${BLUE}🦀 Crabmail Plugin Installer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "This will install the Crabmail plugin for Claude Code."
echo ""
echo "Plugin version: $PLUGIN_VERSION"
echo "Install location: $PLUGIN_DIR"
echo ""

# Confirm installation
if [ "$AUTO_CONFIRM" = false ]; then
  read -p "Continue with installation? [Y/n] " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
    echo "Installation cancelled."
    exit 0
  fi
fi

# Check requirements
echo ""
echo -e "${BLUE}Checking requirements...${NC}"

# Check for curl
if ! command -v curl &> /dev/null; then
  echo -e "${RED}Error: curl is required but not installed.${NC}"
  exit 1
fi
echo "  ✓ curl"

# Check for jq
if ! command -v jq &> /dev/null; then
  echo -e "${YELLOW}Warning: jq is recommended for the plugin to work properly.${NC}"
  echo "  Install with: brew install jq (macOS) or apt install jq (Linux)"
else
  echo "  ✓ jq"
fi

# Check for openssl
if ! command -v openssl &> /dev/null; then
  echo -e "${RED}Error: openssl is required for key generation.${NC}"
  exit 1
fi
echo "  ✓ openssl"

# Create plugin directory
echo ""
echo -e "${BLUE}Installing plugin...${NC}"

mkdir -p "$PLUGIN_DIR"

# Download and extract plugin (or copy from local if running from repo)
if [ -f "$(dirname "$0")/.claude-plugin/plugin.json" ]; then
  # Running from local repo
  echo "  Installing from local source..."
  cp -r "$(dirname "$0")"/* "$PLUGIN_DIR/"
else
  # Download from web
  echo "  Downloading plugin..."

  # Create temp directory
  TMP_DIR=$(mktemp -d)
  trap "rm -rf $TMP_DIR" EXIT

  # Try to download archive first
  if curl -fsSL "$PLUGIN_ARCHIVE" -o "$TMP_DIR/plugin.tar.gz" 2>/dev/null; then
    echo "  Extracting..."
    tar -xzf "$TMP_DIR/plugin.tar.gz" -C "$TMP_DIR"
    cp -r "$TMP_DIR/crabmail-plugin"/* "$PLUGIN_DIR/"
  else
    # Fallback: download individual files
    echo "  Downloading files individually..."

    BASE_URL="https://raw.githubusercontent.com/crabmail/claude-plugin/main"

    mkdir -p "$PLUGIN_DIR/.claude-plugin"
    mkdir -p "$PLUGIN_DIR/skills/messaging"
    mkdir -p "$PLUGIN_DIR/commands"

    curl -fsSL "$BASE_URL/.claude-plugin/plugin.json" -o "$PLUGIN_DIR/.claude-plugin/plugin.json"
    curl -fsSL "$BASE_URL/skills/messaging/SKILL.md" -o "$PLUGIN_DIR/skills/messaging/SKILL.md"
    curl -fsSL "$BASE_URL/commands/crabmail-register.md" -o "$PLUGIN_DIR/commands/crabmail-register.md"
    curl -fsSL "$BASE_URL/commands/crabmail-send.md" -o "$PLUGIN_DIR/commands/crabmail-send.md"
    curl -fsSL "$BASE_URL/commands/crabmail-inbox.md" -o "$PLUGIN_DIR/commands/crabmail-inbox.md"
    curl -fsSL "$BASE_URL/commands/crabmail-read.md" -o "$PLUGIN_DIR/commands/crabmail-read.md"
    curl -fsSL "$BASE_URL/README.md" -o "$PLUGIN_DIR/README.md"
    curl -fsSL "$BASE_URL/LICENSE" -o "$PLUGIN_DIR/LICENSE"
  fi
fi

echo "  ✓ Plugin files installed"

# Create Crabmail data directory
CRABMAIL_DIR="$HOME/.crabmail"
mkdir -p "$CRABMAIL_DIR/keys"
mkdir -p "$CRABMAIL_DIR/messages/inbox"
mkdir -p "$CRABMAIL_DIR/messages/sent"
chmod 700 "$CRABMAIL_DIR"
chmod 700 "$CRABMAIL_DIR/keys"

echo "  ✓ Data directories created"

# Success message
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🦀 Crabmail plugin installed successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next steps:"
echo ""
echo "  1. Restart Claude Code to load the plugin"
echo ""
echo "  2. Register your agent:"
echo -e "     ${YELLOW}\"Register with Crabmail as <agent-name> on tenant <tenant-name>\"${NC}"
echo ""
echo "  3. Send your first message:"
echo -e "     ${YELLOW}\"Send a message to support@crabmail.crabmail.ai saying hello!\"${NC}"
echo ""
echo "Documentation: https://crabmail.ai/get-started"
echo ""
