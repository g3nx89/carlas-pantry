#!/usr/bin/env node
/**
 * check-prerequisites.js - Cross-platform prerequisite checker for mobile-mcp
 * Usage: node check-prerequisites.js [android|ios|all]
 *
 * This script provides Windows-compatible validation (unlike the bash version).
 * Uses execFileSync for security (no shell injection possible).
 */

const { execFileSync } = require('child_process');
const os = require('os');

const platform = process.argv[2] || 'all';
const isWindows = os.platform() === 'win32';
const isMac = os.platform() === 'darwin';

const colors = {
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  reset: '\x1b[0m'
};

let errors = 0;

function printStatus(message, status) {
  const statusText = {
    ok: `${colors.green}[OK]${colors.reset}`,
    fail: `${colors.red}[FAIL]${colors.reset}`,
    warn: `${colors.yellow}[WARN]${colors.reset}`
  };
  console.log(`${statusText[status]} ${message}`);
  if (status === 'fail') errors++;
}

function runCommand(cmd, args = [], timeout = 5000) {
  try {
    return execFileSync(cmd, args, { encoding: 'utf8', timeout, stdio: ['pipe', 'pipe', 'pipe'] }).trim();
  } catch {
    return null;
  }
}

function checkCommand(name, cmd = name) {
  const result = runCommand(isWindows ? 'where' : 'which', [cmd]);
  if (result) {
    printStatus(`${name} found: ${result.split('\n')[0]}`, 'ok');
    return true;
  }
  printStatus(`${name} not found`, 'fail');
  return false;
}

console.log('========================================');
console.log('Mobile-MCP Prerequisites Check');
console.log(`Platform: ${platform} | OS: ${os.platform()}`);
console.log('========================================\n');

// Common prerequisites
console.log('--- Common Prerequisites ---');

// Node.js
const nodeVersion = runCommand('node', ['--version']);
if (nodeVersion) {
  const major = parseInt(nodeVersion.replace('v', '').split('.')[0], 10);
  const minVersion = 18;
  if (major >= minVersion) {
    printStatus(`Node.js ${nodeVersion} (>=${minVersion} required)`, 'ok');
  } else {
    printStatus(`Node.js ${nodeVersion} (>=${minVersion} required)`, 'fail');
  }
} else {
  printStatus('Node.js not found', 'fail');
}

// npm
checkCommand('npm');

// npx
checkCommand('npx');

console.log('');

// Android prerequisites
if (platform === 'android' || platform === 'all') {
  console.log('--- Android Prerequisites ---');

  // ANDROID_HOME
  const androidHome = process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT;
  if (androidHome) {
    printStatus(`ANDROID_HOME set: ${androidHome}`, 'ok');
  } else {
    printStatus('ANDROID_HOME not set', 'fail');
    console.log('  Set with: export ANDROID_HOME=/path/to/android/sdk');
  }

  // Java
  const javaVersion = runCommand('java', ['-version']);
  if (javaVersion !== null) {
    printStatus('Java found', 'ok');
  } else {
    // java -version writes to stderr, try detecting via which/where
    if (checkCommand('Java', 'java')) {
      // Already printed status
    }
  }

  // JAVA_HOME
  if (process.env.JAVA_HOME) {
    printStatus(`JAVA_HOME set: ${process.env.JAVA_HOME}`, 'ok');
  } else {
    printStatus('JAVA_HOME not set', 'warn');
  }

  // ADB
  const adbPath = isWindows ? 'adb.exe' : 'adb';
  if (checkCommand('ADB', adbPath)) {
    // Check for devices
    const devices = runCommand('adb', ['devices'], 10000);
    if (devices) {
      const lines = devices.split('\n').filter(l => l && !l.includes('List'));
      if (lines.length > 0) {
        printStatus(`Android device(s) connected: ${lines.length}`, 'ok');
      } else {
        printStatus('No Android devices connected', 'warn');
      }
    }
  }

  console.log('');
}

// iOS prerequisites (macOS only)
if (platform === 'ios' || platform === 'all') {
  console.log('--- iOS Prerequisites ---');

  if (!isMac) {
    printStatus('iOS development requires macOS', 'fail');
  } else {
    // Xcode
    const xcodeVersion = runCommand('xcodebuild', ['-version']);
    if (xcodeVersion && !xcodeVersion.includes('error')) {
      printStatus(`Xcode: ${xcodeVersion.split('\n')[0]}`, 'ok');
    } else {
      printStatus('Xcode not found or not configured', 'fail');
    }

    // xcode-select
    const xcodeSelect = runCommand('xcode-select', ['-p']);
    if (xcodeSelect) {
      printStatus('Xcode command line tools installed', 'ok');
    } else {
      printStatus('Xcode command line tools not installed', 'fail');
      console.log('  Install with: xcode-select --install');
    }

    // simctl - check for booted simulators
    const simctlDevices = runCommand('xcrun', ['simctl', 'list', 'devices'], 15000);
    if (simctlDevices) {
      printStatus('simctl available', 'ok');
      const booted = (simctlDevices.match(/Booted/g) || []).length;
      if (booted > 0) {
        printStatus(`iOS Simulator(s) running: ${booted}`, 'ok');
      } else {
        printStatus('No iOS Simulators running', 'warn');
      }
    }
  }

  console.log('');
}

// Summary
console.log('========================================');
if (errors === 0) {
  console.log(`${colors.green}All critical prerequisites satisfied!${colors.reset}`);
  process.exit(0);
} else {
  console.log(`${colors.red}${errors} critical issue(s) found.${colors.reset}`);
  console.log('Please resolve before using mobile-mcp.');
  process.exit(1);
}
