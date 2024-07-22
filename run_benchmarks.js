const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Start services and run benchmarks
function killServerOnPort(port) {
  try {
    const pid = execSync(`lsof -t -i:${port}`).toString().trim();
    if (pid) {
      execSync(`kill ${pid}`);
      console.log(`Killed process running on port ${port}`);
    } else {
      console.log(`No process found running on port ${port}`);
    }
  } catch (error) {
    console.error(`Error killing server on port ${port}:`, error.message);
  }
}

const bench1Results = [];
const bench2Results = [];
const bench3Results = [];

killServerOnPort(3000);
execSync('sh nginx/run.sh');

function runBenchmark(serviceScript) {
  killServerOnPort(8000);
  execSync('sleep 5');

  const benchmarks = [1, 2, 3];
  
  if (serviceScript.includes('hasura')) {
    execSync(`bash ${serviceScript}`, { stdio: 'inherit' });
  } else {
    execSync(`bash ${serviceScript} &`, { stdio: 'inherit' });
  }

  execSync('sleep 15');

  let graphqlEndpoint = 'http://localhost:8000/graphql';
  if (serviceScript.includes('hasura')) {
    graphqlEndpoint = 'http://127.0.0.1:8080/v1/graphql';
  }

  for (const bench of benchmarks) {
    const benchmarkScript = 'wrk/bench.sh';
    const sanitizedServiceScriptName = serviceScript.replace(/\//g, '_');
    const resultFiles = [
      `result1_${sanitizedServiceScriptName}.txt`,
      `result2_${sanitizedServiceScriptName}.txt`,
      `result3_${sanitizedServiceScriptName}.txt`
    ];

    execSync(`bash test_query${bench}.sh ${graphqlEndpoint}`);

    // Warmup run
    execSync(`bash ${benchmarkScript} ${graphqlEndpoint} ${bench} > /dev/null`);
    execSync('sleep 1');
    execSync(`bash ${benchmarkScript} ${graphqlEndpoint} ${bench} > /dev/null`);
    execSync('sleep 1');
    execSync(`bash ${benchmarkScript} ${graphqlEndpoint} ${bench} > /dev/null`);
    execSync('sleep 1');

    // 3 benchmark runs
    for (const resultFile of resultFiles) {
      console.log(`Running benchmark ${bench} for ${serviceScript}`);
      const outputFile = `bench${bench}_${resultFile}`;
      execSync(`bash ${benchmarkScript} ${graphqlEndpoint} ${bench} > ${outputFile}`);
      
      if (bench === 1) {
        bench1Results.push(outputFile);
      } else if (bench === 2) {
        bench2Results.push(outputFile);
      } else if (bench === 3) {
        bench3Results.push(outputFile);
      }
    }
  }
}

// Main script
if (process.argv.length < 3) {
  console.log('Usage: node script.js <service_name>');
  console.log('Available services: apollo_server, caliban, netflix_dgs, gqlgen, tailcall, async_graphql, hasura, graphql_jit');
  process.exit(1);
}

const service = process.argv[2];
const validServices = ['apollo_server', 'caliban', 'netflix_dgs', 'gqlgen', 'tailcall', 'async_graphql', 'hasura', 'graphql_jit'];

if (!validServices.includes(service)) {
  console.log(`Invalid service name. Available services: ${validServices.join(', ')}`);
  process.exit(1);
}

if (fs.existsSync('results.md')) {
  fs.unlinkSync('results.md');
}

runBenchmark(`graphql/${service}/run.sh`);

if (service === 'apollo_server') {
  process.chdir('graphql/apollo_server');
  execSync('npm stop');
  process.chdir('../../');
} else if (service === 'hasura') {
  execSync('bash graphql/hasura/kill.sh');
}