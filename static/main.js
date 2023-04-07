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
                        console.log();
                    }
                    const center = layer.getBounds().getCenter();
                    const circle = L.circle(center, {
                        color: 'blue',
                        fillColor: '#30f',
                        fillOpacity: 0.5,
                        radius: Math.sqrt(layoffs) * 1000
                    }).addTo(map);
                    circle.bindPopup();
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
