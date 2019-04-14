#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
# Usage:
# curl https://raw.githubusercontent.com/mixool/script/debian-9/typecho.sh | bash

preinstall_conf(){
    # set domain and email for caddyfile
    echo
    read -p "Please input your domain name for vps:" domain
    read -p "Please input your email:" email
    echo
    echo "---------------------------"
    echo "domain = ${domain}"
    echo "email  = ${email}"
    echo "---------------------------"
    echo
    
    # set CLOUDFLARE_EMAIL and CLOUDFLARE_API_KEY
    echo
    read -p "Please input your CLOUDFLARE_EMAIL:" CLOUDFLARE_EMAIL
    read -p "Please input your CLOUDFLARE_API_KEY:" CLOUDFLARE_API_KEY
    echo
    echo "---------------------------"
    echo "CLOUDFLARE_EMAIL = ${CLOUDFLARE_EMAIL}"
    echo "CLOUDFLARE_API_KEY  = ${CLOUDFLARE_API_KEY}"
    echo "---------------------------"
    echo
}

install_main(){
	apt update
	apt autoremove apache2 -y
	apt install php7.0-cgi php7.0-fpm php7.0-curl php7.0-gd php7.0-mbstring php7.0-xml php7.0-sqlite3 sqlite3 -y
}

install_typecho(){
	wget -O /tmp/typecho.tar.gz https://github.com/typecho/typecho/releases/download/v1.1-17.10.30-release/1.1.17.10.30.-release.tar.gz
	[[ ! -d "/var/www/typecho" ]] && mkdir /var/www/typecho || rm -rf /var/www/typecho/*
	tar zxvf /tmp/typecho.tar.gz -C /var/www/typecho/ && mv /var/www/typecho/build/* /var/www/typecho
	rm -rf /tmp/typecho.tar.gz /var/www/typecho/build
	chmod -Rf 755 /var/www/typecho/* 
	chown www-data:www-data -R /var/www/typecho/* 
}

install_caddy(){
	curl https://getcaddy.com | bash -s personal tls.dns.cloudflare
	mkdir /etc/caddy

cat <<EOF > /etc/caddy/Caddyfile
http://${domain} {
	redir https://${domain}{url}
	}
https://${domain} {
	gzip
	tls ${email}
	root /var/www/typecho
	fastcgi / /run/php/php7.0-fpm.sock php
	rewrite {
		if {path} not_match ^\/admin
		to {path} {path}/ /index.php?{query}
		}
	}
EOF

cat <<EOF > /etc/systemd/system/caddy.service
[Unit]
Description=Caddy HTTP/2 web server
Documentation=https://caddyserver.com/docs
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service
[Service]
ExecStart=/usr/local/bin/caddy -log stdout -conf=/etc/caddy/Caddyfile -email=${email} -agree=true
Restart=always
User=root
Environment=CLOUDFLARE_EMAIL=${CLOUDFLARE_EMAIL}
Environment=CLOUDFLARE_API_KEY=${CLOUDFLARE_API_KEY}
[Install]
WantedBy=multi-user.target
EOF

	systemctl enable caddy && systemctl start caddy
}

preinstall_conf
install_main
install_typecho
install_caddy
