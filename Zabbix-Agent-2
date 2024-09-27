#!/bin/bash

# Funkcja sprawdzająca, czy użytkownik jest rootem
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Proszę uruchomić skrypt jako root."
        exit 1
    fi
}

# Funkcja doinstalowująca brakujące pakiety
install_missing_packages() {
    echo "Sprawdzanie brakujących pakietów..."
    if ! command -v openssl &> /dev/null; then
        echo "Instalowanie brakującego pakietu openssl..."
        apt install -y openssl
    fi
}

# Funkcja generująca klucz PSK
generate_psk() {
    read -p "Podaj identyfikator PSK (np. PSK001): " PSK_ID

    # Generowanie 256-bitowego klucza PSK za pomocą OpenSSL
    PSK_KEY=$(openssl rand -hex 32)

    # Wyświetlanie wygenerowanego klucza PSK
    echo "Wygenerowany klucz PSK: $PSK_KEY"

    # Zapis klucza PSK do pliku (możesz zmienić ścieżkę w razie potrzeby)
    echo "$PSK_KEY" > /etc/zabbix/zabbix_agent2.psk
}

# Funkcja instalacji i konfiguracji Zabbix Agent 2
install_zabbix_agent2() {
    echo "Instalowanie Zabbix Agent 2 (wersja 7.0)..."

    # Pobieranie repozytorium Zabbix dla wersji 7.0
    wget https://repo.zabbix.com/zabbix/7.0/$(lsb_release -si | awk '{print tolower($0)}')/pool/main/z/zabbix-release/zabbix-release_7.0-1+$(lsb_release -sc)_all.deb

    # Instalacja repozytorium
    dpkg -i zabbix-release_7.0-1+$(lsb_release -sc)_all.deb
    apt update

    # Instalacja agenta Zabbix 2
    apt install -y zabbix-agent2

    # Upewnij się, że agent się zainstalował
    if ! command -v zabbix_agent2 &> /dev/null; then
        echo "Błąd: Zabbix Agent 2 nie został poprawnie zainstalowany."
        exit 1
    fi
    echo "Zabbix Agent 2 zainstalowany pomyślnie."
}

# Funkcja konfiguracji Zabbix Agent 2 z szyfrowaniem PSK
configure_zabbix_agent2() {
    # Zapytanie o szczegóły konfiguracji
    read -p "Podaj IP serwera Zabbix: " ZABBIX_SERVER_IP
    read -p "Podaj IP aktywnego serwera Zabbix: " ZABBIX_ACTIVE_SERVER_IP
    read -p "Podaj nazwę hosta dla agenta: " HOSTNAME
    read -p "Podaj port (domyślnie 10050) dla agenta pasywnego: " PASSIVE_PORT
    PASSIVE_PORT=${PASSIVE_PORT:-10050}
    read -p "Podaj port (domyślnie 10051) dla agenta aktywnego: " ACTIVE_PORT
    ACTIVE_PORT=${ACTIVE_PORT:-10051}

    # Edycja pliku konfiguracyjnego Zabbix Agent 2
    ZABBIX_CONFIG="/etc/zabbix/zabbix_agent2.conf"

    # Tworzenie kopii zapasowej pliku konfiguracyjnego
    cp $ZABBIX_CONFIG ${ZABBIX_CONFIG}.bak

    # Aktualizacja pliku konfiguracyjnego z PSK
    sed -i "s/^Server=.*/Server=$ZABBIX_SERVER_IP/" $ZABBIX_CONFIG
    sed -i "s/^ServerActive=.*/ServerActive=$ZABBIX_ACTIVE_SERVER_IP:$ACTIVE_PORT/" $ZABBIX_CONFIG
    sed -i "s/^Hostname=.*/Hostname=$HOSTNAME/" $ZABBIX_CONFIG
    sed -i "s/^ListenPort=.*/ListenPort=$PASSIVE_PORT/" $ZABBIX_CONFIG

    # Dodanie szyfrowania PSK
    sed -i "s/^# TLSConnect=.*/TLSConnect=psk/" $ZABBIX_CONFIG
    sed -i "s/^# TLSAccept=.*/TLSAccept=psk/" $ZABBIX_CONFIG
    sed -i "s/^# TLSPSKIdentity=.*/TLSPSKIdentity=$PSK_ID/" $ZABBIX_CONFIG
    sed -i "s|^# TLSPSKFile=.*|TLSPSKFile=/etc/zabbix/zabbix_agent2.psk|" $ZABBIX_CONFIG

    echo "Konfiguracja Zabbix Agent 2 z szyfrowaniem PSK zakończona pomyślnie."
}

# Funkcja restartująca i włączająca agenta
restart_zabbix_agent2() {
    echo "Restartowanie usługi Zabbix Agent 2..."
    systemctl restart zabbix-agent2
    systemctl enable zabbix-agent2
    echo "Zabbix Agent 2 został uruchomiony i włączony do automatycznego startu."
}

# Funkcja główna
main() {
    check_root
    install_missing_packages
    install_zabbix_agent2
    generate_psk
    configure_zabbix_agent2
    restart_zabbix_agent2
    echo "Instalacja i konfiguracja Zabbix Agent 2 z szyfrowaniem PSK zakończona pomyślnie."
}

# Uruchomienie głównej funkcji
main
