"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.parseMetric = parseMetric;
exports.calculateAverage = calculateAverage;
exports.parseServerMetrics = parseServerMetrics;
var child_process_1 = require("child_process");
function parseMetric(file, metric) {
    try {
        var command = "grep \"".concat(metric, "\" \"").concat(file, "\" | awk '{print $2}' | sed 's/ms//'");
        var result = (0, child_process_1.execSync)(command, { encoding: 'utf-8' }).trim();
        return parseFloat(result);
    }
    catch (error) {
        console.error("Error parsing metric from ".concat(file, ": ").concat(error.message));
        return null;
    }
}
function calculateAverage(values) {
    if (values.length === 0)
        return 0;
    var sum = values.reduce(function (a, b) { return a + b; }, 0);
    return sum / values.length;
}
function parseServerMetrics(servers, resultFiles) {
    var serverMetrics = {};
    servers.forEach(function (server, idx) {
        var startIdx = idx * 3;
        var reqSecVals = [];
        var latencyVals = [];
        for (var j = 0; j < 3; j++) {
            var fileIdx = startIdx + j;
            if (fileIdx < resultFiles.length) {
                var reqSec = parseMetric(resultFiles[fileIdx], "Requests/sec");
                var latency = parseMetric(resultFiles[fileIdx], "Latency");
                if (reqSec !== null)
                    reqSecVals.push(reqSec);
                if (latency !== null)
                    latencyVals.push(latency);
            }
        }
        serverMetrics[server] = {
            reqSec: calculateAverage(reqSecVals),
            latency: calculateAverage(latencyVals)
        };
    });
    return serverMetrics;
}
