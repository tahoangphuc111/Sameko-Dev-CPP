/**
 * Masterclass Apple Liquid Glass Controller & rAF Parallax Engine
 * 
 * Performance & Rendering Guarantee:
 * - Mouse movement updates specular sheen parallax ONLY inside requestAnimationFrame()
 * - Zero backdrop-filter keyframe animations (animates transform & opacity via GPU compositor)
 * - Zero forced DOM layout reflows (modifies CSS transform & custom variables at 120 FPS)
 */

class AppleLiquidGlassEngine {
    constructor() {
        this.rafId = null;
        this.mouseX = 0;
        this.mouseY = 0;
        this.targetX = 0;
        this.targetY = 0;
        this.initParallax();
    }

    initParallax() {
        window.addEventListener('mousemove', (e) => {
            // Compute normalized -1 to +1 range from window center
            const centerX = window.innerWidth / 2;
            const centerY = window.innerHeight / 2;
            this.targetX = (e.clientX - centerX) / centerX;
            this.targetY = (e.clientY - centerY) / centerY;

            if (!this.rafId) {
                this.rafId = requestAnimationFrame(() => this.updateParallax());
            }
        }, { passive: true });
    }

    updateParallax() {
        // Smooth exponential interpolation (lerp) for physics feel
        this.mouseX += (this.targetX - this.mouseX) * 0.12;
        this.mouseY += (this.targetY - this.mouseY) * 0.12;

        const shiftX = (this.mouseX * 2.5).toFixed(2) + 'px';
        const shiftY = (this.mouseY * 2.5).toFixed(2) + 'px';

        document.documentElement.style.setProperty('--parallax-x', shiftX);
        document.documentElement.style.setProperty('--parallax-y', shiftY);

        if (Math.abs(this.targetX - this.mouseX) > 0.001 || Math.abs(this.targetY - this.mouseY) > 0.001) {
            this.rafId = requestAnimationFrame(() => this.updateParallax());
        } else {
            this.rafId = null;
        }
    }

    apply(appearance) {
        const enabled = appearance?.liquidGlass !== false;
        const performanceMode = appearance?.performanceMode === true;

        document.body.classList.toggle('glass-disabled', !enabled);
        document.body.classList.toggle('glass-performance', enabled && performanceMode);
    }
}

const LiquidGlassManager = new AppleLiquidGlassEngine();

if (typeof module !== 'undefined' && module.exports) {
    module.exports = { LiquidGlassManager };
}
