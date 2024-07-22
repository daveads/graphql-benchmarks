const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

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

function runBenchmark(serviceScript) {
  killServerOnPort(8000);
  
  // Sleep function
  const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

  // Run the service script
  if (serviceScript.includes('hasura')) {
    execSync(`bash ${serviceScript}`, { stdio: 'inherit' });
  } else {
    execSync(`bash ${serviceScript} &`, { stdio: 'inherit' });
  }

  sleep(15000); // Give some time for the service to start up

  const graphqlEndpoint = serviceScript.includes('hasura') 
    ? 'http://127.0.0.1:8080/v1/graphql'
    : 'http://localhost:8000/graphql';

  const benchmarks = [1, 2, 3];
  const benchmarkScript = 'wrk/bench.sh';
  const sanitizedServiceScriptName = path.basename(serviceScript).replace('/', '_');

  for (const bench of benchmarks) {
    const resultFiles = [
      `result1_${sanitizedServiceScriptName}.txt`,
      `result2_${sanitizedServiceScriptName}.txt`,
      `result3_${sanitizedServiceScriptName}.txt`
    ];

    execSync(`bash test_query${bench}.sh ${graphqlEndpoint}`, { stdio: 'inherit' });

    // Warmup runs
    execSync(`bash ${benchmarkScript} ${graphqlEndpoint} ${bench} > /dev/null`, { stdio: 'inherit' });
    sleep(1000);
    execSync(`bash ${benchmarkScript} ${graphqlEndpoint} ${bench} > /dev/null`, { stdio: 'inherit' });
    sleep(1000);
    execSync(`bash ${benchmarkScript} ${graphqlEndpoint} ${bench} > /dev/null`, { stdio: 'inherit' });
    sleep(1000);

    // 3 benchmark runs
    for (const resultFile of resultFiles) {
      console.log(`Running benchmark ${bench} for ${serviceScript}`);
      execSync(`bash ${benchmarkScript} ${graphqlEndpoint} ${bench} > bench${bench}_${resultFile}`, { stdio: 'inherit' });
    }
  }
}

function main() {
  if (process.argv.length < 3) {
    console.log("Usage: node script.js <service_name>");
    console.log("Available services: apollo_server, caliban, netflix_dgs, gqlgen, tailcall, async_graphql, hasura, graphql_jit");
    process.exit(1);
  }

  const service = process.argv[2];
  const validServices = ["apollo_server", "caliban", "netflix_dgs", "gqlgen", "tailcall", "async_graphql", "hasura", "graphql_jit"];

  if (!validServices.includes(service)) {
    console.log(`Invalid service name. Available services: ${validServices.join(', ')}`);
    process.exit(1);
  }

  killServerOnPort(3000);
  execSync('sh nginx/run.sh', { stdio: 'inherit' });

  runBenchmark(`graphql/${service}/run.sh`);

  if (service === "apollo_server") {
    process.chdir('graphql/apollo_server');
    execSync('npm stop', { stdio: 'inherit' });
    process.chdir('../..');
  } else if (service === "hasura") {
    execSync('bash graphql/hasura/kill.sh', { stdio: 'inherit' });
  }
}

main();