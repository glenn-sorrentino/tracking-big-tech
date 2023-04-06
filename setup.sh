#!/bin/bash

# Update system
apt update
apt -y dist-upgrade && apt -y autoremove

# Install required system packages
sudo apt install -y python3 python3-venv python3-pip

# Create a project directory
mkdir warn_dashboard
cd warn_dashboard

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
</head>
<body>
    <h1>WARN Dashboard</h1>
    <script src="/static/main.js"></script>
</body>
</html>
EOL

# Write sample code to static/main.js
cat > static/main.js << EOL
console.log("Hello, world!");
EOL

# Write sample code to static/styles.css
cat > static/styles.css << EOL
body {
    font-family: Arial, sans-serif;
}
EOL

echo "Basic environment and file structure have been created. You can now modify and expand the code as needed."
