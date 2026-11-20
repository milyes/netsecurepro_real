# NetSecurePro AI – Z-CORE

**FR** – Console de démonstration Zero Trust + petit audit local SSH/ports.
**EN** – Zero Trust demo console + a small local SSH/ports audit.

Auteur / Author: Mohammed Ilyes Zoubirou ([@MZoubirou](https://github.com/MZoubirou)) – Montréal

---

## ⚠️ Avertissement / Warning

**FR** – Ce dépôt contient **deux outils différents**. Ne les confondez pas.

**EN** – This repo contains **two different tools**. Do not mix them up.

| | `netsecurepro_demo.sh` | `netsecurepro_real.sh` |
| --- | --- | --- |
| Version | v1.3.2 | v1.1.1 (bêta / beta) |
| Nature | **Simulation** | **Audit local réel / real local audit** |
| Données / Data | Fictives, codées en dur / Fictional, hard-coded | Lues sur la machine / Read from this machine |
| Étiquette / Label | `[SIM]` | `[OK]` `[ATTENTION]` `[ALERTE]` |
| Score | Plancher à 70, sans signification / Floor at 70, meaningless | 100 moins pénalités détaillées / 100 minus itemised penalties |
| Usage | Démos, présentations / Demos, presentations | Audit de **votre** machine / Audit of **your** machine |

**FR** – Auditez uniquement vos propres machines, ou celles pour lesquelles vous avez une autorisation écrite.
**EN** – Only audit your own machines, or ones you have written permission to audit.

**FR** – Projet indépendant, non affilié à Tesla, Inc. ni au NIST. Aucun véhicule n'est contacté. « NIST SP 800-207 » est cité comme référence d'inspiration uniquement : aucune conformité ni certification n'est revendiquée.
**EN** – Independent project, not affiliated with Tesla, Inc. or NIST. No vehicle is ever contacted. "NIST SP 800-207" is cited as inspiration only: no compliance or certification is claimed.

---

## 1. `netsecurepro_demo.sh` – Simulation

**FR** – Console pour illustrer le concept Zero Trust + segment Tesla S15 + RBAC. Tout est fictif : les valeurs « conformes » ou « 100 % » ne reflètent aucun contrôle réel.

**EN** – Console to illustrate a Zero Trust + Tesla S15 segment + RBAC concept. Everything is fictional: "compliant" or "100 %" values reflect no real check.

Menu: statut / status · Tesla · scan NIST · violation · RBAC · reset · logs · quitter / quit.

Log: `$HOME/netsecurepro_audit.log`

```bash
chmod +x netsecurepro_demo.sh
./netsecurepro_demo.sh
```

---

## 2. `netsecurepro_real.sh` – Audit local / Local audit

**FR** – Audite la machine sur laquelle il tourne (Linux ou Termux). Ne se connecte à aucune autre machine.
**EN** – Audits the machine it runs on (Linux or Termux). Does not connect to any other machine.

### Vérifié / Checked

| # | FR | EN |
| --- | --- | --- |
| 1 | Ports TCP en écoute **si l'OS le permet** ; pénalité si SSH (22 ou 8022) est exposé hors loopback. Sinon : `[NON ÉVALUÉ]` | Listening TCP ports **if the OS allows it**; penalty if SSH (22 or 8022) is exposed beyond loopback. Otherwise: `[NON ÉVALUÉ]` (not evaluated) |
| 2 | SSH : configuration **effective** via `sshd -T` (inclut `sshd_config.d`), repli sur le fichier ; état du processus `sshd` ; adresses d'écoute | SSH: **effective** configuration via `sshd -T` (includes `sshd_config.d`), file fallback; `sshd` process state; listen addresses |
| 3 | Permissions de `~/.ssh` et clés privées lisibles par group/other | `~/.ssh` permissions and private keys readable by group/other |
| 4 | Mises à jour `apt` en attente (selon le **cache local**, non rafraîchi) | Pending `apt` updates (from the **local cache**, not refreshed) |
| 5 | Interfaces réseau `ip a` (info seulement, sans pénalité) | Network interfaces `ip a` (info only, no penalty) |

**FR** – Gravité SSH : `PasswordAuthentication yes` ou `PermitRootLogin yes` = -15 (ALERTE) si `sshd` tourne, -5 (ATTENTION) s'il est arrêté. `sshd` actif sur une adresse non-loopback = -10 (-20 si port 22).
**EN** – SSH severity: `PasswordAuthentication yes` or `PermitRootLogin yes` = -15 (ALERT) if `sshd` is running, -5 (WARNING) if stopped. `sshd` running on a non-loopback address = -10 (-20 on port 22).

**FR** – `[NON ÉVALUÉ]` signifie « impossible à vérifier ici », **jamais** « OK ». Le score est calculé uniquement sur les contrôles évalués.
**EN** – `[NON ÉVALUÉ]` means "cannot be checked here", **never** "OK". The score covers evaluated checks only.

### Non vérifié / Not checked

- FR : pare-feu, antivirus, vulnérabilités applicatives, autres utilisateurs, sécurité du réseau, conformité réelle à un référentiel.
- EN: firewall, antivirus, application vulnerabilities, other users, network security, real compliance with any framework.

**FR** – Le score s'appelle « Score de durcissement SSH/ports ». 100/100 signifie « rien à signaler sur ces points », **pas** « machine sécurisée ».
**EN** – The score is a "SSH/ports hardening score". 100/100 means "nothing to report on these points", **not** "machine is secure".

### Limites constatées / Observed limitations

**FR** – Sur Termux 0.118.3 (F-Droid) / Android 16 / aarch64, sans root : `ss` répond « Permission denied » (en renvoyant quand même le code 0) et `netstat` n'est pas supporté. La détection de ports est donc `[NON ÉVALUÉ]`, et l'exposition SSH est déduite de `sshd -T` et de l'état du processus. `ip` peut aussi être limité.
**EN** – On Termux 0.118.3 (F-Droid) / Android 16 / aarch64, non-root: `ss` answers "Permission denied" (while still returning exit code 0) and `netstat` is unsupported. Port detection is therefore `[NON ÉVALUÉ]`, and SSH exposure is inferred from `sshd -T` and the process state. `ip` may also be limited.

Log: `$HOME/netsecurepro_real_audit.log` (créé avec `umask 077` / created with `umask 077`). Il contient des informations sensibles : ne le publiez pas / it contains sensitive information: do not publish it.

```bash
chmod +x netsecurepro_real.sh
./netsecurepro_real.sh
```

---

## 3. Statut / Status

- Demo v1.3.2 : testé / tested (menu 1–8).
- Real v1.1 : testé sur / tested on Termux 0.118.3 (F-Droid) / Android 16 / aarch64 – a révélé un faux `[OK]` sur les ports (corrigé en v1.1.1) / revealed a false `[OK]` on ports (fixed in v1.1.1).
- Real v1.1.1 : testé avec simulations ; **à retester sur appareil réel** / tested with mocks; **to be re-tested on a real device**.

## 4. Licence / License

MIT – voir / see [LICENSE](LICENSE). Fourni « tel quel », sans garantie / provided "as is", without warranty.
