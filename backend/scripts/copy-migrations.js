const fs = require('fs');
const path = require('path');

const srcDir = path.resolve(__dirname, '../src/core/database/migrations');
const destDir = path.resolve(__dirname, '../dist/core/database/migrations');

if (fs.existsSync(srcDir)) {
  fs.mkdirSync(destDir, { recursive: true });
  const files = fs.readdirSync(srcDir).filter(f => f.endsWith('.sql'));
  for (const file of files) {
    fs.copyFileSync(path.join(srcDir, file), path.join(destDir, file));
  }
  console.log(`Copied ${files.length} SQL migrations to dist/core/database/migrations.`);
}
