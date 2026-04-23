#!/bin/bash
#
# Zabbix Agent 2 - konfiguracja + PSK
# Zakłada, że agent jest już zainstalowany (paczka z repo dystrybucji).
#

set -euo pipefail

ZABBIX_CONFIG="/etc/zabbix/zabbix_agent2.conf"
PSK_FILE="/etc/zabbix/zabbix_agent2.psk"

# --- Walidacja uprawnień ---
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "[ERR] Uruchom jako root." >&2
        exit 1
    fi
}

# --- Walidacja stanu systemu: agent + openssl ---
check_prereqs() {
    if ! command -v zabbix_agent2 &>/dev/null; then
        echo "[ERR] zabbix_agent2 nie jest zainstalowany. Zainstaluj paczkę z repo Zabbix i uruchom skrypt ponownie." >&2
        exit 1
    fi
    if ! command -v openssl &>/dev/null; then
        echo "[ERR] Brak openssl - zainstaluj pakiet openssl." >&2
        exit 1
    fi
    if [ ! -f "$ZABBIX_CONFIG" ]; then
        echo "[ERR] Brak pliku $ZABBIX_CONFIG." >&2
        exit 1
    fi
}

# --- Prosta walidacja IP/FQDN (server może być lista oddzielona przecinkami) ---
validate_host() {
    local v="$1"
    [[ -n "$v" ]] || return 1
    # Dopuszczamy IP, FQDN, listę rozdzieloną przecinkami
    [[ "$v" =~ ^[A-Za-z0-9.,:_-]+$ ]] || return 1
    return 0
}

# --- Zbieranie parametrów od operatora ---
collect_params() {
    read -rp "Hostname agenta (musi zgadzać się z 'Host name' w Zabbix): " HOSTNAME_VAL
    [[ -n "$HOSTNAME_VAL" ]] || { echo "[ERR] Hostname wymagany."; exit 1; }

    read -rp "IP/FQDN Zabbix Server (pasywne, Server=): " ZBX_SERVER
    validate_host "$ZBX_SERVER" || { echo "[ERR] Nieprawidłowy Server."; exit 1; }

    read -rp "IP/FQDN Zabbix Server (aktywne, ServerActive=, pusty = taki sam jak Server): " ZBX_ACTIVE
    ZBX_ACTIVE="${ZBX_ACTIVE:-$ZBX_SERVER}"
    validate_host "$ZBX_ACTIVE" || { echo "[ERR] Nieprawidłowy ServerActive."; exit 1; }

    read -rp "ListenPort pasywny [10050]: " PASSIVE_PORT
    PASSIVE_PORT="${PASSIVE_PORT:-10050}"

    read -rp "Port aktywny serwera [10051]: " ACTIVE_PORT
    ACTIVE_PORT="${ACTIVE_PORT:-10051}"

    read -rp "TLSPSKIdentity (np. PSK-${HOSTNAME_VAL}): " PSK_ID
    PSK_ID="${PSK_ID:-PSK-${HOSTNAME_VAL}}"
}

# --- Generowanie PSK 256-bit ---
generate_psk() {
    if [ -f "$PSK_FILE" ]; then
        read -rp "[WARN] $PSK_FILE już istnieje. Nadpisać? [t/N]: " ans
        [[ "${ans,,}" == "t" ]] || { echo "[INFO] Pozostawiam istniejący PSK."; PSK_KEY="$(cat "$PSK_FILE")"; return 0; }
    fi

    PSK_KEY="$(openssl rand -hex 32)"
    install -m 640 -o zabbix -g zabbix /dev/null "$PSK_FILE"
    printf '%s\n' "$PSK_KEY" > "$PSK_FILE"
    chmod 640 "$PSK_FILE"
    chown zabbix:zabbix "$PSK_FILE"
}

# --- Aktualizacja parametru w zabbix_agent2.conf (działa na zakomentowanych i odkomentowanych) ---
# $1 = klucz, $2 = wartość
set_cfg() {
    local key="$1" val="$2" esc_val
    esc_val=$(printf '%s\n' "$val" | sed 's/[&/\]/\\&/g')
    if grep -Eq "^[#[:space:]]*${key}=" "$ZABBIX_CONFIG"; then
        sed -i -E "s|^[#[:space:]]*${key}=.*|${key}=${esc_val}|" "$ZABBIX_CONFIG"
    else
        echo "${key}=${val}" >> "$ZABBIX_CONFIG"
    fi
}

apply_config() {
    cp -a "$ZABBIX_CONFIG" "${ZABBIX_CONFIG}.bak.$(date +%Y%m%d-%H%M%S)"

    set_cfg "Server"          "$ZBX_SERVER"
    set_cfg "ServerActive"    "${ZBX_ACTIVE}:${ACTIVE_PORT}"
    set_cfg "Hostname"        "$HOSTNAME_VAL"
    set_cfg "ListenPort"      "$PASSIVE_PORT"
    set_cfg "TLSConnect"      "psk"
    set_cfg "TLSAccept"       "psk"
    set_cfg "TLSPSKIdentity"  "$PSK_ID"
    set_cfg "TLSPSKFile"      "$PSK_FILE"

    # Walidacja konfiguracji przed restartem
    if ! zabbix_agent2 -c "$ZABBIX_CONFIG" -T >/dev/null 2>&1; then
        echo "[WARN] zabbix_agent2 -T zgłosił problem - sprawdź konfigurację ręcznie."
    fi
}

restart_agent() {
    systemctl enable --now zabbix-agent2
    systemctl restart zabbix-agent2
    sleep 1
    systemctl --no-pager --full status zabbix-agent2 | head -n 15
}

summary() {
    cat <<EOF

========= PODSUMOWANIE =========
Hostname:         $HOSTNAME_VAL
Server:           $ZBX_SERVER
ServerActive:     ${ZBX_ACTIVE}:${ACTIVE_PORT}
ListenPort:       $PASSIVE_PORT
TLSPSKIdentity:   $PSK_ID
TLSPSKFile:       $PSK_FILE
PSK (do frontendu Zabbix):
$PSK_KEY
================================

Wklej Identity i PSK w konfiguracji hosta na serwerze Zabbix (Encryption -> PSK).
EOF
}

main() {
    check_root
    check_prereqs
    collect_params
    generate_psk
    apply_config
    restart_agent
    summary
}

main "$@"