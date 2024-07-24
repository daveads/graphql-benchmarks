const { spawn, execSync } = require('child_process');
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

function spawnProcess(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const process = spawn(command, args, options);
    let output = '';

    process.stdout.on('data', (data) => {
      output += data.toString();
    });

    process.stderr.on('data', (data) => {
      console.error(`Error: ${data}`);
    });

    process.on('close', (code) => {
      if (code === 0) {
        resolve(output);
      } else {
        reject(new Error(`Process exited with code ${code}`));
      }
    });
  });
}

async function runBenchmark(serviceScript) {
  killServerOnPort(8000);
  await spawnProcess('sleep', ['5']);

  const benchmarks = [1, 2, 3];
  
  if (serviceScript.includes('hasura')) {
    await spawnProcess('bash', [serviceScript], { stdio: 'inherit' });
  } else {
    spawn('bash', [serviceScript], { stdio: 'inherit' });
  }

  await spawnProcess('sleep', ['15']);

  let graphqlEndpoint = 'http://localhost:8000/graphql';
  if (serviceScript.includes('hasura')) {
    graphqlEndpoint = 'http://127.0.0.1:8080/v1/graphql';
  }

  const benchmarkPromises = benchmarks.map(async (bench) => {
    const benchmarkScript = 'wrk/bench.sh';
    const sanitizedServiceScriptName = serviceScript.replace(/\//g, '_');
    const resultFiles = [
      `result1_${sanitizedServiceScriptName}.txt`,
      `result2_${sanitizedServiceScriptName}.txt`,
      `result3_${sanitizedServiceScriptName}.txt`
    ];

    await spawnProcess('bash', [`test_query${bench}.sh`, graphqlEndpoint]);

    // Warmup runs
    for (let i = 0; i < 3; i++) {
      await spawnProcess('bash', [benchmarkScript, graphqlEndpoint, bench.toString()], { stdio: 'ignore' });
      await spawnProcess('sleep', ['1']);
    }

    // 3 benchmark runs
    const benchResults = await Promise.all(resultFiles.map(async (resultFile) => {
      console.log(`Running benchmark ${bench} for ${serviceScript}`);
      const outputFile = `bench${bench}_${resultFile}`;
      await spawnProcess('bash', [benchmarkScript, graphqlEndpoint, bench.toString()], { stdio: 'pipe' })
        .then(output => fs.promises.writeFile(outputFile, output));
      return outputFile;
    }));

    return { bench, results: benchResults };
  });

  return Promise.all(benchmarkPromises);
}

async function main() {
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

  killServerOnPort(3000);
  await spawnProcess('sh', ['nginx/run.sh']);

  const results = await runBenchmark(`graphql/${service}/run.sh`);

  if (service === 'apollo_server') {
    process.chdir('graphql/apollo_server');
    await spawnProcess('npm', ['stop']);
    process.chdir('../../');
  } else if (service === 'hasura') {
    await spawnProcess('bash', ['graphql/hasura/kill.sh']);
  }

  console.log('All benchmarks completed. Results:', results);
}

main().catch(error => console.error('Error:', error));