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
