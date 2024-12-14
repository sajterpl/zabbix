#!/bin/bash

# Poproś użytkownika o podanie identyfikatora PSK
read -p "Podaj identyfikator PSK (domyślnie: ZabbixPSK): " PSK_IDENTITY
PSK_IDENTITY=${PSK_IDENTITY:-ZabbixPSK} # Domyślny identyfikator, jeśli nic nie wpisano

# Ścieżka do pliku klucza PSK
PSK_FILE="/etc/zabbix/psk_${PSK_IDENTITY}.key"
PROXY_CONFIG="/etc/zabbix/zabbix_proxy.conf"

# Tworzenie klucza PSK
echo "Generowanie klucza PSK..."
openssl rand -hex 32 > $PSK_FILE

# Ustawienie odpowiednich uprawnień do pliku PSK
chmod 640 $PSK_FILE
chown zabbix:zabbix $PSK_FILE

# Pobranie wygenerowanego klucza
PSK_KEY=$(cat $PSK_FILE)

# Dodawanie konfiguracji PSK do pliku zabbix_proxy.conf
echo "Aktualizowanie pliku konfiguracyjnego Zabbix Proxy: $PROXY_CONFIG"

if grep -q "TLSConnect=" $PROXY_CONFIG; then
    sed -i "s/^TLSConnect=.*/TLSConnect=psk/" $PROXY_CONFIG
else
    echo "TLSConnect=psk" >> $PROXY_CONFIG
fi

if grep -q "TLSAccept=" $PROXY_CONFIG; then
    sed -i "s/^TLSAccept=.*/TLSAccept=psk/" $PROXY_CONFIG
else
    echo "TLSAccept=psk" >> $PROXY_CONFIG
fi

if grep -q "TLSPSKIdentity=" $PROXY_CONFIG; then
    sed -i "s/^TLSPSKIdentity=.*/TLSPSKIdentity=$PSK_IDENTITY/" $PROXY_CONFIG
else
    echo "TLSPSKIdentity=$PSK_IDENTITY" >> $PROXY_CONFIG
fi

if grep -q "TLSPSKFile=" $PROXY_CONFIG; then
    sed -i "s|^TLSPSKFile=.*|TLSPSKFile=$PSK_FILE|" $PROXY_CONFIG
else
    echo "TLSPSKFile=$PSK_FILE" >> $PROXY_CONFIG
fi

# Restart Zabbix Proxy
echo "Restartowanie usługi Zabbix Proxy..."
systemctl restart zabbix-proxy

# Sprawdzenie statusu Zabbix Proxy
if systemctl status zabbix-proxy | grep -q "active (running)"; then
    echo "Usługa Zabbix Proxy została pomyślnie zrestartowana i działa poprawnie."
else
    echo "Wystąpił problem z restartem usługi Zabbix Proxy. Sprawdź logi: /var/log/zabbix/zabbix_proxy.log"
fi

# Tworzenie danych do wklejenia w serwerze Zabbix
PSK_DATA=$(cat <<EOF
===== Dane do wprowadzenia na serwerze Zabbix =====
PSK Identity: $PSK_IDENTITY
PSK Key: $PSK_KEY
================================================
EOF
)

# Wyświetlenie danych na ekranie
echo ""
echo "$PSK_DATA"
echo ""

# Zapisanie danych do pliku dla łatwego kopiowania
OUTPUT_FILE="/tmp/zabbix_psk_${PSK_IDENTITY}.txt"
echo "$PSK_DATA" > $OUTPUT_FILE

# Informacja o zapisie danych
echo "Dane zostały zapisane w pliku: $OUTPUT_FILE"
echo "Możesz je łatwo skopiować stąd lub wkleić bezpośrednio z powyższych informacji."
