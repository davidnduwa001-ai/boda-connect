const tseslint = require("@typescript-eslint/eslint-plugin");
const tsparser = require("@typescript-eslint/parser");

module.exports = [
  {
    ignores: [
      "lib/**/*",
      "node_modules/**/*",
      "eslint.config.js",
      ".eslintrc.js",
    ],
  },
  {
    files: ["**/*.ts"],
    languageOptions: {
      parser: tsparser,
      parserOptions: {
        project: ["tsconfig.json"],
        sourceType: "module",
      },
      globals: {
        console: "readonly",
        process: "readonly",
        module: "readonly",
        require: "readonly",
        __dirname: "readonly",
        exports: "readonly",
        Buffer: "readonly",
        setTimeout: "readonly",
        clearTimeout: "readonly",
        setInterval: "readonly",
        clearInterval: "readonly",
      },
    },
    plugins: {
      "@typescript-eslint": tseslint,
    },
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
      "@typescript-eslint/no-unused-vars": "off",
      "no-unused-vars": "off",
    },
  },
];
