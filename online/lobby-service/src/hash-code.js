// Prints a codeHash for config.json, so the plain code needn't be stored:
//   npm run hash-code -- "my secret code"
import { hashCode } from './crypto.js';

const code = process.argv[2];
if (!code || code.length < 6) {
  console.error('Usage: npm run hash-code -- "<code, 6+ characters>"');
  process.exit(1);
}
console.log(hashCode(code));
