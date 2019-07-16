#!/bin/bash
# Generates SSL certificates and Nginx config to utilize them

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

# parse args
while getopts ":d:e:s" opt; do
  case $opt in
    d) domains="$OPTARG"
    ;;
    e) email="$OPTARG" || "" # adding a valid address is strongly recommended
    ;;
    s) staging="y"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

# prompt for args if not passed
if [[ -z $domains ]]; then
  echo -n "domains: "
  read domains
fi

if [[ -z $staging ]]; then
  echo -n "staging (y/n): "
  read staging
fi

# validate staging arg
case "$staging" in
  y|Y ) ;;
  n|N ) ;;
  * ) echo "invalid input";;
esac

rsa_key_size=4096
certbot_path="./volumes/production/certbot"

if [ -d "$certbot_path" ]; then
  read -p "Existing data found for $domains. Continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi

if [ ! -e "$certbot_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$certbot_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$certbot_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/options-ssl-nginx.conf > "$certbot_path/conf/options-ssl-nginx.conf"
  openssl dhparam -out "$certbot_path/conf/ssl-dhparams.pem" $rsa_key_size
  echo
fi

echo "### Creating dummy certificate for $domains ..."
path="/etc/letsencrypt/live/$domains"
mkdir -p "$certbot_path/conf/live/$domains"
sudo docker-compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:1024 -days 1 \
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo

echo "### Generating nginx config ..."
nginx_path="volumes/production/nginx"
cp -f $nginx_path/base.conf-tpl $nginx_path/generated.conf
sed -i "s/%DOMAINS%/$domains/g" $nginx_path/generated.conf
echo

echo "### Starting nginx ..."
sudo docker-compose up --force-recreate -d nginx
echo

echo "### Deleting dummy certificate for $domains ..."
sudo docker-compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domains && \
  rm -Rf /etc/letsencrypt/archive/$domains && \
  rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot
echo

echo "### Requesting Let's Encrypt certificate for $domains ..."
#Join $domains to -d args
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Enable staging mode if needed
if [ $staging != "n" ]; then staging_arg="--staging"; fi

sudo docker-compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot
echo

echo "### Stopping docker services"
sudo docker stop nginx nodejs
echo

echo "### Updating .env file"
echo "mode=production" > .env
