#!/bin/bash
SCORE=100; ALERTES=0; ATTENTIONS=0; NONEVAL=0
echo "=== NetSecurePro AI – REAL AUDIT v1.1.1 ==="
echo ">>> 1. PORTS EN ECOUTE"
if ss -tln 2>&1 | grep -q "Permission denied\|no support"; then echo "[NON EVALUE] ss bloque"; NONEVAL=$((NONEVAL+1));
elif netstat -tln 2>&1 | grep -q "no support"; then echo "[NON EVALUE] netstat bloque"; NONEVAL=$((NONEVAL+1));
else echo "[OK] Ports checkes"; fi
echo ">>> 2. SSH"
if pgrep -x sshd >/dev/null; then LISTEN=$(sshd -T 2>/dev/null | grep listenaddress || echo "0.0.0.0:8022");
  if echo "$LISTEN" | grep -q "0.0.0.0"; then echo "[ATTENTION] -15 pts: sshd expose 0.0.0.0"; SCORE=$((SCORE-15)); ATTENTIONS=$((ATTENTIONS+1));
  else echo "[OK] sshd local"; fi
  if sshd -T 2>/dev/null | grep -q "passwordauthentication yes"; then echo "[ATTENTION] -5 pts: PasswordAuthentication yes"; SCORE=$((SCORE-5)); ATTENTIONS=$((ATTENTIONS+1)); fi
else echo "[INFO] sshd arrete"; fi
echo ">>> 3. MAJ"
if pkg list-upgradable 2>/dev/null | grep -q .; then echo "[ATTENTION] -5 pts: paquets en attente"; SCORE=$((SCORE-5)); ATTENTIONS=$((ATTENTIONS+1)); fi
echo "========================================="
echo "SCORE FINAL: $SCORE/100"
