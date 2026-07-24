==================================================
ICECAST2 COMMANDS
==================================================

# Edit the icecast2 configuration file
sudo nano /etc/icecast2/icecast.xml

# Check the icecast2 configuration file
sudo cat /etc/icecast2/icecast.xml

# Restart the icecast2 service
sudo systemctl restart icecast2

# Check the status of the icecast2 service
sudo systemctl status icecast2

# Check the logs of the icecast2 service
sudo journalctl -u icecast2 -f

# Check the logs of the icecast2 service
sudo journalctl -u icecast2 -f

# Check the authentication configuration in the icecast2 configuration file
sudo grep -A20 -B5 authentication /etc/icecast2/icecast.xml

# Check the mount configuration in the icecast2 configuration file
sudo grep -A20 -B5 mount /etc/icecast2/icecast.xml

==================================================
NGINX COMMANDS
==================================================

# Edit the nginx configuration file
sudo nano /etc/nginx/nginx.conf

# Restart the nginx service
sudo systemctl restart nginx

# Check the status of the nginx service
sudo systemctl status nginx

# Check the logs of the nginx service
sudo journalctl -u nginx -f

# Check the logs of the nginx service
sudo journalctl -u nginx -f

# Check the nginx configuration file
sudo nginx -T | grep -A 20 -B 5 "listen 2001"

# Check the nginx configuration file
sudo nginx -t

==================================================
FFMPEG COMMANDS
==================================================

# Edit the ffmpeg configuration file
sudo nano /etc/ffmpeg/ffmpeg.conf

# Restart the ffmpeg service
sudo systemctl restart ffmpeg

# Check the status of the ffmpeg service
sudo systemctl status ffmpeg

# Check the logs of the ffmpeg service
sudo journalctl -u ffmpeg -f

# Check the logs of the ffmpeg service
sudo journalctl -u ffmpeg -f

==================================================
SYSTEMD COMMANDS
==================================================

# Check the status of a systemd service
sudo systemctl status <service-name>

# Check the logs of a systemd service
sudo journalctl -u <service-name> -f

==================================================
POSTGRES COMMANDS
==================================================

# Check the status of the postgres service
sudo systemctl status postgresql

# Check the logs of the postgres service
sudo journalctl -u postgresql -f

# Check the logs of the postgres service
sudo journalctl -u postgresql -f

# Connect to the postgres database
sudo -i -u postgres
psql -h localhost -p 5432 -U postgres -d linkkin_db
exit

==================================================

# Check the ports that are listening
sudo ss -tulpn | grep -E '2001|8010|8011'

==================================================
# After connect BUTT to radio.linkkin.chat:2001, check the logs of the icecast2 service
# Check the logs of the icecast2 service
sudo tail -f /var/log/icecast2/access.log

==================================================

# Check the logs of the icecast2 service
sudo tail -f /var/log/icecast2/error.log

==================================================

# Icecast LISTENER proxy (browser play URLs) — nginx :8089 → 127.0.0.1:8010
sudo cp linkkin-backend/docs/nginx.radio.listeners.conf /etc/nginx/sites-available/radio.linkkin.listeners.conf
sudo ln -sf /etc/nginx/sites-available/radio.linkkin.listeners.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
curl -sI http://127.0.0.1:8089/ | head -5

# Backend .env (same server): ICECAST_ADMIN_URL=http://127.0.0.1:8010
# Web .env: VITE_ICECAST_PUBLIC_URL=http://radio.linkkin.chat:8089
#            VITE_ICECAST_PUBLIC_URL_HTTPS=https://radio.linkkin.chat

==================================================

# HTTPS listener for web.linkkin.chat (mixed content fix) — nginx :443 → Icecast :8010
# Router: forward TCP 443 → this server
sudo certbot certonly --nginx -d radio.linkkin.chat
sudo cp linkkin-backend/docs/nginx.radio.listeners-https.conf /etc/nginx/sites-available/
sudo ln -sf /etc/nginx/sites-available/nginx.radio.listeners-https.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
curl -sI https://radio.linkkin.chat/50f75a32-2766-430b-b149-c7fef0343761.mp3 | head -8

==================================================

curl -v -u source:ep_d3b6906c8cc4f6609956ea342a306dca9500 -T /dev/null \
http://127.0.0.1:2001/50f75a32-2766-430b-b149-c7fef0343761.mp3

# HTTPS listen test (after certbot + nginx :443):
# https://radio.linkkin.chat/50f75a32-2766-430b-b149-c7fef0343761.mp3

==================================================

# api.linkkin.chat — fix 502 (backend down or nginx missing)
# 1) Start API:
cd linkkin-backend && npm run dev
curl -s http://127.0.0.1:8000/health

# 2) nginx + SSL (requires sudo):
sudo certbot certonly --nginx -d api.linkkin.chat
sudo cp linkkin-backend/docs/nginx.api.linkkin.conf /etc/nginx/sites-available/api.linkkin.conf
sudo ln -sf /etc/nginx/sites-available/api.linkkin.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
curl -s https://api.linkkin.chat/health

==================================================

# Mobile app — Live channels / API URL (web uses VITE_API_URL; mobile uses env_defaults.env)
# After changing assets/env_defaults.env, rebuild and reinstall the APK:
#   cd linkkin-mobile && flutter pub get && flutter run
# Production API URL (works on Wi‑Fi and mobile data):
#   API_BASE_URL=https://api.linkkin.chat
# Same-network dev on a physical phone:
#   API_BASE_URL=http://192.168.0.108:8000
# Login screen → API URL field can override without rebuild (tap Save).
# Stale LAN URLs are auto-migrated to production on next app start when env is HTTPS.

sudo certbot certonly --nginx -d radio.linkkin.chat

# Copy the nginx configuration file
sudo cp linkkin-backend/docs/nginx.radio.listeners-https.conf \
  /etc/nginx/sites-available/

# Link the nginx configuration file
sudo ln -sf \
  /etc/nginx/sites-available/nginx.radio.listeners-https.conf \
  /etc/nginx/sites-enabled/

==================================================
Category tabs

Tab	Jobs
All jobs: Everything
Media & Cloudinary: chat cleanup, orphan sweep, status, AI images, migration
chat cleanup, orphan sweep, status, AI images, migration
Radio: radio audio cleanup
Logs & disk: log files cleanup
System: migration tasks

==================================================
LinkKin-backend Setup Commands
==================================================
Developer:
--------------------------------------------------
cd linkkin-backend   # or web, admin, support, mobile, radio
./setup.sh           # first time only
./doctor.sh          # verify environment
./run.sh             # start dev server
./update.sh          # after git pull (GIT_PULL=1 ./update.sh to auto-pull)
--------------------------------------------------
Production:
--------------------------------------------------
sudo ./scripts/server-setup.sh   # fresh Ubuntu server
GIT_PULL=1 ./deploy.sh           # pull + migrate + PM2 restart
./backup.sh                      # DB + uploads + logs
--------------------------------------------------

==================================================
Complete LinkKin-Project Setup Commands
==================================================
cd /home/hmd/liveProjects/linkkin
./bootstrap.sh          # clone (if needed) + setup + doctor
./linkkin-run.sh        # dev stack start
./health.sh             # live checks

--------------------------------------------------

USE_TMUX=1 ./linkkin-run.sh     # tmux sessionలో start
GIT_PULL=0 ./linkkin-update.sh  # pull skip
./version.sh                    # bug reportsకు versions
./env-check.sh                  # deployment ముందు env diff

==================================================

Usage
--------------------------------------------------
cd linkkin-setup
./bootstrap.sh
./linkkin-run.sh

--------------------------------------------------
Push to GitHub
--------------------------------------------------
Files staged ఉన్నాయి. Commit + push:

cd linkkin-setup
git commit -m "Initial linkkin-setup: workspace ops + linkkin-radio"
git push -u origin main
--------------------------------------------------
Remote: git@github.com:vinaymdk/linkkin-setup.git
--------------------------------------------------
కొత్త machineలో:
--------------------------------------------------

git clone git@github.com:vinaymdk/linkkin-setup.git
cd linkkin-setup
./bootstrap.sh    # మిగతా repos auto-clone
--------------------------------------------------

<!-- Build APK for development with environment variables (API_BASE_URL and PUSH_HMAC_SECRET) - START -->
flutter run --dart-define=API_BASE_URL=http://192.168.0.106:8000 --dart-define=PUSH_HMAC_SECRET=my_super_secret
<!-- Build APK for development with environment variables (API_BASE_URL and PUSH_HMAC_SECRET) - END -->

<!-- Build APK for production with environment variables (API_BASE_URL and PUSH_HMAC_SECRET) - START -->
flutter build apk --release \
--dart-define=API_BASE_URL=https://api.linkkin.com \
--dart-define=PUSH_HMAC_SECRET=my_secret
<!-- Build APK for production with environment variables (API_BASE_URL and PUSH_HMAC_SECRET) - END -->

sudo -i -u postgres
psql

psql -h 127.0.0.1 -U postgres -d bhoomisetu_db
psql -h 127.0.0.1 -U postgres -d linkkin_db
