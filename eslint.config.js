import js from '@eslint/js';
import ts from 'typescript-eslint';
export default ts.config({ignores: ["src/reference/**/*.js"]}, js.configs.recommended, ...ts.configs.recommended, {
  files: ['src/**/*.ts', 'tests/**/*.ts'],
  rules: { '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }], '@typescript-eslint/no-explicit-any': 'error' }
});
