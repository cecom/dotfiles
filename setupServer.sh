#!/bin/bash
echo "Setze Server auf..."

# Git Config schreiben
cat << 'EOF' > ~/.gitconfig
[alias]
  s = status -sb
  lg = log --oneline
[user]
  name = Sven Oppermann
  email = sven.oppermann@iosus.de
[core]
  editor = vi
EOF

# Prüfen, ob unser Prompt schon drin ist
if ! grep -q "get_git_info" ~/.bashrc; then
    echo "Füge hübschen Git-Prompt hinzu..."
    
    cat << 'EOF' >> ~/.bashrc

# --- Git Info Funktion für den Prompt ---
function get_git_info() {
    # Lautlos abbrechen, wenn wir nicht in einem Git-Repo sind
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then return; fi

    local branch=$(git branch --show-current 2>/dev/null)
    
    # Basis: Grüner Text für "git" und den Branch
    local info=" \[\e[0;32m\]git ⎇ \[\e[1;32m\]$branch"

    # Ausgabe zurückgeben
    echo -e "$info"
}

# --- Custom Server Prompt ---
# Baut sich dynamisch auf. $(get_git_info) wird bei jedem Enter neu ausgeführt.
PS1='\n\[\e[0m\]🦎 📂 \[\e[1;36m\]\w$(get_git_info)\[\e[0m\]\n\[\e[1;31m\]➔ \[\e[0m\]'
# ----------------------------
EOF

fi

source ~/.bashrc
echo "✅ Setup abgeschlossen!"