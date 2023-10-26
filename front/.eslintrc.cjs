module.exports = {
  root: true,
  env: {
    browser: true,
    commonjs: true,
    es2020: true,
    node: true,
  },
  extends: ['eslint:recommended', 'standard', 'plugin:vue/recommended'],
  parserOptions: {
    ecmaVersion: 2019,
  },
  plugins: ['import', 'node', 'promise', 'standard', 'vue'],
  rules: {},
}