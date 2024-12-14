#!/bin/bash

echo "=== Aktualizacja systemu i Zabbix Proxy ==="

# Sprawdzanie uprawnień
if [[ $EUID -ne 0 ]]; then
    echo "Uruchom skrypt jako root lub użyj sudo."
    exit 1
fi

# Aktualizacja systemu operacyjnego
echo "Aktualizowanie systemu operacyjnego..."
if [[ -f /etc/debian_version ]]; then
    apt update && apt upgrade -y
elif [[ -f /etc/redhat-release ]]; then
    yum update -y
else
    echo "Nieobsługiwany system operacyjny. Aktualizacja systemu pominięta."
fi

# Sprawdzanie obecności `curl`
echo "Sprawdzanie obecności curl..."
if ! command -v curl &> /dev/null; then
    echo "curl nie jest zainstalowany. Instalowanie curl..."
    if [[ -f /etc/debian_version ]]; then
        apt install curl -y
    elif [[ -f /etc/redhat-release ]]; then
        yum install curl -y
    else
        echo "Nieobsługiwany system operacyjny. Nie można zainstalować curl."
        exit 1
    fi
fi

# Wykrywanie systemu operacyjnego
echo "Wykrywanie wersji systemu operacyjnego..."
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

# Wyświetlanie szczegółów systemu
echo "Wykryty system: $OS_PRETTY_NAME"
echo "ID systemu: $OS_NAME"
echo "Wersja systemu: $OS_VERSION"
echo ""

# Informacje o wymaganym linku repozytorium
if [[ $OS_NAME == "ubuntu" || $OS_NAME == "debian" ]]; then
    echo "Dla systemów Debian/Ubuntu użyj linku w formacie:"
    echo "https://repo.zabbix.com/zabbix/<wersja>/$(echo $OS_NAME)/pool/main/z/zabbix-release/zabbix-release_<wersja>-<numer>+$(echo $OS_NAME)$(echo $OS_VERSION | tr -d .)_all.deb"
elif [[ $OS_NAME == "centos" || $OS_NAME == "rhel" ]]; then
    echo "Dla systemów CentOS/Red Hat użyj linku w formacie:"
    echo "https://repo.zabbix.com/zabbix/<wersja>/$(echo $OS_NAME)/<wersja>/x86_64/zabbix-release-<wersja>-<numer>.el$(echo $OS_VERSION | cut -d. -f1).noarch.rpm"
else
    echo "Nie udało się określić formatu linku dla tego systemu."
fi

# Prośba o link do pliku repozytorium
echo ""
read -p "Podaj pełny link do pliku repozytorium Zabbix: " REPO_URL

# Sprawdzanie, czy link został podany
if [[ -z "$REPO_URL" ]]; then
    echo "Nie podano linku. Anulowanie."
    exit 1
fi

# Pobieranie i instalacja repozytorium
echo "Pobieranie pliku repozytorium Zabbix z podanego linku..."
TEMP_FILE=$(mktemp)

if ! curl -o "$TEMP_FILE" -fsSL "$REPO_URL"; then
    echo "Nie udało się pobrać pliku. Sprawdź podany link."
    exit 1
fi

# Instalacja repozytorium
if [[ $OS_NAME == "ubuntu" || $OS_NAME == "debian" ]]; then
    echo "Instalowanie repozytorium Zabbix na Debian/Ubuntu..."
    dpkg -i "$TEMP_FILE" || { echo "Błąd podczas instalacji pliku repozytorium."; exit 1; }
    apt update
    echo "Aktualizacja Zabbix Proxy..."
    apt install --only-upgrade zabbix-proxy-mysql zabbix-proxy-sqlite3 -y
elif [[ $OS_NAME == "centos" || $OS_NAME == "rhel" ]]; then
    echo "Instalowanie repozytorium Zabbix na CentOS/Red Hat..."
    yum install -y "$TEMP_FILE" || { echo "Błąd podczas instalacji pliku repozytorium."; exit 1; }
    yum clean all
    echo "Aktualizacja Zabbix Proxy..."
    yum update -y zabbix-proxy-mysql zabbix-proxy-sqlite3
fi

# Restartowanie usługi Zabbix Proxy
echo "Restartowanie usługi Zabbix Proxy..."
systemctl restart zabbix-proxy

# Sprawdzanie statusu Zabbix Proxy
if systemctl status zabbix-proxy | grep -q "active (running)"; then
    echo "Zabbix Proxy zostało pomyślnie zaktualizowane i działa poprawnie."
else
    echo "Wystąpił problem z restartem usługi Zabbix Proxy. Sprawdź logi: /var/log/zabbix/zabbix_proxy.log"
fi

# Usuwanie pliku tymczasowego
rm -f "$TEMP_FILE"

# Weryfikacja wersji Zabbix Proxy
echo "Sprawdzanie zainstalowanej wersji Zabbix Proxy..."
zabbix_proxy_version=$(zabbix_proxy -V 2>/dev/null | grep -oP '(?<=Zabbix proxy ).*')
if [[ -n $zabbix_proxy_version ]]; then
    echo "Zainstalowana wersja Zabbix Proxy: $zabbix_proxy_version"
else
    echo "Nie udało się sprawdzić wersji Zabbix Proxy. Upewnij się, że usługa działa."
fi

echo "=== Aktualizacja zakończona. ==="
