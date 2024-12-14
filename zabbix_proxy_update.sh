#!/bin/bash

echo "=== Aktualizacja Zabbix Proxy do najnowszej wersji ==="

# Sprawdzanie uprawnień
if [[ $EUID -ne 0 ]]; then
    echo "Uruchom skrypt jako root lub użyj sudo."
    exit 1
fi

# Funkcja do aktualizacji na systemach Debian/Ubuntu
update_debian() {
    echo "Wykryto system Debian/Ubuntu."

    # Pobranie najnowszej wersji repozytorium Zabbix
    echo "Dodawanie repozytorium Zabbix..."
    wget -qO- https://repo.zabbix.com/zabbix/$(lsb_release -cs)/$(lsb_release -cs)/zabbix-release_$(lsb_release -cs)_amd64.deb -O zabbix-release.deb
    dpkg -i zabbix-release.deb
    apt update

    # Aktualizacja Zabbix Proxy
    echo "Aktualizacja Zabbix Proxy..."
    apt install --only-upgrade zabbix-proxy-mysql zabbix-proxy-sqlite3 -y

    # Restart Zabbix Proxy
    echo "Restartowanie Zabbix Proxy..."
    systemctl restart zabbix-proxy

    echo "Aktualizacja zakończona."
}

# Funkcja do aktualizacji na systemach CentOS/Red Hat
update_centos() {
    echo "Wykryto system CentOS/Red Hat."

    # Pobranie repozytorium Zabbix
    echo "Dodawanie repozytorium Zabbix..."
    yum install -y https://repo.zabbix.com/zabbix/$(rpm --eval %{centos_ver})/$(rpm --eval %{centos_ver})/zabbix-release.noarch.rpm
    yum clean all

    # Aktualizacja Zabbix Proxy
    echo "Aktualizacja Zabbix Proxy..."
    yum update -y zabbix-proxy-mysql zabbix-proxy-sqlite3

    # Restart Zabbix Proxy
    echo "Restartowanie Zabbix Proxy..."
    systemctl restart zabbix-proxy

    echo "Aktualizacja zakończona."
}

# Wykrywanie systemu operacyjnego
if [[ -f /etc/debian_version ]]; then
    update_debian
elif [[ -f /etc/redhat-release ]]; then
    update_centos
else
    echo "Nieobsługiwany system operacyjny. Skrypt wspiera tylko Debian/Ubuntu i CentOS/Red Hat."
    exit 1
fi

# Weryfikacja wersji Zabbix Proxy
echo "Sprawdzanie zainstalowanej wersji Zabbix Proxy..."
zabbix_proxy_version=$(zabbix_proxy -V 2>/dev/null | grep -oP '(?<=Zabbix proxy ).*')
if [[ -n $zabbix_proxy_version ]]; then
    echo "Zainstalowana wersja Zabbix Proxy: $zabbix_proxy_version"
else
    echo "Nie udało się sprawdzić wersji Zabbix Proxy. Upewnij się, że usługa działa."
fi

echo "=== Aktualizacja zakończona. ==="
