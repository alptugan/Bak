let appData = [];
let filteredData = [];
let charts = {};
let translations = {};
let currentLanguage = "tr";

const chartColors = {
    deepBlue: "#0a2e4a",
    mutedGreen: "#4CAF50", // A standard muted green, will adjust if needed
    cleanWhite: "#f4f7f6",
    lightBlue: "#36A2EB",
    lightGreen: "#98FB98",
    darkGreen: "#2E8B57",
    lightGrey: "#D3D3D3",
};

document.addEventListener("DOMContentLoaded", () => {
    loadConfigAndInitialize();
    loadTranslations();

    const csvFileInput = document.getElementById("csvFileInput");
    const applyFilterButton = document.getElementById("applyFilter");
    const dropZone = document.getElementById("dropZone");
    const modal = document.getElementById("modal");
    const closeModalBtn = document.getElementById("closeModal");
    const langEnBtn = document.getElementById("lang-en");
    const langTrBtn = document.getElementById("lang-tr");

    csvFileInput.addEventListener("change", handleFileUpload);
    applyFilterButton.addEventListener("click", applyDateFilter);

    // Drag and drop event listeners
    dropZone.addEventListener("click", () => csvFileInput.click()); // Click drop zone to open file dialog
    dropZone.addEventListener("dragover", handleDragOver);
    dropZone.addEventListener("dragleave", handleDragLeave);
    dropZone.addEventListener("drop", handleDrop);

    // Event listeners for enlarge buttons
    document.querySelectorAll(".enlarge-btn").forEach((button) => {
        button.addEventListener("click", (event) => {
            event.stopPropagation(); // Prevent event from bubbling up to dropZone click
            const chartId = event.target.getAttribute("data-chart-id");
            enlargeChart(chartId);
        });
    });

    // Event listener for close button
    closeModalBtn.addEventListener("click", closeModal);

    // Language buttons
    langEnBtn.addEventListener("click", () => setLanguage("en"));
    langTrBtn.addEventListener("click", () => setLanguage("tr"));

    // Close modal if clicking outside the modal content
    window.addEventListener("click", (event) => {
        if (event.target === modal) {
            closeModal();
        }
    });
});

function loadTranslations() {
    fetch("languages.json")
        .then((response) => response.json())
        .then((data) => {
            translations = data;
            setLanguage(currentLanguage); // Set default language
        })
        .catch((error) => console.error("Error loading translations:", error));
}

function setLanguage(lang) {
    currentLanguage = lang;
    document.querySelectorAll("[data-lang-key]").forEach((elem) => {
        const key = elem.getAttribute("data-lang-key");
        if (translations[lang] && translations[lang][key]) {
            elem.textContent = translations[lang][key];
        }
    });

    // Update active class on buttons
    document.getElementById("lang-en").classList.toggle("active", lang === "en");
    document.getElementById("lang-tr").classList.toggle("active", lang === "tr");

    if (filteredData.length > 0) {
        renderCharts();
    }
}

function loadConfigAndInitialize() {
    fetch("config.json")
        .then((response) => response.json())
        .then((config) => {
            const dropZone = document.getElementById("dropZone");
            if (config.showDropZone) {
                dropZone.style.display = "flex";
            } else {
                dropZone.style.display = "none";
                loadDefaultCSV();
            }
        })
        .catch((error) => {
            console.error("Error loading config.json:", error);
            // Fallback behavior if config.json is missing or invalid
            const dropZone = document.getElementById("dropZone");
            dropZone.style.display = "flex";
        });
}

function loadDefaultCSV() {
    fetch("file_data.csv")
        .then((response) => {
            if (!response.ok) {
                throw new Error("Network response was not ok " + response.statusText);
            }
            return response.text();
        })
        .then((data) => {
            parseData(data, () => {
                updateDateRangeInputs();
                renderCharts();
            });
        })
        .catch((error) => console.error("Error loading initial CSV:", error));
}

function handleFileUpload(event) {
    const file = event.target.files[0];
    if (file) {
        fileNameDisplay.textContent = `File: ${file.name}`;
        parseData(file, () => {
            updateDateRangeInputs();
            renderCharts();
        });
    }
}

function handleDragOver(event) {
    event.preventDefault(); // Prevent default to allow drop
    event.stopPropagation();
    event.currentTarget.classList.add("hover");
}

function handleDragLeave(event) {
    event.preventDefault();
    event.stopPropagation();
    event.currentTarget.classList.remove("hover");
}

function handleDrop(event) {
    event.preventDefault();
    event.stopPropagation();
    event.currentTarget.classList.remove("hover");

    const files = event.dataTransfer.files;
    if (files.length > 0) {
        const file = files[0];
        if (file.name.endsWith(".csv")) {
            fileNameDisplay.textContent = `File: ${file.name}`;
            parseData(file, () => {
                updateDateRangeInputs();
                renderCharts();
            });
        } else {
            alert("Please drop a CSV file.");
            fileNameDisplay.textContent = "Invalid file type. Please drop a CSV file.";
            console.error("Invalid file type dropped:", file.name);
        }
    }
}

function parseData(fileOrString, onComplete) {
    appData = []; // Reset data
    filteredData = [];

    Papa.parse(fileOrString, {
        worker: true, // Use a web worker for performance
        header: true,
        dynamicTyping: true,
        step: (results) => {
            const row = results.data;
            if (row && row.DATE) {
                // Preprocess each row as it's parsed
                let dateTimeString = `${row.DATE} ${row.TIME ? row.TIME.replace(/-/g, ":") : "00:00:00"}`;
                const dateObj = moment(dateTimeString, "YYYY-MM-DD HH:mm:ss").toDate();

                if (!isNaN(dateObj.getTime())) {
                    row.date = dateObj;
                    row.hour = dateObj.getHours();
                    row.dayOfWeek = dateObj.getDay(); // 0 for Sunday
                    row.month = dateObj.getMonth(); // 0 for January
                    appData.push(row); // Add processed row to data
                } else {
                    // Silently skip rows with invalid dates to avoid console spam on large files
                    // console.warn("Skipping row with invalid date:", row);
                }
            }
        },
        complete: () => {
            filteredData = [...appData]; // Initially, filtered data is all data
            if (onComplete) {
                onComplete();
            }
        },
        error: (error) => {
            console.error("Error parsing CSV:", error.message);
            alert("Error parsing CSV: " + error.message);
        },
    });
}

function updateDateRangeInputs() {
    if (appData.length === 0) return;

    const dates = appData.map((d) => d.date.getTime());
    const minDate = new Date(Math.min(...dates));
    const maxDate = new Date(Math.max(...dates));

    const formatDate = (date) => date.toISOString().split("T")[0];

    document.getElementById("startDate").value = formatDate(minDate);
    document.getElementById("endDate").value = formatDate(maxDate);
}

function applyDateFilter() {
    const startDate = new Date(document.getElementById("startDate").value);
    const endDate = new Date(document.getElementById("endDate").value);

    // Set time to start/end of day for accurate filtering
    startDate.setHours(0, 0, 0, 0);
    endDate.setHours(23, 59, 59, 999);

    filteredData = appData.filter((row) => {
        // Use the preprocessed row.date for filtering
        return row.date >= startDate && row.date <= endDate;
    });
    renderCharts();
}

function renderCharts() {
    updateSummary();
    renderDailyUsageChart();
    renderHourlyUsageHeatmap();
    renderDayOfWeekUsageChart();
    renderCumulativeUsageChart();
    renderMonthlyUsageChart();
}

function updateSummary() {
    const totalImages = filteredData.length;
    document.getElementById("totalImages").textContent = totalImages;

    if (filteredData.length === 0) {
        document.getElementById("avgDailyImages").textContent = 0;
        return;
    }

    const uniqueDays = new Set(filteredData.map((d) => d.date.toISOString().split("T")[0])).size;
    const avgDailyImages = totalImages / uniqueDays;
    document.getElementById("avgDailyImages").textContent = avgDailyImages.toFixed(2);
}

function renderDailyUsageChart() {
    const dailyCounts = filteredData.reduce((acc, row) => {
        const dateStr = row.date.toISOString().split("T")[0];
        acc[dateStr] = (acc[dateStr] || 0) + 1;
        return acc;
    }, {});

    const sortedDates = Object.keys(dailyCounts).sort();
    const data = sortedDates.map((date) => dailyCounts[date]);

    const ctx = document.getElementById("dailyUsageChart").getContext("2d");
    if (charts.dailyUsageChart) charts.dailyUsageChart.destroy();
    charts.dailyUsageChart = new Chart(ctx, {
        type: "line",
        data: {
            labels: sortedDates,
            datasets: [
                {
                    label: translations[currentLanguage].dailyUsageLabel,
                    data: data,
                    borderColor: chartColors.deepBlue,
                    backgroundColor: "rgba(10, 46, 74, 0.2)",
                    fill: true,
                    tension: 0.1,
                },
            ],
        },
        options: {
            responsive: true,
            scales: {
                x: {
                    type: "time",
                    time: {
                        unit: "day",
                        tooltipFormat: "MMM D, YYYY",
                    },
                    title: {
                        display: true,
                        text: translations[currentLanguage].dateAxisLabel,
                    },
                },
                y: {
                    beginAtZero: true,
                    title: {
                        display: true,
                        text: translations[currentLanguage].imageCountAxisLabel,
                    },
                },
            },
            plugins: {
                tooltip: {
                    callbacks: {
                        title: function (context) {
                            return context[0].label;
                        },
                        label: function (context) {
                            return `${translations[currentLanguage].tooltipImages}: ${context.raw}`;
                        },
                    },
                },
            },
        },
    });
}

function renderHourlyUsageHeatmap() {
    const hourlyCounts = {}; // { 'YYYY-MM-DD': { '0': count, '1': count, ... } }
    filteredData.forEach((row) => {
        const dateStr = row.date.toISOString().split("T")[0];
        if (!hourlyCounts[dateStr]) {
            hourlyCounts[dateStr] = Array(24).fill(0);
        }
        hourlyCounts[dateStr][row.hour]++;
    });

    const sortedDates = Object.keys(hourlyCounts).sort();
    const hours = Array.from({ length: 24 }, (_, i) => i); // 0 to 23

    const datasets = hours.map((hour) => {
        return {
            label: `${translations[currentLanguage].hourLabel} ${hour}`,
            data: sortedDates.map((date) => hourlyCounts[date][hour] || 0),
            backgroundColor: (context) => {
                const value = context.raw;
                const maxVal = Math.max(...Object.values(hourlyCounts).flatMap(Object.values));
                const intensity = value / maxVal;
                // Interpolate between cleanWhite and deepBlue
                const r = Math.floor(255 + (10 - 255) * intensity);
                const g = Math.floor(255 + (46 - 255) * intensity);
                const b = Math.floor(255 + (74 - 255) * intensity);
                return `rgb(${r}, ${g}, ${b})`;
            },
            borderColor: chartColors.deepBlue,
            borderWidth: 0.5,
        };
    });

    const ctx = document.getElementById("hourlyUsageChart").getContext("2d");
    if (charts.hourlyUsageChart) charts.hourlyUsageChart.destroy();
    charts.hourlyUsageChart = new Chart(ctx, {
        type: "bar",
        data: {
            labels: sortedDates,
            datasets: datasets,
        },
        options: {
            indexAxis: "y", // Make it a horizontal bar chart for heatmap effect
            responsive: true,
            scales: {
                x: {
                    stacked: true,
                    title: {
                        display: true,
                        text: translations[currentLanguage].imageCountAxisLabel,
                    },
                },
                y: {
                    stacked: true,
                    type: "time", // Use time scale for y-axis to correctly display dates
                    time: {
                        unit: "day",
                        tooltipFormat: "MMM D, YYYY",
                    },
                    title: {
                        display: true,
                        text: translations[currentLanguage].dateAxisLabel,
                    },
                },
            },
            plugins: {
                tooltip: {
                    callbacks: {
                        title: function (context) {
                            return `${translations[currentLanguage].dateAxisLabel}: ${context[0].label}`;
                        },
                        label: function (context) {
                            const hour = context.dataset.label;
                            const count = context.raw;
                            return `${hour}: ${count} ${translations[currentLanguage].tooltipImages}`;
                        },
                    },
                },
            },
        },
    });
}

function renderDayOfWeekUsageChart() {
    const dayNames = translations[currentLanguage].dayNames;
    const dayCounts = Array(7).fill(0); // 0-6 for days of week

    filteredData.forEach((row) => {
        dayCounts[row.dayOfWeek]++;
    });

    const ctx = document.getElementById("dayOfWeekChart").getContext("2d");
    if (charts.dayOfWeekChart) charts.dayOfWeekChart.destroy();
    charts.dayOfWeekChart = new Chart(ctx, {
        type: "bar",
        data: {
            labels: dayNames,
            datasets: [
                {
                    label: translations[currentLanguage].imagesGeneratedLabel,
                    data: dayCounts,
                    backgroundColor: chartColors.deepBlue,
                    borderColor: chartColors.deepBlue,
                    borderWidth: 1,
                },
            ],
        },
        options: {
            responsive: true,
            scales: {
                y: {
                    beginAtZero: true,
                    title: {
                        display: true,
                        text: translations[currentLanguage].imageCountAxisLabel,
                    },
                },
            },
        },
    });
}

function renderCumulativeUsageChart() {
    const dailyCounts = filteredData.reduce((acc, row) => {
        const dateStr = row.date.toISOString().split("T")[0];
        acc[dateStr] = (acc[dateStr] || 0) + 1;
        return acc;
    }, {});

    const sortedDates = Object.keys(dailyCounts).sort();
    let cumulativeSum = 0;
    const cumulativeData = sortedDates.map((date) => {
        cumulativeSum += dailyCounts[date];
        return cumulativeSum;
    });

    const ctx = document.getElementById("cumulativeUsageChart").getContext("2d");
    if (charts.cumulativeUsageChart) charts.cumulativeUsageChart.destroy();
    charts.cumulativeUsageChart = new Chart(ctx, {
        type: "line",
        data: {
            labels: sortedDates,
            datasets: [
                {
                    label: translations[currentLanguage].cumulativeImagesLabel,
                    data: cumulativeData,
                    borderColor: chartColors.darkGreen,
                    backgroundColor: "rgba(46, 139, 87, 0.2)",
                    fill: true,
                    tension: 0.1,
                },
            ],
        },
        options: {
            responsive: true,
            scales: {
                x: {
                    type: "time",
                    time: {
                        unit: "day",
                    },
                    title: {
                        display: true,
                        text: translations[currentLanguage].dateAxisLabel,
                    },
                },
                y: {
                    beginAtZero: true,
                    title: {
                        display: true,
                        text: translations[currentLanguage].cumulativeImagesAxisLabel,
                    },
                },
            },
        },
    });
}

function renderMonthlyUsageChart() {
    const monthNames = translations[currentLanguage].monthNames;
    const monthlyCounts = Array(12).fill(0);

    filteredData.forEach((row) => {
        monthlyCounts[row.month]++;
    });

    const labels = monthlyCounts.map((count, index) => `${monthNames[index]} (${count})`);
    const data = monthlyCounts;

    const ctx = document.getElementById("monthlyUsageChart").getContext("2d");
    if (charts.monthlyUsageChart) charts.monthlyUsageChart.destroy();
    charts.monthlyUsageChart = new Chart(ctx, {
        type: "pie",
        data: {
            labels: labels,
            datasets: [
                {
                    data: data,
                    backgroundColor: [
                        "#0a2e4a", // Deep Blue
                        "#2c5d7c",
                        "#4e8cb0",
                        "#70bad4",
                        "#92e9f8",
                        "#4CAF50", // Muted Green
                        "#66BB6A",
                        "#81C784",
                        "#9CCC65",
                        "#AED581",
                        "#DCE775",
                        "#FFF176",
                    ],
                    hoverOffset: 4,
                },
            ],
        },
        options: {
            responsive: true,
            plugins: {
                legend: {
                    position: "top",
                },
                tooltip: {
                    callbacks: {
                        label: function (context) {
                            let label = context.label || "";
                            if (label) {
                                label += ": ";
                            }
                            if (context.parsed !== null) {
                                label += context.parsed;
                            }
                            return label;
                        },
                    },
                },
            },
        },
    });
}

// Function to handle chart enlargement
function enlargeChart(chartId) {
    const originalChart = charts[chartId];
    if (!originalChart) return;

    // Find the original chart's data and options
    let chartData = null;
    let chartOptions = null;
    let chartType = "";

    // This is a bit of a hacky way to get the chart config.
    // A better approach would be to store chart configurations separately.
    if (chartId === "dailyUsageChart") {
        chartData = originalChart.data;
        chartOptions = originalChart.options;
        chartType = "line";
    } else if (chartId === "hourlyUsageChart") {
        chartData = originalChart.data;
        chartOptions = originalChart.options;
        chartType = "bar";
    } else if (chartId === "dayOfWeekChart") {
        chartData = originalChart.data;
        chartOptions = originalChart.options;
        chartType = "bar";
    } else if (chartId === "cumulativeUsageChart") {
        chartData = originalChart.data;
        chartOptions = originalChart.options;
        chartType = "line";
    } else if (chartId === "monthlyUsageChart") {
        chartData = originalChart.data;
        chartOptions = originalChart.options;
        chartType = "pie";
    }

    if (!chartData || !chartOptions) return;

    // Destroy existing modal chart if it exists
    if (charts.modalChart) {
        charts.modalChart.destroy();
    }

    // Create a new chart instance in the modal
    const modal = document.getElementById("modal"); // Re-get modal element
    const modalChartCanvas = document.getElementById("modalChart"); // Re-get modalChartCanvas element
    const ctx = modalChartCanvas.getContext("2d");
    charts.modalChart = new Chart(ctx, {
        type: chartType,
        data: chartData,
        options: {
            ...chartOptions, // Inherit original options
            responsive: true,
            maintainAspectRatio: false, // Allow chart to fill modal
            plugins: {
                legend: {
                    display: chartOptions.plugins?.legend?.display ?? true,
                    position: chartOptions.plugins?.legend?.position ?? "top",
                },
                tooltip: {
                    enabled: true,
                },
            },
            scales: {
                ...chartOptions.scales,
                x: {
                    ...chartOptions.scales?.x,
                    title: {
                        display: true,
                        text: chartOptions.scales?.x?.title?.text || "X-Axis",
                    },
                },
                y: {
                    ...chartOptions.scales?.y,
                    title: {
                        display: true,
                        text: chartOptions.scales?.y?.title?.text || "Y-Axis",
                    },
                },
            },
        },
    });

    modal.style.display = "block";
}

// Function to close the modal
function closeModal() {
    const modal = document.getElementById("modal"); // Re-get modal element
    modal.style.display = "none";
    if (charts.modalChart) {
        charts.modalChart.destroy();
        charts.modalChart = null;
    }
}