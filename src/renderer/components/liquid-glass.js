/**
 * Apple Liquid Glass Manager
 * Encapsulates dynamic SVG displacement filter updates, chromatic subpixel shifts, and performance fallback modes.
 */
const LiquidGlassManager = {
    filterPresets: {
        subtle: {
            blur: '0.10',
            frequency: '0.016 0.030',
            scale: '2.0',
            saturation: '1.15',
            surface: '1.8',
            constant: '0.36',
            exponent: '18',
            redShift: '-1.0',
            blueShift: '1.0'
        },
        balanced: {
            blur: '0.14',
            frequency: '0.012 0.024',
            scale: '3.6',
            saturation: '1.25',
            surface: '2.6',
            constant: '0.46',
            exponent: '24',
            redShift: '-1.8',
            blueShift: '1.8'
        },
        strong: {
            blur: '0.18',
            frequency: '0.009 0.018',
            scale: '5.2',
            saturation: '1.35',
            surface: '3.4',
            constant: '0.56',
            exponent: '30',
            redShift: '-2.5',
            blueShift: '2.5'
        }
    },

    /**
     * Apply Liquid Glass settings to body dataset and SVG filter elements.
     * @param {Object} appearance - Settings appearance configuration object.
     */
    apply(appearance) {
        const enabled = appearance?.liquidGlass !== false;
        const selectedMode = ['subtle', 'balanced', 'strong'].includes(appearance?.liquidGlassMode)
            ? appearance.liquidGlassMode
            : 'balanced';
        const performanceMode = appearance?.performanceMode === true;
        const mode = performanceMode ? 'subtle' : selectedMode;
        const refractionEnabled = appearance?.liquidGlassRefraction !== false && !performanceMode;

        document.body.classList.toggle('glass-disabled', !enabled);
        document.body.classList.toggle('glass-no-refraction', !refractionEnabled || !enabled);
        document.body.classList.toggle('glass-performance', enabled && performanceMode);
        document.body.dataset.glassMode = enabled ? mode : 'off';

        const values = this.filterPresets[mode] || this.filterPresets.balanced;
        const setAttr = (id, name, val) => document.getElementById(id)?.setAttribute(name, val);

        setAttr('glass-filter-soften', 'stdDeviation', values.blur);
        setAttr('glass-filter-map', 'baseFrequency', values.frequency);
        setAttr('glass-filter-displace', 'scale', values.scale);
        setAttr('red-shift', 'dx', values.redShift);
        setAttr('blue-shift', 'dx', values.blueShift);
        setAttr('glass-filter-color', 'values', values.saturation);
        setAttr('glass-filter-specular', 'surfaceScale', values.surface);
        setAttr('glass-filter-specular', 'specularConstant', values.constant);
        setAttr('glass-filter-specular', 'specularExponent', values.exponent);
    }
};

if (typeof module !== 'undefined' && module.exports) {
    module.exports = LiquidGlassManager;
}
