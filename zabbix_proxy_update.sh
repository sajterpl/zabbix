#!/bin/bash

echo "=== Aktualizacja Zabbix Proxy ==="

# Sprawdzanie uprawnień
if [[ $EUID -ne 0 ]]; then
    echo "Uruchom skrypt jako root lub użyj sudo."
    exit 1
fi

# Prośba o link do pliku repozytorium
read -p "Podaj pełny link do pliku repozytorium Zabbix (np. https://repo.zabbix.com/...): " REPO_URL

# Sprawdzanie, czy link został podany
if [[ -z "$REPO_URL" ]]; then
    echo "Nie podano linku. Anulowanie."
    exit 1
fi

# Wykrywanie systemu operacyjnego
if [[ -f /etc/debian_version ]]; then
    OS="debian"
elif [[ -f /etc/redhat-release ]]; then
    OS="redhat"
else
    echo "Nieobsługiwany system operacyjny. Skrypt wspiera tylko Debian/Ubuntu i CentOS/Red Hat."
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
if [[ $OS == "debian" ]]; then
    echo "Instalowanie repozytorium Zabbix na Debian/Ubuntu..."
    dpkg -i "$TEMP_FILE" || { echo "Błąd podczas instalacji pliku repozytorium."; exit 1; }
    apt update
    echo "Aktualizacja Zabbix Proxy..."
    apt install --only-upgrade zabbix-proxy-mysql zabbix-proxy-sqlite3 -y
elif [[ $OS == "redhat" ]]; then
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
