#!/bin/bash

# Update system
apt update
apt -y dist-upgrade && apt -y autoremove

# Install required system packages
sudo apt install -y python3 python3-venv python3-pip whiptail

# Function to display error message and exit
error_exit() {
    echo "An error occurred during installation. Please check the output above for more details."
    exit 1
}

# Trap any errors and call the error_exit function
trap error_exit ERR

# Prompt user for domain name
DOMAIN=$(whiptail --inputbox "Enter your domain name:" 8 60 3>&1 1>&2 2>&3)

# Prompt user for email
EMAIL=$(whiptail --inputbox "Enter your email:" 8 60 3>&1 1>&2 2>&3)

export DOMAIN
export EMAIL

# Debug: Print the value of the DOMAIN variable
echo "Domain: ${DOMAIN}"

# Clone the repo
git clone https://github.com/glenn-sorrentino/warn-dashboard.git
cd warn-dashboard

# Download the XLS file
wget -O warn_report.xlsx "https://edd.ca.gov/siteassets/files/jobs_and_training/warn/warn_report.xlsx"

# Create a virtual environment and activate it
python3 -m venv venv
source venv/bin/activate

# Install required packages
pip install Flask pandas openpyxl

# Check if the application is running and listening on the expected address and port
sleep 5
if ! netstat -tuln | grep -q '127.0.0.1:5000'; then
    echo "The application is not running as expected. Please check the application logs for more details."
    error_exit
fi

# Enable the Tor hidden service
sudo ln -sf /etc/nginx/sites-available/warn-dashboard.nginx /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# Configure Nginx
cat > /etc/nginx/sites-available/warn-dashboard.nginx << EOL
server {
    listen 80;
    server_name ${DOMAIN};
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
    
        # add_header Strict-Transport-Security "max-age=63072000; includeSubdomains";
        # add_header X-Frame-Options DENY;
        # add_header X-Content-Type-Options nosniff;
        # add_header Content-Security-Policy "default-src 'self'; frame-ancestors 'none'";
        # add_header Permissions-Policy "geolocation=(), midi=(), notifications=(), push=(), sync-xhr=(), microphone=(), camera=(), magnetometer=(), gyroscope=(), speaker=(), vibrate=(), fullscreen=(), payment=(), interest-cohort=()";
        # add_header Referrer-Policy "no-referrer";
        # add_header X-XSS-Protection "1; mode=block";
}
EOL

# Configure Nginx
cat > /etc/nginx/nginx.conf << EOL
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;
events {
        worker_connections 768;
        # multi_accept on;
}
http {
        ##
        # Basic Settings
        ##
        sendfile on;
        tcp_nopush on;
        types_hash_max_size 2048;
        # server_tokens off;
        # server_names_hash_bucket_size 64;
        # server_name_in_redirect off;
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        ##
        # SSL Settings
        ##
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # Dropping SSLv3, ref: POODLE
        ssl_prefer_server_ciphers on;
        ##
        # Logging Settings
        ##
        # access_log /var/log/nginx/access.log;
        error_log /var/log/nginx/error.log;
        ##
        # Gzip Settings
        ##
        gzip on;
        # gzip_vary on;
        # gzip_proxied any;
        # gzip_comp_level 6;
        # gzip_buffers 16 8k;
        # gzip_http_version 1.1;
        # gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
        ##
        # Virtual Host Configs
        ##
        include /etc/nginx/conf.d/*.conf;
        include /etc/nginx/sites-enabled/*;
        ##
        # Enable privacy preserving logging
        ##
        geoip_country /usr/share/GeoIP/GeoIP.dat;
        log_format privacy '0.0.0.0 - \$remote_user [\$time_local] "\$request" \$status \$body_bytes_sent "\$http_referer" "-" \$geoip_country_code';

        access_log /var/log/nginx/access.log privacy;
}

EOL

if [ -e "/etc/nginx/sites-enabled/default" ]; then
    rm /etc/nginx/sites-enabled/default
fi
ln -sf /etc/nginx/sites-available/hush-line.nginx /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx || error_exit

# Obtain SSL certificate
certbot --nginx --agree-tos --non-interactive --email ${EMAIL} --agree-tos -d $DOMAIN

# Set up cron job to renew SSL certificate
(crontab -l 2>/dev/null; echo "30 2 * * 1 /usr/bin/certbot renew --quiet") | crontab -

echo "
✅ Installation complete!
                                               
https://$DOMAIN

Have feedback? Send us an email at feedback@scidsg.org.
"

echo "Basic environment and file structure have been created. You can now modify and expand the code as needed."

# Run the Flask application
echo "Starting the Flask application..."
cd warn_dashboard
source venv/bin/activate
python app.py
