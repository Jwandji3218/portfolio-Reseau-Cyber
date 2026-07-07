#!/bin/bash

# Script d'audit de sécurité - Projet 3
# Usage: sudo ./audit.sh

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

LOGFILE="$HOME/audit_$(date +%Y%m%d_%H%M).log"

log() {
echo -e "$1" | tee -a "$LOGFILE"
}

ok() {
log "${GREEN}[OK]${NC} $1"
}

warn() {
log "${RED}[!!]${NC} $1"
}

section() {
log "\n${BLUE}=== $1 ===${NC}"
}

if [ "$EUID" -ne 0 ]; then
echo "Merci de lancer ce script avec sudo."
exit 1
fi

log "${YELLOW}Rapport d'audit de sécurité - $(date)${NC}"
log "Machine : $(hostname)"

# --- Système ---
section "SYSTÈME"
log "OS : $(lsb_release -d | cut -f2)"
log "Uptime : $(uptime -p)"
log "Charge : $(uptime | awk -F'load average:' '{print $2}')"

# --- Comptes utilisateurs ---
section "COMPTES UTILISATEURS"
uid0=$(awk -F: '($3 == 0) {print $1}' /etc/passwd)
if [ "$(echo "$uid0" | wc -l)" -eq 1 ] && [ "$uid0" = "root" ]; then
ok "Seul 'root' a l'UID 0."
else
warn "Attention, plusieurs comptes avec UID 0 détectés : $uid0"
fi

nopass=$(sudo awk -F: '($2 == "") {print $1}' /etc/shadow)
if [ -z "$nopass" ]; then
ok "Aucun compte sans mot de passe."
else
warn "Comptes sans mot de passe détectés : $nopass"
fi

# --- SSH ---
section "CONFIGURATION SSH"
root_login=$(sshd -T | grep -i "^permitrootlogin" | awk '{print $2}')
pass_auth=$(sshd -T | grep -i "^passwordauthentication" | awk '{print $2}')
pubkey_auth=$(sshd -T | grep -i "^pubkeyauthentication" | awk '{print $2}')

if [ "$root_login" = "no" ]; then
ok "PermitRootLogin désactivé."
else
warn "PermitRootLogin est activé (valeur: $root_login) !"
fi

if [ "$pass_auth" = "no" ]; then
ok "PasswordAuthentication désactivé (connexion par clé uniquement)."
else
warn "PasswordAuthentication est activé (valeur: $pass_auth) !"
fi

if [ "$pubkey_auth" = "yes" ]; then
ok "PubkeyAuthentication activé."
else
warn "PubkeyAuthentication est désactivé (valeur: $pubkey_auth) !"
fi

# --- UFW ---
section "PARE-FEU (UFW)"
ufw_status=$(ufw status | head -n1)
log "$ufw_status"
if echo "$ufw_status" | grep -q "active"; then
ok "UFW est actif."
log "$(ufw status numbered)"
else
warn "UFW est INACTIF !"
fi

# --- Ports en écoute ---
section "PORTS EN ÉCOUTE"
log "$(ss -tulnp 2>/dev/null | tail -n +2)"

# --- Mises à jour ---
section "MISES À JOUR DE SÉCURITÉ"
updates=$(apt list --upgradable 2>/dev/null | grep -c security)
if [ "$updates" -eq 0 ]; then
ok "Aucune mise à jour de sécurité en attente."
else
warn "$updates mise(s) à jour de sécurité en attente."
fi

# --- Dernières connexions ---
section "DERNIÈRES CONNEXIONS (10 max)"
log "$(last -n 10)"

log "\n${YELLOW}Rapport sauvegardé dans : $LOGFILE${NC}"
