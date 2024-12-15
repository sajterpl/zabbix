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
    MISSING_PACKAGES=""
    if ! command -v openssl &> /dev/null; then
        MISSING_PACKAGES+="openssl "
    fi
    if ! command -v wget &> /dev/null; then
        MISSING_PACKAGES+="wget "
    fi
    if [ -n "$MISSING_PACKAGES" ]; then
        echo "Instalowanie brakujących pakietów: $MISSING_PACKAGES"
        apt update && apt install -y $MISSING_PACKAGES
    else
        echo "Wszystkie wymagane pakiety są zainstalowane."
    fi
}

# Funkcja weryfikująca system operacyjny
detect_system() {
    echo "Wykrywanie systemu operacyjnego..."
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_NAME=$ID
        OS_VERSION=$VERSION_ID
        OS_PRETTY_NAME=$PRETTY_NAME
    elif [[ -f /etc/redhat-release ]]; then
        OS_NAME="rhel"
        OS_VERSION=$(rpm --eval %{centos_ver})
        OS_PRETTY_NAME=$(cat /etc/redhat-release)
    else
        echo "Nieobsługiwany system operacyjny. Skrypt wspiera tylko Debian/Ubuntu i CentOS/Red Hat."
        exit 1
    fi

    # Wyświetlenie szczegółów systemu
    echo "Wykryty system operacyjny: $OS_PRETTY_NAME"
    echo "ID systemu: $OS_NAME"
    echo "Wersja systemu: $OS_VERSION"
    echo ""

    # Wyświetlenie formatu linku do pobrania agenta
    echo "Proszę użyć odpowiedniego linku do pobrania Zabbix Agent 2:"
    if [[ $OS_NAME == "ubuntu" || $OS_NAME == "debian" ]]; then
        echo "https://repo.zabbix.com/zabbix/<wersja>/$OS_NAME/pool/main/z/zabbix-release/zabbix-release_<wersja>-<numer>+$OS_NAME${OS_VERSION//./}_all.deb"
    elif [[ $OS_NAME == "centos" || $OS_NAME == "rhel" ]]; then
        echo "https://repo.zabbix.com/zabbix/<wersja>/$OS_NAME/$OS_VERSION/x86_64/zabbix-release-<wersja>-<numer>.el${OS_VERSION%%.*}.noarch.rpm"
    else
        echo "Nie udało się określić formatu linku dla tego systemu."
    fi
    echo ""
}

# Funkcja generująca klucz PSK
generate_psk() {
    read -p "Podaj identyfikator PSK (np. PSK001): " PSK_ID
    PSK_FILE="/etc/zabbix/zabbix_agent2.psk"

    # Generowanie 256-bitowego klucza PSK za pomocą OpenSSL
    PSK_KEY=$(openssl rand -hex 32)

    # Zapis klucza PSK do pliku
    echo "Zapisywanie klucza PSK w $PSK_FILE..."
    echo "$PSK_KEY" > $PSK_FILE
    chmod 640 $PSK_FILE
    chown zabbix:zabbix $PSK_FILE

    # Wyświetlenie informacji o identyfikatorze i kluczu PSK
    echo ""
    echo "===== Wygenerowane dane PSK ====="
    echo "Identyfikator PSK: $PSK_ID"
    echo "Klucz PSK: $PSK_KEY"
    echo "Plik PSK zapisany w: $PSK_FILE"
    echo "================================="
    echo ""

    # Zapis danych do pliku dla ułatwienia kopiowania
    PSK_OUTPUT_FILE="/tmp/psk_info_${PSK_ID}.txt"
    cat <<EOF > $PSK_OUTPUT_FILE
Identyfikator PSK: $PSK_ID
Klucz PSK: $PSK_KEY
Plik PSK: $PSK_FILE
EOF
    echo "Dane PSK zostały zapisane w pliku: $PSK_OUTPUT_FILE"
}

# Funkcja instalacji Zabbix Agent 2
install_zabbix_agent2() {
    # Poproś użytkownika o podanie linku do pliku .deb lub .rpm
    read -p "Podaj URL do pliku z Zabbix Agent 2: " ZABBIX_PACKAGE_URL

    echo "Pobieranie Zabbix Agent 2 z podanego linku..."

    # Pobranie pliku .deb lub .rpm z podanego URL
    wget -q $ZABBIX_PACKAGE_URL -O zabbix_agent2.pkg

    # Instalacja pobranego pakietu
    if [[ $OS_NAME == "ubuntu" || $OS_NAME == "debian" ]]; then
        dpkg -i zabbix_agent2.pkg
        apt update
        apt install -f -y
    elif [[ $OS_NAME == "centos" || $OS_NAME == "rhel" ]]; then
        yum install -y zabbix_agent2.pkg
    else
        echo "Nieobsługiwany system operacyjny. Instalacja Zabbix Agent 2 przerwana."
        exit 1
    fi

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
    echo "Aktualizacja pliku $ZABBIX_CONFIG..."
    sed -i "s/^Server=.*/Server=$ZABBIX_SERVER_IP/" $ZABBIX_CONFIG
    sed -i "s/^ServerActive=.*/ServerActive=$ZABBIX_ACTIVE_SERVER_IP:$ACTIVE_PORT/" $ZABBIX_CONFIG
    sed -i "s/^Hostname=.*/Hostname=$HOSTNAME/" $ZABBIX_CONFIG
    sed -i "s/^# ListenPort=.*/ListenPort=$PASSIVE_PORT/" $ZABBIX_CONFIG
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
    detect_system
    install_zabbix_agent2
    generate_psk
    configure_zabbix_agent2
    restart_zabbix_agent2
    echo "Instalacja i konfiguracja Zabbix Agent 2 z szyfrowaniem PSK zakończona pomyślnie."
}

# Uruchomienie głównej funkcji
main
