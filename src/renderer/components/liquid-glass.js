/**
 * Nik Delvin Apple Liquid Glass Refraction Engine
 * Exact implementation based on liquid-glass (127.0.0.1:4321)
 * Generates dynamic optical displacement maps with RGB chromatic aberration.
 */

const LiquidGlassEngine = {
    /**
     * Generate dynamic SVG displacement map Data URI
     */
    getDisplacementMap({ height, width, radius, depth }) {
        const svg = `<svg height="${height}" width="${width}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
            <style>.mix { mix-blend-mode: screen; }</style>
            <defs>
                <linearGradient id="Y" x1="0" x2="0" y1="${Math.ceil((radius / height) * 15)}%" y2="${Math.floor(100 - (radius / height) * 15)}%">
                    <stop offset="0%" stop-color="#0F0" />
                    <stop offset="100%" stop-color="#000" />
                </linearGradient>
                <linearGradient id="X" x1="${Math.ceil((radius / width) * 15)}%" x2="${Math.floor(100 - (radius / width) * 15)}%" y1="0" y2="0">
                    <stop offset="0%" stop-color="#F00" />
                    <stop offset="100%" stop-color="#000" />
                </linearGradient>
            </defs>
            <rect x="0" y="0" height="${height}" width="${width}" fill="#808080" />
            <g filter="blur(2px)">
                <rect x="0" y="0" height="${height}" width="${width}" fill="#000080" />
                <rect x="0" y="0" height="${height}" width="${width}" fill="url(#Y)" class="mix" />
                <rect x="0" y="0" height="${height}" width="${width}" fill="url(#X)" class="mix" />
                <rect x="${depth}" y="${depth}" height="${Math.max(1, height - 2 * depth)}" width="${Math.max(1, width - 2 * depth)}" fill="#808080" rx="${radius}" ry="${radius}" filter="blur(${depth}px)" />
            </g>
        </svg>`;
        return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
    },

    /**
     * Generate dynamic SVG displacement filter Data URI with RGB Chromatic Aberration
     */
    getDisplacementFilter({ height, width, radius, depth, strength = 40, chromaticAberration = 6 }) {
        const mapUri = this.getDisplacementMap({ height, width, radius, depth });
        const svg = `<svg height="${height}" width="${width}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <filter id="displace" color-interpolation-filters="sRGB">
                    <feImage x="0" y="0" height="${height}" width="${width}" href="${mapUri}" result="displacementMap" />
                    <feDisplacementMap transform-origin="center" in="SourceGraphic" in2="displacementMap" scale="${strength + chromaticAberration * 2}" xChannelSelector="R" yChannelSelector="G" />
                    <feColorMatrix type="matrix" values="1 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 1 0" result="displacedR" />
                    <feDisplacementMap in="SourceGraphic" in2="displacementMap" scale="${strength + chromaticAberration}" xChannelSelector="R" yChannelSelector="G" />
                    <feColorMatrix type="matrix" values="0 0 0 0 0  0 1 0 0 0  0 0 0 0 0  0 0 0 1 0" result="displacedG" />
                    <feDisplacementMap in="SourceGraphic" in2="displacementMap" scale="${strength}" xChannelSelector="R" yChannelSelector="G" />
                    <feColorMatrix type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 1 0 0  0 0 0 1 0" result="displacedB" />
                    <feBlend in="displacedR" in2="displacedG" mode="screen"/>
                    <feBlend in2="displacedB" mode="screen"/>
                </filter>
            </defs>
        </svg>`;
        return "data:image/svg+xml;utf8," + encodeURIComponent(svg) + "#displace";
    },

    /**
     * Redraw glass refraction geometry on target element
     */
    redraw(el) {
        if (!el) return;
        const rect = el.getBoundingClientRect();
        const width = Math.max(10, Math.round(rect.width));
        const height = Math.max(10, Math.round(rect.height));

        const blur = parseFloat(el.dataset.blur || "8");
        const depth = parseFloat(el.dataset.depth || "6");
        const strength = parseFloat(el.dataset.strength || "30");
        const chromaticAberration = parseFloat(el.dataset.cab || "4");
        const radius = parseFloat(getComputedStyle(el).borderRadius || "12");

        const filterUrl = this.getDisplacementFilter({ height, width, radius, depth, strength, chromaticAberration });
        el.style.backdropFilter = `blur(${blur / 2}px) url('${filterUrl}') blur(${blur}px) brightness(1.1) saturate(1.25)`;
        el.style.webkitBackdropFilter = `blur(${blur / 2}px) url('${filterUrl}') blur(${blur}px) brightness(1.1) saturate(1.25)`;
    },

    /**
     * Observe and bind glass elements
     */
    init() {
        const elements = document.querySelectorAll('.liquidglass-refract');
        elements.forEach(el => {
            this.redraw(el);
            if (!el._glassObserver) {
                el._glassObserver = new ResizeObserver(() => this.redraw(el));
                el._glassObserver.observe(el);
            }
        });
    }
};

const LiquidGlassManager = {
    apply(appearance) {
        const enabled = appearance?.liquidGlass !== false;
        const performanceMode = appearance?.performanceMode === true;

        document.body.classList.toggle('glass-disabled', !enabled);
        document.body.classList.toggle('glass-performance', enabled && performanceMode);

        if (enabled && !performanceMode) {
            setTimeout(() => LiquidGlassEngine.init(), 100);
        }
    }
};

document.addEventListener('DOMContentLoaded', () => {
    LiquidGlassEngine.init();
});

if (typeof module !== 'undefined' && module.exports) {
    module.exports = { LiquidGlassEngine, LiquidGlassManager };
}
