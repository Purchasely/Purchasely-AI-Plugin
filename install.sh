#!/bin/sh
# ──────────────────────────────────────────────────────────────────────
# Purchasely AI Plugin — Installer
# Detects AI coding tools and installs the appropriate configuration.
# POSIX-compatible (no bash-isms).
# ──────────────────────────────────────────────────────────────────────
set -e

# ── Version ──────────────────────────────────────────────────────────
VERSION="1.0.0"

# ── Resolve script directory (where configs/ lives) ─────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Color support ────────────────────────────────────────────────────
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  BOLD="$(tput bold)"
  RESET="$(tput sgr0)"
  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"
  MAGENTA="$(tput setaf 5)"
  CYAN="$(tput setaf 6)"
else
  BOLD="" RESET="" RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN=""
fi

# ── Helpers ──────────────────────────────────────────────────────────
info()    { printf "%s[info]%s  %s\n" "$CYAN"   "$RESET" "$1"; }
ok()      { printf "%s[ok]%s    %s\n" "$GREEN"  "$RESET" "$1"; }
warn()    { printf "%s[warn]%s  %s\n" "$YELLOW" "$RESET" "$1"; }
err()     { printf "%s[err]%s   %s\n" "$RED"    "$RESET" "$1" >&2; }
step()    { printf "\n%s==>%s %s%s%s\n" "$BLUE" "$RESET" "$BOLD" "$1" "$RESET"; }

confirm() {
  if [ "$ALL" = "1" ]; then
    return 0
  fi
  printf "%s[?]%s   %s [Y/n] " "$MAGENTA" "$RESET" "$1"
  read -r answer </dev/tty
  case "$answer" in
    [nN]*) return 1 ;;
    *)     return 0 ;;
  esac
}

# ── Banner ───────────────────────────────────────────────────────────
banner() {
  printf "%s" "$MAGENTA"
  cat <<'LOGO'

  ____                _                    _
 |  _ \ _   _ _ __ ___| |__   __ _ ___  ___| |_   _
 | |_) | | | | '__/ __| '_ \ / _` / __|/ _ \ | | | |
 |  __/| |_| | | | (__| | | | (_| \__ \  __/ | |_| |
 |_|    \__,_|_|  \___|_| |_|\__,_|___/\___|_|\__, |
                                               |___/
LOGO
  printf "%s" "$RESET"
  printf "  %sAI Plugin Installer%s v%s\n\n" "$BOLD" "$RESET" "$VERSION"
}

# ── Usage ────────────────────────────────────────────────────────────
usage() {
  banner
  cat <<EOF
${BOLD}USAGE${RESET}
  install.sh [options]

${BOLD}OPTIONS${RESET}
  --all               Install for all detected tools without prompting
  --tool <name>       Install only for a specific tool
                      (claude, cursor, copilot, windsurf, codex, gemini, mistral)
  --project <path>    Target project directory (default: current directory)
  --help              Show this help message

${BOLD}EXAMPLES${RESET}
  ./install.sh                          # Interactive — detect & prompt
  ./install.sh --all                    # Install everything detected
  ./install.sh --tool cursor            # Install Cursor config only
  ./install.sh --project ~/my-app       # Target a specific project

EOF
  exit 0
}

# ── Parse arguments ──────────────────────────────────────────────────
ALL=0
TOOL=""
PROJECT_DIR="$(pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --all)
      ALL=1
      shift
      ;;
    --tool)
      [ -z "${2:-}" ] && { err "--tool requires a value"; exit 1; }
      TOOL="$2"
      shift 2
      ;;
    --project)
      [ -z "${2:-}" ] && { err "--project requires a path"; exit 1; }
      PROJECT_DIR="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      err "Unknown option: $1"
      printf "Run with --help for usage.\n"
      exit 1
      ;;
  esac
done

# Validate project directory
if [ ! -d "$PROJECT_DIR" ]; then
  err "Project directory does not exist: $PROJECT_DIR"
  exit 1
fi
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# Validate --tool value
if [ -n "$TOOL" ]; then
  case "$TOOL" in
    claude|cursor|copilot|windsurf|codex|gemini|mistral) ;;
    *)
      err "Unknown tool: $TOOL"
      err "Valid tools: claude, cursor, copilot, windsurf, codex, gemini, mistral"
      exit 1
      ;;
  esac
fi

# ── Detection functions ──────────────────────────────────────────────
detect_claude() {
  command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ]
}

detect_cursor() {
  [ -d "$PROJECT_DIR/.cursor" ] || command -v cursor >/dev/null 2>&1
}

detect_copilot() {
  [ -d "$PROJECT_DIR/.github" ]
}

detect_windsurf() {
  command -v windsurf >/dev/null 2>&1 || [ -f "$HOME/.windsurf/config.json" ] || [ -d "$HOME/.windsurf" ]
}

detect_codex() {
  command -v codex >/dev/null 2>&1
}

detect_gemini() {
  command -v gemini >/dev/null 2>&1
}

detect_mistral() {
  # Mistral's coding agent CLI is `vibe`. It reads the cross-vendor AGENTS.md
  # standard (same format as Codex). Detect by presence of the `vibe` binary
  # or an existing AGENTS.md file in the project.
  command -v vibe >/dev/null 2>&1 \
    || [ -f "$PROJECT_DIR/AGENTS.md" ]
}

# ── Install functions ────────────────────────────────────────────────
installed_count=0
skipped_count=0
failed_count=0
summary=""

add_summary() {
  summary="${summary}  ${GREEN}+${RESET} $1\n"
}

add_skip() {
  summary="${summary}  ${YELLOW}-${RESET} $1 (skipped)\n"
}

install_claude() {
  step "Claude Code"
  if ! detect_claude; then
    info "Claude Code not detected — skipping"
    return
  fi
  ok "Detected Claude Code"

  if confirm "Install Purchasely plugin for Claude Code?"; then
    printf "\n"
    info "Preferred: Run these commands inside Claude Code:"
    printf "\n    %s%s/plugin marketplace add Purchasely/AI-Plugin%s\n" "$BOLD" "$CYAN" "$RESET"
    printf "    %s%s/plugin install purchasely@Purchasely%s\n\n" "$BOLD" "$CYAN" "$RESET"
    info "Alternatively, you can manually copy configs from:"
    info "  ${SCRIPT_DIR}/configs/claude/"
    info "to your project's .claude/ directory."
    add_summary "Claude Code — plugin command printed"
    installed_count=$((installed_count + 1))
  else
    add_skip "Claude Code"
    skipped_count=$((skipped_count + 1))
  fi
}

install_cursor() {
  step "Cursor"
  if ! detect_cursor; then
    info "Cursor not detected — skipping"
    return
  fi
  ok "Detected Cursor"

  src="$SCRIPT_DIR/configs/cursor/purchasely.mdc"
  dest="$PROJECT_DIR/.cursor/rules/purchasely.mdc"

  if [ ! -f "$src" ]; then
    err "Source config not found: $src"
    failed_count=$((failed_count + 1))
    return
  fi

  if confirm "Install Cursor rules to $dest?"; then
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    ok "Installed: $dest"
    add_summary "Cursor — $dest"
    installed_count=$((installed_count + 1))
  else
    add_skip "Cursor"
    skipped_count=$((skipped_count + 1))
  fi
}

install_copilot() {
  step "GitHub Copilot"
  if ! detect_copilot; then
    info "GitHub Copilot (.github/) not detected — skipping"
    return
  fi
  ok "Detected .github/ directory"

  src="$SCRIPT_DIR/configs/copilot/copilot-instructions.md"
  dest="$PROJECT_DIR/.github/copilot-instructions.md"

  if [ ! -f "$src" ]; then
    err "Source config not found: $src"
    failed_count=$((failed_count + 1))
    return
  fi

  if confirm "Install Copilot instructions to $dest?"; then
    mkdir -p "$(dirname "$dest")"
    if [ -f "$dest" ]; then
      warn "File already exists — appending with separator"
      printf "\n\n---\n<!-- Purchasely AI Plugin — auto-appended by install.sh -->\n\n" >> "$dest"
      cat "$src" >> "$dest"
      ok "Appended to: $dest"
    else
      cp "$src" "$dest"
      ok "Created: $dest"
    fi
    add_summary "GitHub Copilot — $dest"
    installed_count=$((installed_count + 1))
  else
    add_skip "GitHub Copilot"
    skipped_count=$((skipped_count + 1))
  fi
}

install_windsurf() {
  step "Windsurf"
  if ! detect_windsurf; then
    info "Windsurf not detected — skipping"
    return
  fi
  ok "Detected Windsurf"

  src="$SCRIPT_DIR/configs/windsurf/.windsurfrules"
  dest="$PROJECT_DIR/.windsurfrules"

  if [ ! -f "$src" ]; then
    err "Source config not found: $src"
    failed_count=$((failed_count + 1))
    return
  fi

  if [ -f "$dest" ]; then
    warn "File already exists: $dest"
    if ! confirm "Overwrite existing .windsurfrules?"; then
      add_skip "Windsurf (file exists)"
      skipped_count=$((skipped_count + 1))
      return
    fi
  elif ! confirm "Install Windsurf rules to $dest?"; then
    add_skip "Windsurf"
    skipped_count=$((skipped_count + 1))
    return
  fi

  cp "$src" "$dest"
  ok "Installed: $dest"
  add_summary "Windsurf — $dest"
  installed_count=$((installed_count + 1))
}

install_codex() {
  step "Codex"
  if ! detect_codex; then
    info "Codex not detected — skipping"
    return
  fi
  ok "Detected Codex"

  src="$SCRIPT_DIR/configs/codex/AGENTS.md"
  dest="$PROJECT_DIR/AGENTS.md"

  if [ ! -f "$src" ]; then
    err "Source config not found: $src"
    failed_count=$((failed_count + 1))
    return
  fi

  if [ -f "$dest" ]; then
    warn "File already exists: $dest"
    if ! confirm "Overwrite existing AGENTS.md?"; then
      add_skip "Codex (file exists)"
      skipped_count=$((skipped_count + 1))
      return
    fi
  elif ! confirm "Install Codex agent config to $dest?"; then
    add_skip "Codex"
    skipped_count=$((skipped_count + 1))
    return
  fi

  cp "$src" "$dest"
  ok "Installed: $dest"
  add_summary "Codex — $dest"
  installed_count=$((installed_count + 1))
}

install_mistral() {
  step "Mistral"
  if ! detect_mistral; then
    info "Mistral not detected — skipping"
    return
  fi
  ok "Detected Mistral"

  src="$SCRIPT_DIR/configs/mistral/AGENTS.md"
  dest="$PROJECT_DIR/AGENTS.md"

  if [ ! -f "$src" ]; then
    err "Source config not found: $src"
    failed_count=$((failed_count + 1))
    return
  fi

  if [ -f "$dest" ]; then
    warn "AGENTS.md already exists: $dest"
    info "Mistral reads the same AGENTS.md as Codex — no action needed if Codex was already installed."
    add_skip "Mistral (AGENTS.md already present)"
    skipped_count=$((skipped_count + 1))
    return
  elif ! confirm "Install Mistral AGENTS.md to $dest?"; then
    add_skip "Mistral"
    skipped_count=$((skipped_count + 1))
    return
  fi

  cp "$src" "$dest"
  ok "Installed: $dest"
  add_summary "Mistral — $dest"
  installed_count=$((installed_count + 1))
}

install_gemini() {
  step "Gemini"
  if ! detect_gemini; then
    info "Gemini not detected — skipping"
    return
  fi
  ok "Detected Gemini"

  src="$SCRIPT_DIR/configs/gemini/GEMINI.md"
  dest="$PROJECT_DIR/GEMINI.md"

  if [ ! -f "$src" ]; then
    err "Source config not found: $src"
    failed_count=$((failed_count + 1))
    return
  fi

  if [ -f "$dest" ]; then
    warn "File already exists: $dest"
    if ! confirm "Overwrite existing GEMINI.md?"; then
      add_skip "Gemini (file exists)"
      skipped_count=$((skipped_count + 1))
      return
    fi
  elif ! confirm "Install Gemini config to $dest?"; then
    add_skip "Gemini"
    skipped_count=$((skipped_count + 1))
    return
  fi

  cp "$src" "$dest"
  ok "Installed: $dest"
  add_summary "Gemini — $dest"
  installed_count=$((installed_count + 1))
}

# ── Main ─────────────────────────────────────────────────────────────
banner
info "Project directory: ${BOLD}${PROJECT_DIR}${RESET}"
info "Config source:     ${BOLD}${SCRIPT_DIR}${RESET}"

if [ -n "$TOOL" ]; then
  # Single tool mode
  info "Installing for: ${BOLD}${TOOL}${RESET}"
  case "$TOOL" in
    claude)   install_claude   ;;
    cursor)   install_cursor   ;;
    copilot)  install_copilot  ;;
    windsurf) install_windsurf ;;
    codex)    install_codex    ;;
    gemini)   install_gemini   ;;
    mistral)  install_mistral  ;;
  esac
else
  # Detect all tools
  step "Detecting AI tools..."
  detected=""
  detect_claude   && detected="${detected} claude"   && ok "Claude Code"
  detect_cursor   && detected="${detected} cursor"   && ok "Cursor"
  detect_copilot  && detected="${detected} copilot"  && ok "GitHub Copilot"
  detect_windsurf && detected="${detected} windsurf" && ok "Windsurf"
  detect_codex    && detected="${detected} codex"    && ok "Codex"
  detect_gemini   && detected="${detected} gemini"   && ok "Gemini"
  detect_mistral  && detected="${detected} mistral"  && ok "Mistral"

  if [ -z "$detected" ]; then
    warn "No AI coding tools detected."
    info "You can install manually with: ./install.sh --tool <name>"
    exit 0
  fi

  # Install for each detected tool
  for tool in $detected; do
    case "$tool" in
      claude)   install_claude   ;;
      cursor)   install_cursor   ;;
      copilot)  install_copilot  ;;
      windsurf) install_windsurf ;;
      codex)    install_codex    ;;
      gemini)   install_gemini   ;;
    esac
  done
fi

# ── Summary ──────────────────────────────────────────────────────────
printf "\n"
step "Summary"
if [ -n "$summary" ]; then
  printf "%b" "$summary"
fi
printf "\n"
info "${GREEN}${installed_count}${RESET} installed, ${YELLOW}${skipped_count}${RESET} skipped, ${RED}${failed_count}${RESET} failed"

if [ "$installed_count" -gt 0 ]; then
  printf "\n%sDone!%s Happy coding with Purchasely.\n\n" "$GREEN$BOLD" "$RESET"
else
  printf "\nNothing was installed. Run with %s--help%s for options.\n\n" "$BOLD" "$RESET"
fi
