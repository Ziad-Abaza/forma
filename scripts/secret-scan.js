const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Secret scan pattern rules
const SUSPICIOUS_PATTERNS = [
  /AIza[0-9A-Za-z-_]{35}/, // Google API key pattern
  /sk-[a-zA-Z0-9]{32,}/,   // OpenAI secret key pattern
  /-----BEGIN PRIVATE KEY-----/,
  /-----BEGIN RSA PRIVATE KEY-----/,
  /postgres:\/\/[^:]+:[^@]+@/ // Hardcoded connection string with password in source
];

// File types to scan
const SCANNABLE_EXTENSIONS = ['.ts', '.js', '.json', '.md', '.dart', '.yaml', '.yml', '.env.example'];

const IGNORED_PATHS = [
  'node_modules',
  '.git',
  'dist',
  'build',
  '.dart_tool',
  'GEMINI.txt', // Ignored file checked separately
  '.env',       // Untracked local env
  '.env.local'
];

function getAllFiles(dirPath, arrayOfFiles = []) {
  const files = fs.readdirSync(dirPath);

  files.forEach((file) => {
    const fullPath = path.join(dirPath, file);
    const relPath = path.relative(process.cwd(), fullPath);

    if (IGNORED_PATHS.some(ignored => relPath.split(path.sep).includes(ignored)) || relPath === 'scripts/secret-scan.js' || relPath === 'scripts\\secret-scan.js') {
      return;
    }

    if (fs.statSync(fullPath).isDirectory()) {
      arrayOfFiles = getAllFiles(fullPath, arrayOfFiles);
    } else {
      const ext = path.extname(file);
      if (SCANNABLE_EXTENSIONS.includes(ext) || file === '.env.example') {
        arrayOfFiles.push(fullPath);
      }
    }
  });

  return arrayOfFiles;
}

console.log('Running Forma Automated Secret Scanner...');
const files = getAllFiles(process.cwd());
let violations = 0;

// Also read actual key from .env if present, to ensure it never appears anywhere in scannable files
let realKey = null;
if (fs.existsSync('.env')) {
  const content = fs.readFileSync('.env', 'utf8');
  const match = content.match(/GEMINI_API_KEY=(.+)/);
  if (match && match[1].trim().length > 10) {
    realKey = match[1].trim();
  }
}

for (const filePath of files) {
  const content = fs.readFileSync(filePath, 'utf8');
  const relPath = path.relative(process.cwd(), filePath);

  if (realKey && content.includes(realKey)) {
    console.error(`[SECRET VIOLATION] Real API key found in file: ${relPath}`);
    violations++;
  }

  for (const pattern of SUSPICIOUS_PATTERNS) {
    if (pattern.test(content)) {
      // Allow connection strings in .env.example or tests if explicitly mock
      if (filePath.endsWith('.env.example') && pattern.toString().includes('postgres')) {
        continue;
      }
      console.error(`[SECRET VIOLATION] Suspicious secret pattern (${pattern}) found in file: ${relPath}`);
      violations++;
    }
  }
}

// Verify git status does not track GEMINI.txt or .env
try {
  const tracked = execSync('git ls-files GEMINI.txt .env', { encoding: 'utf8' }).trim();
  if (tracked.length > 0) {
    console.error(`[SECRET VIOLATION] Sensitive files tracked by git: ${tracked}`);
    violations++;
  }
} catch (e) {
  // Git command check
}

if (violations > 0) {
  console.error(`\nSecret scan FAILED with ${violations} violation(s).`);
  process.exit(1);
} else {
  console.log(`\nSecret scan PASSED: ${files.length} files scanned. No secrets found.`);
}
