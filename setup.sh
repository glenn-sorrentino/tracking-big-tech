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
from flask import Flask, render_template

app = Flask(__name__)

@app.route("/")
def index():
    return render_template("index.html")

if __name__ == "__main__":
    app.run(debug=True)
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
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <h1>WARN Dashboard</h1>
    <div>
        <canvas id="myChart"></canvas>
    </div>
    <script src="/static/main.js"></script>
</body>
</html>
EOL

# Write sample code to static/main.js
cat > static/main.js << EOL
document.addEventListener("DOMContentLoaded", function() {
    const ctx = document.getElementById("myChart").getContext("2d");

    const data = {
        labels: ["Label 1", "Label 2", "Label 3"],
        datasets: [{
            label: "Sample Data",
            data: [10, 20, 30],
            backgroundColor: [
                "rgba(255, 99, 132, 0.2)",
                "rgba(54, 162, 235, 0.2)",
                "rgba(255, 206, 86, 0.2)"
            ],
            borderColor: [
                "rgba(255, 99, 132, 1)",
                "rgba(54, 162, 235, 1)",
                "rgba(255, 206, 86, 1)"
            ],
            borderWidth: 1
        }]
    };

    const options = {
        scales: {
            y: {
                beginAtZero: true
            }
        }
    };

    const myChart = new Chart(ctx, {
        type: "bar",
        data: data,
        options: options
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
