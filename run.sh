#!/bin/bash
trap cleanup SIGTERM SIGINT SIGQUIT SIGHUP ERR

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[33m'
BOLD='\033[1m'
NC='\033[0m'
redsocksPath=/etc/redsocks.conf

if [ -z "$Ports" ]; then
	Ports="80,8080,443"
fi

echo -e "${BOLD}Configuration:${NC}"
echo -e "${YELLOW}PROXY_SERVER= ${GREEN}$PROXY_SERVER${NC}"
echo -e "${YELLOW}PROXY_PORT= ${GREEN}$PROXY_PORT${NC}"
echo -e "${YELLOW}PROXY_Type= ${GREEN}$PROXY_Type${NC}"
echo -e "${YELLOW}Forwarding Ports= ${GREEN}$Ports${NC}"

sed -i "s/vPROXY-SERVER/$PROXY_SERVER/g" $redsocksPath
sed -i "s/vPROXY-PORT/$PROXY_PORT/g" $redsocksPath
sed -i "s/vPROXY-Type/$PROXY_Type/g" $redsocksPath

if [ -n "$PROXY_USERNAME" ] && [ -n "$PROXY_PASSWORD" ]; then
	sed -i '/redsocks {/,/}/ s/}/        login = "'"$PROXY_USERNAME"'";\n}/' $redsocksPath
	sed -i '/redsocks {/,/}/ s/}/        password = "'"$PROXY_PASSWORD"'";\n}/' $redsocksPath
	echo -e "${BOLD}Add Proxy User Authentication to the redsocks.conf configuration file${NC}"
fi

echo -e "${BOLD}Restarting redsocks and redirecting traffic via iptables${NC}"
/etc/init.d/redsocks restart 2>/dev/null

check_iptables_rule() {
	local rule="$1"
	iptables -t nat -C "$rule" 2>/dev/null
	return $?
}

init() {
	iptables -t nat -L redsocks >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		iptables -t nat -N redsocks

		iptables -t nat -A redsocks -d 0.0.0.0/8 -j RETURN
		iptables -t nat -A redsocks -d 10.0.0.0/8 -j RETURN
		iptables -t nat -A redsocks -d 127.0.0.0/8 -j RETURN
		iptables -t nat -A redsocks -d 169.254.0.0/16 -j RETURN
		iptables -t nat -A redsocks -d 172.16.0.0/12 -j RETURN
		iptables -t nat -A redsocks -d 192.168.0.0/16 -j RETURN
		iptables -t nat -A redsocks -d 224.0.0.0/4 -j RETURN
		iptables -t nat -A redsocks -d 240.0.0.0/4 -j RETURN

		IFS=',' read -ra ports <<<"$Ports"
		for port in "${ports[@]}"; do
			iptables -t nat -A redsocks -p tcp --dport "$port" -j REDIRECT --to-port 12345
		done
	fi

	iptables -t nat -S OUTPUT | grep -q '^-A OUTPUT -j redsocks$'
	if [ $? -ne 0 ]; then
		iptables -t nat -A OUTPUT -j redsocks
	fi
}

cleanup() {
	echo -e "${RED} Cleaning up... ${NC}"
	iptables -t nat -D OUTPUT -j redsocks
}

main() {
	init
	# RUN APP
	echo -e "[${YELLOW}$(date "+%Y-%m-%d %H:%M:%S")${NC}]${GREEN} Current IP Address Info: ${NC}"
	echo -e "[${YELLOW}$(date "+%Y-%m-%d %H:%M:%S")${NC}]${GREEN} IPv4: $(curl -s --noproxy "*" -4 ip.sb) ${NC}"
}
main
while true; do sleep 1; done
