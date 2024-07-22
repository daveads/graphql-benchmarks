const { execSync, exec } = require('child_process');
const fs = require('fs');
const path = require('path');

function killServerOnPort(port) {
  return new Promise((resolve, reject) => {
    exec(`lsof -ti:${port}`, (error, stdout, stderr) => {
      if (error) {
        // If lsof doesn't find any process, it returns an error. This is not a problem for us.
        console.log(`No process found running on port ${port}`);
        resolve();
        return;
      }

      const pids = stdout.trim().split('\n');
      if (pids.length > 0) {
        pids.forEach(pid => {
          try {
            process.kill(parseInt(pid));
            console.log(`Killed process ${pid} running on port ${port}`);
          } catch (err) {
            console.error(`Failed to kill process ${pid}: ${err.message}`);
          }
        });
      }
      resolve();
    });
  });
}

function runBenchmark(serviceScript) {
  return new Promise((resolve, reject) => {
    killServerOnPort(8000)
      .then(() => {
        execSync('sleep 5');

        const benchmarks = [1, 2, 3];
        let graphqlEndpoint = 'http://localhost:8000/graphql';

        if (serviceScript.includes('hasura')) {
          execSync(`bash ${serviceScript}`, { stdio: 'inherit' });
          graphqlEndpoint = `http://${execSync("docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' graphql-engine").toString().trim()}:8080/v1/graphql`;
        } else {
          execSync(`bash ${serviceScript} &`, { stdio: 'inherit' });
        }

        execSync('sleep 15');

        const sanitizedServiceScriptName = serviceScript.replace(/\//g, '_');

        benchmarks.forEach(bench => {
          const benchmarkScript = 'wrk/bench.sh';
          
          execSync(`bash test_query${bench}.sh ${graphqlEndpoint}`);

          // Warmup runs
          execSync(`bash ${benchmarkScript} ${graphqlEndpoint} ${bench} > /dev/null`);
          execSync('sleep 1');
          execSync(`bash ${benchmarkScript} ${graphqlEndpoint} ${bench} > /dev/null`);
          execSync('sleep 1');
          execSync(`bash ${benchmarkScript} ${graphqlEndpoint} ${bench} > /dev/null`);
          execSync('sleep 1');

          // Three benchmark runs for each bench
          for (let i = 1; i <= 3; i++) {
            const resultFile = `bench${bench}_result${i}_${sanitizedServiceScriptName}.txt`;
            console.log(`Running benchmark ${bench}, test ${i} for ${serviceScript}`);
            execSync(`bash ${benchmarkScript} ${graphqlEndpoint} ${bench} > ${resultFile}`);
          }
        });

        resolve(sanitizedServiceScriptName);
      })
      .catch(reject);
  });
}

async function main() {
  const benchResults = {
    1: [],
    2: [],
    3: []
  };

  await killServerOnPort(3000);
  execSync('sh nginx/run.sh');

  if (fs.existsSync('results.md')) {
    fs.unlinkSync('results.md');
  }

  const serviceName = process.argv[2];
  if (!serviceName) {
    console.error('Please provide a service name as an argument.');
    process.exit(1);
  }

  const serviceScript = `graphql/${serviceName}/run.sh`;
  
  if (!fs.existsSync(serviceScript)) {
    console.error(`Service script not found: ${serviceScript}`);
    process.exit(1);
  }

  try {
    const sanitizedServiceScriptName = await runBenchmark(serviceScript);
    
    if (serviceName === 'apollo_server') {
      process.chdir('graphql/apollo_server');
      execSync('npm stop');
      process.chdir('../..');
    } else if (serviceName === 'hasura') {
      execSync('bash graphql/hasura/kill.sh');
    }

    [1, 2, 3].forEach(bench => {
      for (let i = 1; i <= 3; i++) {
        benchResults[bench].push(`bench${bench}_result${i}_${sanitizedServiceScriptName}.txt`);
      }
    });

    
main().catch(error => console.error('An error occurred:', error));
