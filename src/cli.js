const path = require("path");
const { loadEnvFromFolder } = require("./envLoader");
const { RemoteBuilder } = require("./remoteBuilder");
const { logInfo, logError } = require("./logger");

function printCliHelp() {
  console.log(`
Usage: expobuild [profile] [options]

Profiles default to "preview". The CLI syncs the current project with a Hetzner build server,
runs \`eas build --local\`, and pulls the artifact into a local \`build-output\` folder.

Options:
  -p, --profile <name>      Override the build profile (default: preview)
  -e, --env-folder <path>   Point to a directory full of env files (default: .env)
  -h, --help                Show this help message
`);
}

function parseArgs(argv) {
  const args = argv.slice(2);
  let profile = "preview";
  let envFolder = ".env";
  let usedProfile = false;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];

    if (arg === "--help" || arg === "-h") {
      printCliHelp();
      process.exit(0);
    }

    if (arg === "--profile" || arg === "-p") {
      const value = args[index + 1];
      if (value && !value.startsWith("-")) {
        profile = value;
        usedProfile = true;
        index += 1;
        continue;
      }
      throw new Error(`Missing profile after ${arg}`);
    }

    if (arg === "--env-folder" || arg === "-e") {
      const value = args[index + 1];
      if (value && !value.startsWith("-")) {
        envFolder = value;
        index += 1;
        continue;
      }
      throw new Error(`Missing env folder after ${arg}`);
    }

    if (!usedProfile && !arg.startsWith("-")) {
      profile = arg;
      usedProfile = true;
    }
  }

  return { profile, envFolder };
}

async function runCli(argv) {
  const { profile, envFolder } = parseArgs(argv);
  const envDirectory = path.resolve(process.cwd(), envFolder);
  logInfo(`Loading environment from ${envDirectory}`);
  const loadedEnv = loadEnvFromFolder(envDirectory);

  Object.entries(loadedEnv).forEach(([key, value]) => {
    if (!(key in process.env)) {
      process.env[key] = value;
    }
  });

  const builderEnv = { ...process.env };
  const builder = new RemoteBuilder(profile, builderEnv);

  try {
    await builder.run();
  } catch (error) {
    logError(error.message);
    throw error;
  }
}

module.exports = { runCli };

