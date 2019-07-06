# About
This repo aims to be a demonstration of production-ready node containerization with Nginx
Inspired by [DigitalOcean Literature](https://www.digitalocean.com/community/tutorials/how-to-secure-a-containerized-node-js-application-with-nginx-let-s-encrypt-and-docker-compose)

### Requirements
* Assumes Ubuntu 18.04 and Docker 18.09.6

### Todo
* Add instructions for recommended optional steps
  * Create non-root sudo user
  * Setup a firewall with ufw

### Notes
* start webserver `docker-compose up -d`
* renew ssl certs: `sudo docker-compose up --force-recreate --no-deps certbot`
