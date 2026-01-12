const ANSI = {
  reset: "\u001b[0m",
  blue: "\u001b[34m",
  green: "\u001b[32m",
  yellow: "\u001b[33m",
  red: "\u001b[31m"
};

function formatMessage(levelLabel, color, message) {
  console.log(`${color}[${levelLabel}]${ANSI.reset} ${message}`);
}

function logInfo(message) {
  formatMessage("INFO", ANSI.blue, message);
}

function logSuccess(message) {
  formatMessage("SUCCESS", ANSI.green, message);
}

function logWarn(message) {
  formatMessage("WARN", ANSI.yellow, message);
}

function logError(message) {
  formatMessage("ERROR", ANSI.red, message);
}

module.exports = {
  logInfo,
  logSuccess,
  logWarn,
  logError
};

