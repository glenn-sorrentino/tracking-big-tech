#!/bin/bash

# Update system
apt update
apt -y dist-upgrade && apt -y autoremove

# Install required system packages
sudo apt install -y python3 python3-venv python3-pip

# Clone the repo
git clone https://github.com/glenn-sorrentino/warn-dashboard.git
cd warn_dashboard

# Download the XLS file
wget -O warn_report.xlsx "https://edd.ca.gov/siteassets/files/jobs_and_training/warn/warn_report.xlsx"

# Create a virtual environment and activate it
python3 -m venv venv
source venv/bin/activate

# Install required packages
pip install Flask pandas openpyxl

echo "Basic environment and file structure have been created. You can now modify and expand the code as needed."

# Run the Flask application
echo "Starting the Flask application..."
cd warn_dashboard
source venv/bin/activate
python app.py
