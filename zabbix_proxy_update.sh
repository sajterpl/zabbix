#!/bin/bash

echo "=== Aktualizacja Zabbix Proxy ==="

# Sprawdzanie uprawnień
if [[ $EUID -ne 0 ]]; then
    echo "Uruchom skrypt jako root lub użyj sudo."
    exit 1
fi

# Wykrywanie systemu operacyjnego
echo "Wykrywanie wersji systemu operacyjnego..."
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    OS_NAME=$ID
    OS_VERSION=$VERSION_ID
elif [[ -f /etc/redhat-release ]]; then
    OS_NAME="rhel"
    OS_VERSION=$(rpm --eval %{centos_ver})
else
    echo "Nieobsługiwany system operacyjny. Skrypt wspiera tylko Debian/Ubuntu i CentOS/Red Hat."
    exit 1
fi

# Wyświetlanie informacji o systemie
echo "Wykryty system: $OS_NAME $OS_VERSION"
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

# Sprawdzanie st
