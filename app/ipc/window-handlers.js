/**
 * Sameko Dev C++ IDE - Window IPC Handlers
 * Handles window controls: minimize, maximize, close
 * @module app/ipc/window-handlers
 */

'use strict';

const { ipcMain } = require('electron');
const { IPC } = require('../shared/constants');
const { minimizeWindow, toggleMaximize, closeWindow, resizeWindow } = require('../windows/main-window');

/**
 * Register all window-related IPC handlers
 */
function registerHandlers() {
    ipcMain.handle(IPC.WINDOW.MINIMIZE, () => {
        minimizeWindow();
    });

    ipcMain.handle(IPC.WINDOW.MAXIMIZE, () => {
        toggleMaximize();
    });

    ipcMain.handle(IPC.WINDOW.CLOSE, () => {
        closeWindow();
    });

    ipcMain.handle(IPC.WINDOW.RESIZE, (event, payload = {}) => {
        const allowedEdges = new Set(['n', 'e', 's', 'w', 'ne', 'nw', 'se', 'sw']);
        const edge = String(payload.edge || '');
        if (!allowedEdges.has(edge)) {
            return { success: false, error: 'Invalid resize edge' };
        }

        const deltaX = Number(payload.deltaX) || 0;
        const deltaY = Number(payload.deltaY) || 0;
        const bounds = resizeWindow(edge, deltaX, deltaY);
        return { success: true, bounds };
    });

}

module.exports = {
    registerHandlers,
};
