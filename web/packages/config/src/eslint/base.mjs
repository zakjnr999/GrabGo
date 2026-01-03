import { defineConfig, globalIgnores } from "eslint/config";

const baseConfig = defineConfig([
    globalIgnores([
        ".next/**",
        "out/**",
        "build/**",
        "dist/**",
        "node_modules/**",
        "next-env.d.ts",
    ]),
]);

export default baseConfig;
