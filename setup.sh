#!/bin/bash

# Update system
apt update
apt -y dist-upgrade && apt -y autoremove

# Install required system packages
sudo apt install -y python3 python3-venv python3-pip

# Create a project directory
mkdir warn_dashboard
cd warn_dashboard

# Download the XLS file
wget -O warn_report.xlsx "https://edd.ca.gov/siteassets/files/jobs_and_training/warn/warn_report.xlsx"

# Create a virtual environment and activate it
python3 -m venv venv
source venv/bin/activate

# Install required packages
pip install Flask pandas openpyxl

# Create necessary directories and files
mkdir templates static
touch app.py templates/index.html static/main.js static/styles.css

# Write sample code to app.py
cat > app.py << EOL
from flask import Flask, render_template, jsonify
import pandas as pd

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
    month_data = df_2023.groupby(df_2023["Notice\nDate"].dt.to_period("M"))["No. Of\nEmployees"].sum()

    # Convert data to JSON serializable format
    processed_data = {
        "company_data": company_data.to_dict(),
        "state_data": state_data.to_dict(),
        "month_data": month_data.to_timestamp().strftime("%b %Y").to_dict()
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
    return new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{
                label: 'Employees Affected',
                data: data,
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
    const map = L.map('map').setView([37.7749, -122.4194], 6);

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).addTo(map);

    // Fetch GeoJSON data for California counties
    fetch('https://raw.githubusercontent.com/codeforamerica/click_that_hood/master/public/data/california-counties.geojson')
        .then(response => response.json())
        .then(geojsonData => {
            L.geoJson(geojsonData, {
                style: feature => {
                    const county_name = feature.properties.name;
                    const layoffs = state_data[county_name] || 0;
                    const fillColor = layoffs > 0 ? 'red' : 'green';

                    return {
                        fillColor: fillColor,
                        fillOpacity: 0.5,
                        weight: 1,
                        color: 'black',
                        opacity: 1
                    };
                },
                onEachFeature: (feature, layer) => {
                    const county_name = feature.properties.name;
                    const layoffs = state_data[county_name] || 0;
                    layer.bindPopup(`<h3>${county_name}</h3><p>Layoffs: ${layoffs}</p>`);
                }
            }).addTo(map);
        });
}

function createLineChart(ctx, labels, data) {
    return new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Employees Affected',
                data: data,
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
  ...
  createMap(data.state_data);
});

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
            createLineChart(monthLineCtx, monthLabels, monthData);
        });
});

EOL

# Write sample code to static/styles.css
cat > static/styles.css << EOL
body {
    font-family: Arial, sans-serif;
}
EOL

echo "Basic environment and file structure have been created. You can now modify and expand the code as needed."

# Run the Flask application
echo "Starting the Flask application..."
cd warn_dashboard
source venv/bin/activate
python app.py

