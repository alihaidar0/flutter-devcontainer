#!/usr/bin/env bash
# =============================================================
#  shell_setup.sh — Developer shell customisation
#
#  Runs as root during the Docker image build.
#  Installs Starship and writes Bash config for the developer user.
# =============================================================
set -euo pipefail

# ── Starship prompt ──────────────────────────────────────────
curl -fsSL https://starship.rs/install.sh | BIN_DIR=/usr/local/bin sh -s -- --yes

# ── Starship config ──────────────────────────────────────────
mkdir -p /home/developer/.config

cat > /home/developer/.config/starship.toml << 'STARSHIP'
format = """
[╭─](bold cyan)$directory$git_branch$git_status$dart$flutter_version$nodejs
[╰─❯](bold cyan) """

[directory]
style            = "bold blue"
truncation_length = 4
truncate_to_repo  = true

[git_branch]
symbol = " "
style  = "bold purple"

[git_status]
style = "bold red"

[dart]
symbol = " "
style  = "bold cyan"
format = "[$symbol$version]($style) "

[flutter_version]
symbol = " "
style  = "bold blue"
format = "[$symbol$version]($style) "

[nodejs]
symbol = " "
style  = "bold green"
format = "[$symbol$version]($style) "

[package]
disabled = true
STARSHIP

# ── Persistent shell history directory ───────────────────────
mkdir -p /home/developer/.shell_history

# ── Bash config ──────────────────────────────────────────────
cat >> /home/developer/.bashrc << 'BASHRC'

# ── Starship ─────────────────────────────────────────────────
eval "$(starship init bash)"

# ── Profile scripts ──────────────────────────────────────────
if [ -d /etc/profile.d ]; then
  for f in /etc/profile.d/*.sh; do
    [ -r "$f" ] && . "$f"
  done
  unset f
fi

# ── History ──────────────────────────────────────────────────
export HISTFILE=/home/developer/.shell_history/.bash_history
export HISTSIZE=50000
export HISTFILESIZE=50000
export HISTCONTROL=ignoredups:erasedups
shopt -s histappend

# ── Terminal ─────────────────────────────────────────────────
export TERM=xterm-256color
export CLICOLOR=1

# ── Flutter aliases ──────────────────────────────────────────
alias fl="flutter"
alias fget="flutter pub get"
alias fadd="flutter pub add"
alias frm="flutter pub remove"
alias fupgrade="flutter pub upgrade"
alias foutdated="flutter pub outdated"
alias frun="flutter run"
alias frunw="flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0"
alias frunc="flutter run -d chrome"
alias fbuild="flutter build"
alias fbuildapk="flutter build apk --release"
alias fbuildaab="flutter build appbundle --release"
alias fbuildweb="flutter build web --release"
alias fbuildlinux="flutter build linux --release"
alias ftest="flutter test"
alias ftestc="flutter test --coverage"
alias fanalyze="flutter analyze"
alias fformat="dart format ."
alias fformatcheck="dart format --set-exit-if-changed ."
alias fdoctor="flutter doctor -v"
alias fclean="flutter clean"
alias fcreate="flutter create"
alias fdevices="flutter devices"
alias fupgrade_sdk="flutter upgrade"

# ── Dart aliases ─────────────────────────────────────────────
alias dpub="dart pub"
alias dget="dart pub get"
alias daudit="dart pub audit"
alias dformat="dart format ."
alias danalyze="dart analyze"
alias dtest="dart test"
alias drun="dart run"
alias dcompile="dart compile"
alias dglobal="dart pub global"

# ── Firebase aliases ─────────────────────────────────────────
alias fblogin="firebase login"
alias fbdeploy="firebase deploy"
alias fbserve="firebase serve"
alias fbuse="firebase use"
alias fblist="firebase projects:list"
alias ffinit="flutterfire configure"

# ── Android Debug Bridge aliases ─────────────────────────────
alias adbdevices="adb devices"
alias adblog="adb logcat"
alias adbinstall="adb install"
alias adbrestart="adb kill-server && adb start-server"

# ── Git aliases ──────────────────────────────────────────────
alias gs="git status"
alias ga="git add"
alias gc="git commit -m"
alias gp="git push"
alias gpl="git pull"
alias gl="git log --oneline --graph --decorate"
alias gco="git checkout"
alias gb="git branch"
alias gd="git diff"

# ── General aliases ──────────────────────────────────────────
alias ll="ls -alFh --color=auto"
alias la="ls -A --color=auto"
alias cls="clear"
BASHRC

echo "✅ Shell setup complete"