module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json"],
    sourceType: "module",
    tsconfigRootDir: __dirname,
  },
  ignorePatterns: [
    "/lib/**/*",
    "/node_modules/**/*",
    ".eslintrc.js",
  ],
  plugins: [
    "@typescript-eslint",
  ],
  rules: {
    "max-len": "off",
    "indent": "off",
    "object-curly-spacing": "off",
    "operator-linebreak": "off",
    "require-jsdoc": "off",
    "eol-last": "off",
    "no-case-declarations": "off",
    "quotes": ["error", "double"],
    "@typescript-eslint/no-explicit-any": "off",
  },
};