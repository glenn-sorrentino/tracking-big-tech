#!/bin/bash

# Update system
apt update
apt -y dist-upgrade && apt -y autoremove

# Install required system packages
sudo apt install -y python3 python3-venv python3-pip nginx git certbot python3-certbot-nginx

# Function to display error message and exit
error_exit() {
    echo "An error occurred during installation. Please check the output above for more details."
    exit 1
}

# Trap any errors and call the error_exit function
trap error_exit ERR

DOMAIN=trackingbig.tech
export DOMAIN

# Debug: Print the value of the DOMAIN variable
echo "Domain: ${DOMAIN}"

# Clone the repo
git clone https://github.com/glenn-sorrentino/warn-dashboard.git

# Download the XLS file
wget -O warn_report.xlsx "https://edd.ca.gov/siteassets/files/jobs_and_training/warn/warn_report.xlsx"

# Create a virtual environment and install required packages
python3 -m venv venv
source venv/bin/activate
pip install Flask 
pip install pandas
pip install openpyxl

# Configure Nginx
cat > /etc/nginx/sites-available/hush-line.nginx << EOL
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
ln -sf /etc/nginx/sites-available/warn-dashboard.nginx /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx || error_exit

# Obtain SSL certificate
certbot --nginx --agree-tos --non-interactive --email demo@scidsg.org --agree-tos -d $DOMAIN

# Set up cron job to renew SSL certificate
(crontab -l 2>/dev/null; echo "30 2 * * 1 /usr/bin/certbot renew --quiet") | crontab -

# Create necessary directories and files
mkdir templates static
touch app.py templates/index.html static/main.js static/styles.css

# Write sample code to app.py
cat > app.py << EOL
from flask import Flask, render_template, jsonify
import pandas as pd
app = Flask(__name__)
def process_data():
    df = pd.read_excel("warn_report.xlsx", engine="openpyxl")
    # Convert "No. Of\nEmployees" column to numeric values
    df["No. Of\nEmployees"] = pd.to_numeric(df["No. Of\nEmployees"], errors='coerce')
    # Group data by company and state
    company_data = df.groupby("Company")["No. Of\nEmployees"].sum().sort_values(ascending=False).head(10)
    state_data = df.groupby("County/Parish")["No. Of\nEmployees"].sum()
    # Convert "Notice\nDate" column to datetime, handling errors with 'coerce'
    df["Notice\nDate"] = pd.to_datetime(df["Notice\nDate"], errors='coerce')
    # Group data by month
    df_2023 = df[df["Notice\nDate"].dt.year == 2023]
    # Group data by month
    month_data = df_2023.groupby(df_2023["Notice\nDate"].dt.to_period("M"))["No. Of\nEmployees"].sum().sort_index()
    # Convert index to the desired format
    formatted_index = month_data.index.to_timestamp().strftime("%b %Y")
    # Create a dictionary from the formatted index and the data
    month_data_dict = dict(zip(formatted_index, month_data))
    # Convert data to JSON serializable format
    processed_data = {
        "company_data": company_data.to_dict(),
        "state_data": state_data.to_dict(),
        "month_data": month_data_dict
    }
    return processed_data
@app.route("/")
def index():
    data = process_data()
    return render_template("index.html", data=data)
@app.route("/data")
def data():
    return jsonify(process_data())
if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0')
EOL

# Write sample code to templates/index.html
cat > templates/index.html << EOL
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WARN Dashboard</title>
    <link rel="stylesheet" href="/static/styles.css">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.7.1/dist/leaflet.css" />
    <script src="https://unpkg.com/leaflet@1.7.1/dist/leaflet.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <h1>WARN Dashboard</h1>
    <div>
        <h2>Top 10 Companies by Layoffs</h2>
        <canvas id="companyBarChart"></canvas>
    </div>
    <div>
        <h2>Layoffs by County</h2>
        <div id="map" style="width: 100%; height: 500px;"></div>
    </div>
    <div>
        <h2>Layoffs by Month (2023)</h2>
        <canvas id="monthLineChart"></canvas>
    </div>
    <script src="/static/main.js"></script>
</body>
</html>
EOL

# Write sample code to static/main.js
cat > static/main.js << EOL
function createBarChart(ctx, labels, data) {
    // Sort labels and data in descending order based on data
    const sortedData = labels.map((label, i) => [label, data[i]])
                              .sort((a, b) => b[1] - a[1]);
    const sortedLabels = sortedData.map(([label, _]) => label);
    const sortedValues = sortedData.map(([_, value]) => value);
    return new Chart(ctx, {
        type: 'bar', // Add this line to specify the chart type
        data: {
            labels: sortedLabels,
            datasets: [{
                label: 'Employees Affected',
                data: sortedValues,
                backgroundColor: 'rgba(75, 192, 192, 0.2)',
                borderColor: 'rgba(75, 192, 192, 1)',
                borderWidth: 1
            }]
        },
        options: {
            scales: {
                y: {
                    beginAtZero: true
                }
            }
        }
    });
}
function createPieChart(ctx, labels, data) {
    return new Chart(ctx, {
        type: 'pie',
        data: {
            labels: labels,
            datasets: [{
                data: data,
                backgroundColor: [
                    'rgba(255, 99, 132, 0.2)',
                    'rgba(255, 206, 86, 0.2)',
                    'rgba(54, 162, 235, 0.2)'
                ],
                borderColor: [
                    'rgba(255, 99, 132, 1)',
                    'rgba(255, 206, 86, 1)',
                    'rgba(54, 162, 235, 1)'
                ],
                borderWidth: 1
            }]
        }
    });
}
function createMap(state_data) {
    console.log('State data:', state_data);
    const map = L.map('map').setView([37.7749, -122.4194], 6);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).addTo(map);
    // Fetch GeoJSON data for California counties
    fetch('https://raw.githubusercontent.com/codeforamerica/click_that_hood/main/public/data/california-counties.geojson')
        .then(response => response.json())
        .then(geojsonData => {
            L.geoJson(geojsonData, {
                onEachFeature: (feature, layer) => {
                    const county_name = feature.properties.name;
                    const formatted_county_name = county_name + " County";
                    const layoffs = state_data[formatted_county_name] || 0;
                    // Log unmatched county names
                    if (!state_data[formatted_county_name]) {
                        console.log(`Unmatched county: ${formatted_county_name}`);
                    }
                    const center = layer.getBounds().getCenter();
                    const circle = L.circle(center, {
                        color: 'blue',
                        fillColor: '#30f',
                        fillOpacity: 0.5,
                        radius: Math.sqrt(layoffs) * 1000
                    }).addTo(map);
                    circle.bindPopup(`<h3>${formatted_county_name}</h3><p>Layoffs: ${layoffs}</p>`);
                }
            });
        });
}
function createLineChart(ctx, labels, data, sortByMonth = false) {
    // Assign an index value to each month if sortByMonth is true
    const monthIndices = sortByMonth ? {
        'Jan': 0, 'Feb': 1, 'Mar': 2, 'Apr': 3, 'May': 4, 'Jun': 5,
        'Jul': 6, 'Aug': 7, 'Sep': 8, 'Oct': 9, 'Nov': 10, 'Dec': 11
    } : null;
    // Sort labels and data based on the month indices
    const sortedData = sortByMonth ? labels.map((label, i) => [label, data[i]])
                                         .sort((a, b) => {
                                             const aMonth = a[0].slice(0, 3);
                                             const bMonth = b[0].slice(0, 3);
                                             const aYear = parseInt(a[0].slice(4));
                                             const bYear = parseInt(b[0].slice(4));
                                             return (aYear - bYear) || (monthIndices[aMonth] - monthIndices[bMonth]);
                                         })
                                   : labels.map((label, i) => [label, data[i]]);
    const sortedLabels = sortedData.map(([label, _]) => label);
    const sortedValues = sortedData.map(([_, value]) => value);
    return new Chart(ctx, {
        type: 'line',
        data: {
            labels: sortedLabels,
            datasets: [{
                label: 'Employees Affected',
                data: sortedValues,
                backgroundColor: 'rgba(75, 192, 192, 0.2)',
                borderColor: 'rgba(75, 192, 192, 1)',
                borderWidth: 1,
                fill: false,
            }]
        },
        options: {
            scales: {
                y: {
                    beginAtZero: true
                }
            }
        }
    });
}
document.addEventListener("DOMContentLoaded", function() {
    fetch('/data')
        .then(response => response.json())
        .then(data => {
            const companyBarCtx = document.getElementById('companyBarChart').getContext('2d');
            const companyLabels = Object.keys(data.company_data);
            const companyData = Object.values(data.company_data);
            createBarChart(companyBarCtx, companyLabels, companyData);
            createMap(data.state_data);
            const monthLineCtx = document.getElementById('monthLineChart').getContext('2d');
            const monthLabels = Object.keys(data.month_data);
            const monthData = Object.values(data.month_data);
            createLineChart(monthLineCtx, monthLabels, monthData, true);
        });
});
EOL

# Write sample code to static/styles.css
cat > static/styles.css << EOL
body {
    font-family: Arial, sans-serif;
}
EOL

echo "
Basic environment and file structure have been created. You can now modify and expand the code as needed.
                                               
https://$DOMAIN
"

# Run the Flask application
echo "Starting the Flask application..."
source venv/bin/activate
python app.py
