/**
 * Sameko Dev C++ IDE - Compiler Warmup
 * Pre-caches compiler binaries in RAM for faster first compilation
 * @module app/services/compiler/warmup
 */

'use strict';

const path = require('path');
const { spawn } = require('child_process');
const { getDetectedCompiler, getCompilerInfo, getCompilerEnv } = require('./detector');

/**
 * Perform compiler warmup
 * Background compilation to force Windows to cache g++.exe, cc1plus.exe, as.exe, ld.exe into RAM
 * This reduces "Cold Start" latency for the first user actual compilation
 * 
 * @param {number} [delay=1000] - Delay in ms before starting warmup
 */
function performCompilerWarmup(delay = 1000) {
    setTimeout(() => {
        const compiler = getDetectedCompiler() || 'g++';
        const compilerInfo = getCompilerInfo();
        const env = getCompilerEnv();

        console.log('[System] Warming up compiler and linker binaries...');

        const nullDevice = process.platform === 'win32' ? 'NUL' : '/dev/null';

        // Warm up Compiler - compile a minimal program to nullDevice
        const child = spawn(compiler, ['-x', 'c++', '-', '-o', nullDevice, '-pipe', '-s', '-O0'], {
            stdio: ['pipe', 'ignore', 'ignore'],
            windowsHide: true,
            env: env
        });

        child.on('error', () => {
            // Silently ignore warmup errors
        });

        if (child.stdin) {
            child.stdin.write('int main(){return 0;}');
            child.stdin.end();
        }

        // Warm up LLD Linker (if available)
        if (compilerInfo.hasLLD && path.isAbsolute(compiler)) {
            const binDir = path.dirname(compiler);
            const lldExe = process.platform === 'win32' ? 'ld.lld.exe' : 'ld.lld';
            const lldPath = path.join(binDir, lldExe);
            if (require('fs').existsSync(lldPath)) {
                const lldWarmup = spawn(lldPath, ['--version'], {
                    windowsHide: true,
                    stdio: 'ignore'
                });
                lldWarmup.on('error', () => {
                    // Silently ignore LLD warmup errors
                });
            }
        }

        console.log('[System] Compiler warmup initiated');
    }, delay);
}

/**
 * Quick warmup - immediate warmup without delay
 * Use when user is about to compile
 */
function quickWarmup() {
    performCompilerWarmup(0);
}

module.exports = {
    performCompilerWarmup,
    quickWarmup,
};
