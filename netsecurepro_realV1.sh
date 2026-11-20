#!/bin/bash
# ============================================================
# NetSecurePro AI – REAL AUDIT v1.1.1 (bêta)
# AUDIT LOCAL UNIQUEMENT – Termux + Linux
# Créateur : Mohammed Ilyes Zoubirou (@MZoubirou)
# ============================================================
# Périmètre : SSH (config effective + état du processus), ports
# en écoute (si l'OS le permet), permissions ~/.ssh, clés
# privées, mises à jour. Un score de 100 ne signifie PAS
# "machine sécurisée" ni "Zero Trust".
# Un contrôle [NON ÉVALUÉ] n'est PAS un [OK].
# ============================================================

umask 077   # le log contient des infos sensibles

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
AUDIT_LOG="$HOME/netsecurepro_real_audit.log"
SCORE=100
PENALTIES=()
NOT_EVAL=()
N_ALERT=0
N_WARN=0
PREFIX="${PREFIX:-/usr}"
PORT_PENALIZED=0   # évite de compter deux fois le même SSH exposé

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$AUDIT_LOG"; }

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[ATTENTION]${NC} $1"; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }

not_eval() {
    echo -e "${YELLOW}[NON ÉVALUÉ]${NC} $1"
    NOT_EVAL+=("$1")
    log "NOT EVALUATED : $1"
}

# add_penalty NIVEAU POINTS MESSAGE – affiche immédiatement la constatation
add_penalty() {
    SCORE=$((SCORE - $2))
    [ "$SCORE" -lt 0 ] && SCORE=0
    PENALTIES+=("[$1] -$2 pts : $3")
    if [ "$1" = "ALERTE" ]; then
        N_ALERT=$((N_ALERT + 1))
        echo -e "${RED}[ALERTE]${NC} -$2 pts : $3"
    else
        N_WARN=$((N_WARN + 1))
        echo -e "${YELLOW}[ATTENTION]${NC} -$2 pts : $3"
    fi
    log "PENALTY [$1] -$2 : $3"
}

print_header() {
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN} NetSecurePro AI – REAL AUDIT v1.1.1 (bêta)${NC}"
    echo -e "${YELLOW}[AVERTISSEMENT] Audit de CETTE machine uniquement${NC}"
    echo -e "${CYAN}============================================================${NC}"
    log "AUDIT START v1.1.1"
}

check_tools() {
    command -v apt >/dev/null 2>&1 && TOOL_PKG="apt" || TOOL_PKG="none"
    log "TOOLS: PKG=$TOOL_PKG"
}

# sshd_state : 0 = tourne, 1 = arrêté, 2 = indéterminé
sshd_state() {
    if command -v pgrep >/dev/null 2>&1; then
        pgrep -x sshd >/dev/null 2>&1 && return 0 || return 1
    elif command -v ps >/dev/null 2>&1; then
        { ps -e 2>/dev/null || ps 2>/dev/null; } | grep -qw sshd && return 0 || return 1
    fi
    return 2
}

# port_exposed PORT : écoute sur toutes les interfaces (pas loopback)
port_exposed() {
    echo "$PORTS" | grep -Eq "(0\.0\.0\.0|\*|\[::\]|::):$1[[:space:]]"
}

check_ports() {
    echo -e "\n${CYAN}>>> 1. PORTS EN ÉCOUTE${NC}"
    PORTS=""
    local done_ok=0 t out
    for t in ss netstat; do
        command -v "$t" >/dev/null 2>&1 || continue
        out=$($t -tln 2>&1)
        # Erreurs fréquentes sur Android : le code retour peut rester 0
        if echo "$out" | grep -qiE 'permission denied|cannot open|no support|not permitted|operation not|not supported'; then
            log "PORTS: $t bloqué ($(echo "$out" | head -1))"
            continue
        fi
        PORTS=$(echo "$out" | grep -E 'LISTEN|^tcp')
        done_ok=1
        break
    done

    if [ "$done_ok" -eq 0 ]; then
        not_eval "Détection de ports impossible (ss/netstat absents ou bloqués par l'OS). Voir contrôle SSH ci-dessous."
        return
    fi

    if [ -z "$PORTS" ]; then
        ok "Aucun port TCP en écoute détecté par $t"
    else
        echo "$PORTS"
        port_exposed 22   && { add_penalty "ALERTE" 20 "SSH port 22 exposé sur toutes les interfaces"; PORT_PENALIZED=1; }
        port_exposed 8022 && { add_penalty "ATTENTION" 10 "SSH Termux port 8022 exposé sur toutes les interfaces"; PORT_PENALIZED=1; }
        if ! port_exposed 22 && ! port_exposed 8022; then
            ok "Pas de SSH exposé (22/8022) hors loopback, parmi les ports visibles"
        fi
    fi
}

# directive_value NOM FICHIER : première valeur effective (hors commentaires)
directive_value() {
    grep -Ei "^[[:space:]]*$1[[:space:]]+" "$2" 2>/dev/null | head -1 | awk '{print tolower($2)}'
}

check_ssh() {
    echo -e "\n${CYAN}>>> 2. SSH (config effective + état du processus)${NC}"
    if ! command -v sshd >/dev/null 2>&1; then
        info "sshd non installé : contrôles SSH sans objet"
        return
    fi

    sshd_state; STATE=$?
    case $STATE in
        0) info "sshd est EN COURS D'EXÉCUTION" ;;
        1) info "sshd n'est pas lancé" ;;
        *) not_eval "Impossible de savoir si sshd tourne (ni pgrep ni ps)" ;;
    esac

    # Gravité : réelle si sshd tourne, latente sinon
    if [ "$STATE" -eq 0 ]; then PEN_LVL="ALERTE"; PEN_PTS=15; else PEN_LVL="ATTENTION"; PEN_PTS=5; fi

    EFF=$(sshd -T 2>&1)
    if echo "$EFF" | grep -qi '^passwordauthentication'; then
        info "Config lue avec : sshd -T (inclut sshd_config.d)"
        PA=$(echo "$EFF" | awk 'tolower($1)=="passwordauthentication"{print tolower($2)}')
        PR=$(echo "$EFF" | awk 'tolower($1)=="permitrootlogin"{print tolower($2)}')
        LA=$(echo "$EFF" | awk 'tolower($1)=="listenaddress"{print $2}')
        SPORT=$(echo "$EFF" | awk 'tolower($1)=="port"{print $2; exit}')
    else
        SSHD_CONF="$PREFIX/etc/ssh/sshd_config"
        [ ! -f "$SSHD_CONF" ] && SSHD_CONF="/etc/ssh/sshd_config"
        if [ -f "$SSHD_CONF" ]; then
            warn "sshd -T indisponible : lecture de $SSHD_CONF (sshd_config.d NON pris en compte)"
            PA=$(directive_value PasswordAuthentication "$SSHD_CONF"); [ -z "$PA" ] && PA="yes"
            PR=$(directive_value PermitRootLogin "$SSHD_CONF")
            LA=""; SPORT=$(directive_value Port "$SSHD_CONF")
        else
            not_eval "Config SSH illisible (sshd -T en erreur, sshd_config introuvable)"
            return
        fi
    fi

    case "$PA" in
        yes) add_penalty "$PEN_LVL" "$PEN_PTS" "PasswordAuthentication = yes" ;;
        no)  ok "PasswordAuthentication désactivé" ;;
        *)   not_eval "PasswordAuthentication : valeur illisible" ;;
    esac
    case "$PR" in
        yes) add_penalty "$PEN_LVL" "$PEN_PTS" "PermitRootLogin = yes" ;;
        "")  info "PermitRootLogin non lu" ;;
        *)   ok "PermitRootLogin : $PR" ;;
    esac

    # Exposition : adresses d'écoute non-loopback
    EXPOSED=$(echo "$LA" | grep -Ev '^(127\.|\[::1\])' | grep -v '^$' | tr '\n' ' ')
    if [ -n "$EXPOSED" ]; then
        if [ "$STATE" -eq 0 ] && [ "$PORT_PENALIZED" -eq 1 ]; then
            info "sshd actif sur : $EXPOSED (déjà compté dans le contrôle des ports)"
        elif [ "$STATE" -eq 0 ]; then
            if [ "$SPORT" = "22" ]; then
                add_penalty "ALERTE" 20 "sshd actif, à l'écoute sur : $EXPOSED"
            else
                add_penalty "ATTENTION" 10 "sshd actif, à l'écoute sur : $EXPOSED"
            fi
        else
            info "Si lancé, sshd écouterait sur : $EXPOSED (non exposé tant qu'il est arrêté)"
        fi
    elif [ -n "$LA" ]; then
        ok "sshd n'écoute qu'en loopback"
    fi

    command -v ssh >/dev/null 2>&1 && info "Version : $(ssh -V 2>&1 | head -1)"
    log "SSH AUDIT DONE (state=$STATE)"
}

check_ssh_perms() {
    echo -e "\n${CYAN}>>> 3. PERMISSIONS ~/.ssh ET CLÉS${NC}"
    if [ -d "$HOME/.ssh" ]; then
        PERM=$(stat -c %a "$HOME/.ssh" 2>/dev/null)
        case "$PERM" in
            700|600|500|400) ok "Permissions ~/.ssh : $PERM" ;;
            "") not_eval "Permissions de ~/.ssh illisibles" ;;
            *) add_penalty "ALERTE" 10 "~/.ssh permissions $PERM (attendu 700)" ;;
        esac
        BAD=$(find "$HOME/.ssh" -type f -name 'id_*' ! -name '*.pub' -perm /077 2>/dev/null)
        if [ -n "$BAD" ]; then
            add_penalty "ALERTE" 15 "Clé privée lisible par group/other : $(echo "$BAD" | tr '\n' ' ')"
        else
            ok "Clés privées protégées (ou absentes)"
        fi
    else
        ok "Dossier ~/.ssh inexistant"
    fi
}

check_updates() {
    echo -e "\n${CYAN}>>> 4. MISES À JOUR${NC}"
    if [ "$TOOL_PKG" = "none" ]; then
        not_eval "apt indisponible"
        return
    fi
    UPDATES=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)
    if [ "$UPDATES" -gt 0 ]; then
        add_penalty "ATTENTION" 5 "$UPDATES paquet(s) en attente (d'après le cache apt local, non rafraîchi)"
    else
        ok "Aucune mise à jour en attente (d'après le cache apt local)"
    fi
}

check_interfaces() {
    echo -e "\n${CYAN}>>> 5. INTERFACES RÉSEAU (info, sans pénalité)${NC}"
    if command -v ip >/dev/null 2>&1; then
        IPOUT=$(ip a 2>&1 | grep -E '^[0-9]+:|inet ')
        [ -n "$IPOUT" ] && echo "$IPOUT" || info "ip : aucune donnée (accès refusé ?)"
    else
        info "ip indisponible"
    fi
}

print_report() {
    echo -e "\n${CYAN}============================================================${NC}"
    echo -e "${CYAN} SCORE DE DURCISSEMENT SSH/PORTS : $SCORE/100${NC}"
    [ ${#NOT_EVAL[@]} -gt 0 ] && echo -e "${YELLOW} (calculé sur les contrôles évalués seulement)${NC}"
    echo -e "${CYAN} Alertes : $N_ALERT | Attentions : $N_WARN | Non évalués : ${#NOT_EVAL[@]}${NC}"
    echo -e "${CYAN}============================================================${NC}"
    for p in "${PENALTIES[@]}"; do
        case "$p" in
            "[ALERTE]"*) echo -e "${RED}$p${NC}" ;;
            *) echo -e "${YELLOW}$p${NC}" ;;
        esac
    done
    [ ${#PENALTIES[@]} -eq 0 ] && ok "Aucune pénalité sur les points évalués"
    for n in "${NOT_EVAL[@]}"; do echo -e "${YELLOW}[NON ÉVALUÉ]${NC} $n"; done
    echo -e "\n${YELLOW}Périmètre limité : SSH, ports (si visibles), permissions, mises à jour.${NC}"
    echo -e "${YELLOW}Un contrôle non évalué ne vaut pas OK. Log : $AUDIT_LOG${NC}"
    log "AUDIT END SCORE:$SCORE ALERTS:$N_ALERT WARNINGS:$N_WARN NOT_EVAL:${#NOT_EVAL[@]}"
}

print_header
check_tools
check_ports
check_ssh
check_ssh_perms
check_updates
check_interfaces
print_report
