#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

function extractMetric(file, metric) {
  try {
    return execSync(`grep "${metric}" "${file}" | awk '{print $2}' | sed 's/ms//'`, { encoding: 'utf-8' }).trim();
  } catch (error) {
    console.error(`Error extracting metric from ${file}:`, error);
    return null;
  }
}

function average(values) {
  const sum = values.reduce((a, b) => parseFloat(a) + parseFloat(b), 0);
  return sum / values.length;
}

const formattedServerNames = {
  tailcall: "Tailcall",
  gqlgen: "Gqlgen",
  apollo: "Apollo GraphQL",
  netflixdgs: "Netflix DGS",
  caliban: "Caliban",
  async_graphql: "async-graphql",
  hasura: "Hasura",
  graphql_jit: "GraphQL JIT",
};

const servers = ["apollo", "caliban", "netflixdgs", "gqlgen", "tailcall", "async_graphql", "hasura", "graphql_jit"];
const resultFiles = process.argv.slice(2);
const avgReqSecs = {};
const avgLatencies = {};

// Extract metrics and calculate averages
servers.forEach((server, idx) => {
  const startIdx = idx * 3;
  const reqSecVals = [];
  const latencyVals = [];
  for (let j = 0; j < 3; j++) {
    const fileIdx = startIdx + j;
    const reqSec = extractMetric(resultFiles[fileIdx], "Requests/sec");
    const latency = extractMetric(resultFiles[fileIdx], "Latency");
    if (reqSec !== null) reqSecVals.push(reqSec);
    if (latency !== null) latencyVals.push(latency);
  }
  avgReqSecs[server] = average(reqSecVals);
  avgLatencies[server] = average(latencyVals);
});

// Generating data files for gnuplot
const reqSecData = "/tmp/reqSec.dat";
const latencyData = "/tmp/latency.dat";

fs.writeFileSync(reqSecData, "Server Value\n" + servers.map(server => `${server} ${avgReqSecs[server]}`).join('\n'));
fs.writeFileSync(latencyData, "Server Value\n" + servers.map(server => `${server} ${avgLatencies[server]}`).join('\n'));

let whichBench = 1;
if (resultFiles[0].startsWith("bench2")) {
  whichBench = 2;
} else if (resultFiles[0].startsWith("bench3")) {
  whichBench = 3;
}

const reqSecHistogramFile = `req_sec_histogram${whichBench}.png`;
const latencyHistogramFile = `latency_histogram${whichBench}.png`;

// Plotting using gnuplot
const gnuplotScript = `
set term pngcairo size 1280,720 enhanced font "Courier,12"
set output "${reqSecHistogramFile}"
set style data histograms
set style histogram cluster gap 1
set style fill solid border -1
set xtics rotate by -45
set boxwidth 0.9
set title "Requests/Sec"
stats "${reqSecData}" using 2 nooutput
set yrange [0:STATS_max*1.2]
set key outside right top
plot "${reqSecData}" using 2:xtic(1) title "Req/Sec"

set output "${latencyHistogramFile}"
set title "Latency (in ms)"
stats "${latencyData}" using 2 nooutput
set yrange [0:STATS_max*1.2]
plot "${latencyData}" using 2:xtic(1) title "Latency"
`;

try {
  execSync(`gnuplot -e '${gnuplotScript}'`);
} catch (error) {
  console.error("Error executing gnuplot:", error);
}

// Move PNGs to assets
const assetsDir = path.join(__dirname, "assets");
if (!fs.existsSync(assetsDir)) {
  fs.mkdirSync(assetsDir);
}
fs.renameSync(reqSecHistogramFile, path.join(assetsDir, reqSecHistogramFile));
fs.renameSync(latencyHistogramFile, path.join(assetsDir, latencyHistogramFile));

// Calculate relative performance and build the results table
const serverRPS = {};
servers.forEach((server) => {
  serverRPS[server] = avgReqSecs[server];
});

const sortedServers = Object.keys(serverRPS).sort(
  (a, b) => serverRPS[b] - serverRPS[a]
);
const lastServer = sortedServers[sortedServers.length - 1];
const lastServerReqSecs = avgReqSecs[lastServer];

let resultsTable = "";

if (whichBench === 1) {
  resultsTable += `<!-- PERFORMANCE_RESULTS_START -->\n\n| Query | Server | Requests/sec | Latency (ms) | Relative |\n|-------:|--------:|--------------:|--------------:|---------:|\n| ${whichBench} | \`{ posts { id userId title user { id name email }}}\` |`;
} else if (whichBench === 2) {
  resultsTable += `| ${whichBench} | \`{ posts { title }}\` |`;
} else if (whichBench === 3) {
  resultsTable += `| ${whichBench} | \`{ greet }\` |`;
}

sortedServers.forEach((server) => {
  const formattedReqSecs = avgReqSecs[server].toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  const formattedLatencies = avgLatencies[server].toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  const relativePerformance = (avgReqSecs[server] / lastServerReqSecs).toFixed(2);

  resultsTable += `\n|| [${formattedServerNames[server]}] | \`${formattedReqSecs}\` | \`${formattedLatencies}\` | \`${relativePerformance}x\` |`;
});

if (whichBench === 3) {
  resultsTable += `\n\n<!-- PERFORMANCE_RESULTS_END -->`;
}

const resultsFile = "results.md";
fs.writeFileSync(resultsFile, resultsTable);

if (whichBench === 3) {
  const finalResults = fs
    .readFileSync(resultsFile, "utf-8")
    .replace(/(\r\n|\n|\r)/gm, "\\n");

  const readmePath = "README.md";
  let readmeContent = fs.readFileSync(readmePath, "utf-8");
  const performanceResultsRegex =
    /<!-- PERFORMANCE_RESULTS_START -->[\s\S]*<!-- PERFORMANCE_RESULTS_END -->/;
  if (performanceResultsRegex.test(readmeContent)) {
    readmeContent = readmeContent.replace(
      performanceResultsRegex,
      finalResults
    );
  } else {
    readmeContent += `\n${finalResults}`;
  }
  fs.writeFileSync(readmePath, readmeContent);
}

// Delete the result TXT files
resultFiles.forEach((file) => {
  fs.unlinkSync(file);
});

console.log("Script execution completed.");
