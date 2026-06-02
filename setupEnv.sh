#!/bin/bash

# --- Konfiguration ---
REPO_URL="https://github.com/cecom/dotfiles"
DOTFILES_DIR="$HOME/.dotfiles"

# --- Farben für die Ausgabe ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 Setze Umgebung via Dotfiles auf...${NC}\n"

##########################################
##### OS-Erkennung (Linux / WSL / Windows)
##########################################
OS_TYPE="linux" # Standard-Fallback

# Prüfe auf WSL (Windows Subsystem for Linux)
if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null; then
    OS_TYPE="wsl"
# Prüfe auf native Windows Git-Bash (MSYS / MinGW)
elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
    OS_TYPE="windows"
# Mac OS (falls du mal einen Apfel kaufst)
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
fi

echo -e "💻 Erkanntes Betriebssystem: ${CYAN}${OS_TYPE}${NC}"


#######################################
###### 1. System-Tools prüfen
#######################################
echo -e "🔍 Prüfe benötigte System-Tools...\n"

# Liste aller Standard-Tools (fzf hat unten eine eigene Auto-Install-Logik)
TOOLS=("git" "curl" "zoxide" "tmux" "bash-completion" "jq" "unzip" "ripgrep" "tree" "htop" "command-not-found")
MISSING_TOOLS=()

# Liste abarbeiten
for pkg in "${TOOLS[@]}"; do
    
    # 1. Sonderbehandlung für spezielle Pakete
    case "$pkg" in
        "ripgrep") 
            check_cmd="rg" 
            ;;
        "bash-completion")
            # Prüft, ob das Verzeichnis oder die Skript-Datei existiert (da es kein Befehl ist)
            if [ -d "/usr/share/bash-completion" ] || [ -f "/etc/bash_completion" ] || [ -f "/usr/share/bash-completion/bash_completion" ]; then
                echo -e "${GREEN}✔ $pkg${NC} ist installiert."
                continue # Springt sofort zum nächsten Paket in der Liste
            else
                echo -e "${RED}✘ $pkg${NC} fehlt!"
                MISSING_TOOLS+=("$pkg")
                continue
            fi
            ;;
        "command-not-found")
            # Prüft auf Debian (command-not-found) oder Arch (pkgfile)
            if command -v command-not-found &> /dev/null || command -v pkgfile &> /dev/null; then
                echo -e "${GREEN}✔ $pkg${NC} ist installiert."
                continue
            else
                echo -e "${YELLOW}✘ $pkg${NC} fehlt! (Debian: apt install command-not-found | Arch: pacman -S pkgfile)"
                echo -e "Anschliessend ein 'sudo apt-file update' bzw. 'sudo pkgfile -u'"
                echo -e "Täglich aktualisieren unter arch: 'sudo systemctl enable --now pkgfile-update.timer'"
                # Wir packen es NICHT in MISSING_TOOLS, da der Paketname je nach OS variiert
                # und sonst der copy-paste Befehl am Ende des Skripts fehlschlagen würde.
                continue
            fi
            ;;
        *) 
            # Für alle anderen Tools ist der Paketname gleich dem Befehl
            check_cmd="$pkg" 
            ;;
    esac

    # 2. Eigentliche Prüfung für normale Befehle
    if command -v "$check_cmd" &> /dev/null; then
        echo -e "${GREEN}✔ $pkg${NC} ist installiert."
    else
        echo -e "${RED}✘ $pkg${NC} fehlt!"
        MISSING_TOOLS+=("$pkg")
    fi

done

# Warnung & Installationshilfe für fehlende Standard-Tools
if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}⚠️ Bitte installiere die fehlenden Tools manuell:${NC}"
    echo -e "  Debian/Ubuntu: sudo apt install ${MISSING_TOOLS[*]}"
    echo -e "  Arch/Garuda:   sudo pacman -S ${MISSING_TOOLS[*]}"
    
    # Harter Abbruch, falls Git oder Curl fehlen (werden fürs Setup zwingend gebraucht)
    if [[ " ${MISSING_TOOLS[*]} " =~ " git " ]] || [[ " ${MISSING_TOOLS[*]} " =~ " curl " ]]; then
        echo -e "\n${RED}🚨 Abbruch: 'git' und 'curl' werden zwingend für das Setup benötigt! Bitte erst installieren.${NC}"
        exit 1
    fi
    echo ""
fi

# fzf Check & Auto-Install (Sonderbehandlung, da es direkt in ~/.fzf geklont werden kann)
if command -v fzf &> /dev/null || [ -x "$HOME/.fzf/bin/fzf" ]; then
    echo -e "${GREEN}✔ fzf${NC} ist installiert."
else
    echo -e "${YELLOW}⚙️ fzf fehlt. Installiere automatisch via Git Clone...${NC}"
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf --quiet
    ~/.fzf/install --bin > /dev/null
    echo -e "${GREEN}✔ fzf erfolgreich in ~/.fzf installiert.${NC}"
fi
echo ""

##########################################
##### 2. Dotfiles Repository klonen/updaten
##########################################
echo -e "📦 Synchronisiere Dotfiles-Repository..."

if [ -d "$DOTFILES_DIR/.git" ]; then
    echo -e "${GREEN}⏭️ Repository existiert bereits. Ziehe Updates...${NC}"
    git -C "$DOTFILES_DIR" pull origin main --quiet
else
    echo -e "${YELLOW}📝 Klone Repository nach $DOTFILES_DIR...${NC}"
    git clone "$REPO_URL" "$DOTFILES_DIR" --quiet
fi
echo ""

##########################################
##### 3. Tmux Plugins klonen
##########################################
TMUX_PLUGIN_DIR="$HOME/.config/tmux/plugins"
mkdir -p "$TMUX_PLUGIN_DIR"

if [ ! -d "$TMUX_PLUGIN_DIR/tmux-power" ]; then
    echo -e "${YELLOW}📝 Klone tmux-power Theme...${NC}"
    git clone https://github.com/wfxr/tmux-power.git "$TMUX_PLUGIN_DIR/tmux-power" --quiet
fi

if [ ! -d "$TMUX_PLUGIN_DIR/tmux-mode-indicator" ]; then
    echo -e "${YELLOW}📝 Klone tmux-mode-indicator...${NC}"
    git clone https://github.com/MunifTanjim/tmux-mode-indicator.git "$TMUX_PLUGIN_DIR/tmux-mode-indicator" --quiet
fi

##########################################
##### 4. Symlinks erstellen
##########################################
echo -e "\n🔗 Erstelle Symlinks..."

ln -sf "$DOTFILES_DIR/gitconfig.custom" "$HOME/.gitconfig.custom"
echo -e "${GREEN}✔ Symlink für .gitconfig.custom erstellt.${NC}"

ln -sf "$DOTFILES_DIR/bashrc.custom" "$HOME/.bashrc.custom"
echo -e "${GREEN}✔ Symlink für .bashrc.custom erstellt.${NC}"

ln -sf "$DOTFILES_DIR/tmux.conf.custom" "$HOME/.tmux.conf.custom"
echo -e "${GREEN}✔ Symlink für .tmux.conf.custom erstellt.${NC}"
echo ""

##########################################
##### 5. Einbindungen in Hauptdateien
##########################################
echo -e "⚙️ Konfiguriere Git-Includes..."

# 1. Allgemeine Config (immer einbinden)
if ! git config --global --get-all include.path 2>/dev/null | grep -q "^$DOTFILES_DIR/gitconfig.custom$"; then
    git config --global --add include.path "$DOTFILES_DIR/gitconfig.custom"
    echo -e "${GREEN}✔ Allgemeine Config (gitconfig.custom) eingebunden.${NC}"
else
    echo -e "${GREEN}⏭️ Allgemeine Config war bereits eingebunden.${NC}"
fi

# 2. OS-spezifische Config (nur einbinden, wenn die Datei existiert)
OS_GITCONFIG="$DOTFILES_DIR/gitconfig.${OS_TYPE}"

if [ -f "$DOTFILES_DIR/gitconfig.${OS_TYPE}" ]; then
    if ! git config --global --get-all include.path 2>/dev/null | grep -q "^${OS_GITCONFIG}$"; then
        git config --global --add include.path "${OS_GITCONFIG}"
        echo -e "${GREEN}✔ OS-spezifische Config (${OS_TYPE}) eingebunden.${NC}"
    else
        echo -e "${GREEN}⏭️ OS-spezifische Config (${OS_TYPE}) war bereits eingebunden.${NC}"
    fi
else
    echo -e "${GRAY}⏭️ Keine OS-spezifische Datei (${OS_TYPE}) gefunden.${NC}"
fi

# -- Bashrc --
if [ -f ~/.bashrc ]; then
    sed -i '/unset PROMPT_COMMAND/d' ~/.bashrc 
fi

if [ -f ~/.bashrc ] && grep -q "source ~/.bashrc.custom" ~/.bashrc; then
    echo -e "${GREEN}⏭️ Einbindung in ~/.bashrc existiert bereits.${NC}"
else
    echo -e "${YELLOW}📝 Binde ~/.bashrc.custom in ~/.bashrc ein...${NC}"
cat << 'EOF' >> ~/.bashrc

# Garuda/Arch Override (Muss zwingend VOR dem Source-Befehl stehen)
unset PROMPT_COMMAND

# Lade benutzerdefinierte Bash-Konfiguration
if [ -f ~/.bashrc.custom ]; then
    source ~/.bashrc.custom
fi
EOF
fi

# -- Tmux.conf --
if [ -f ~/.tmux.conf ] && grep -q "source-file ~/.tmux.conf.custom" ~/.tmux.conf; then
    echo -e "${GREEN}⏭️ Einbindung in ~/.tmux.conf existiert bereits.${NC}"
else
    echo -e "${YELLOW}📝 Binde ~/.tmux.conf.custom in ~/.tmux.conf ein...${NC}"
cat << 'EOF' >> ~/.tmux.conf

# Lade benutzerdefinierte Tmux-Konfiguration
source-file ~/.tmux.conf.custom
EOF
fi

echo -e "\n${GREEN}✅ Dotfiles Setup abgeschlossen!${NC}"
echo -e "${YELLOW}👉 Bitte lade die Bash neu mit: source ~/.bashrc${NC}"
echo -e "${YELLOW}👉 Falls Tmux läuft, lade die Config neu mit: tmux source ~/.tmux.conf${NC}"
