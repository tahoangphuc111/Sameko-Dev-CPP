'use strict';

const { ipcMain, shell } = require('electron');
const autoUpdateService = require('../services/auto-update-service');

function registerUpdateHandlers() {
    ipcMain.handle('check-for-updates', async (event) => {
        try {
            await autoUpdateService.checkForUpdates(true);
            return { success: true };
        } catch (error) {
            return { 
                success: false, 
                error: error.message 
            };
        }
    });

    ipcMain.handle('download-update', async (event) => {
        try {
            await autoUpdateService.downloadUpdate();
            return { success: true };
        } catch (error) {
            return { 
                success: false, 
                error: error.message 
            };
        }
    });

    ipcMain.handle('quit-and-install', (event) => {
        autoUpdateService.quitAndInstall();
        return { success: true };
    });

    ipcMain.handle('get-update-status', (event) => {
        return autoUpdateService.getStatus();
    });

    ipcMain.handle('open-release-page', async (event, url) => {
        const targetUrl = typeof url === 'string' && /^https:\/\/github\.com\/tahoangphuc111\/Sameko-Dev-CPP(\/|$)/.test(url)
            ? url
            : 'https://github.com/tahoangphuc111/Sameko-Dev-CPP/releases';
        await shell.openExternal(targetUrl);
        return { success: true };
    });

    // Get app info (portable detection)
    ipcMain.handle('get-app-info', () => {
        const isPortable = process.env.PORTABLE_EXECUTABLE_DIR !== undefined;
        return {
            isPortable: isPortable,
            version: require('electron').app.getVersion()
        };
    });

    console.log('[IPC] Update handlers registered');
}

module.exports = registerUpdateHandlers;
