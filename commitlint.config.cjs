// Node 22 stricter ESM JSON loader requires `with { type: "json" }` for
// direct JSON imports. Re-exporting from CJS sidesteps that requirement
// while keeping the human-readable config in commitlint.config.json.
//
// Priority: commitlint discovers config in this order:
//   commitlint.config.cjs  ← this file (loads first)
//   commitlint.config.js
//   package.json `commitlint` field
//   commitlint.config.json
//
// If you also keep `commitlint` in package.json, commitlint will warn
// about duplicate config — see commitlint.config.cjs as the source of
// truth and drop the package.json field.

const config = require('./commitlint.config.json');

module.exports = config;
module.exports.default = config; // ESM interop in case commitlint loads via dynamic import
