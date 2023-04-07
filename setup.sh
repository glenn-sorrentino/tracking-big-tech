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
