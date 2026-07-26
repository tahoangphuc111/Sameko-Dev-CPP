/**
 * Apple macOS Material Engine & Optical Specification (TypeScript)
 * 
 * Implements Apple's macOS Material Architecture (NSVisualEffectView / UIVisualEffectView):
 * 1. Clean Digital Translucency (16px blur + 135% saturation)
 * 2. 1px Retina Hairline Borders & Headers
 * 3. Zero JS rAF Loop / 0% CPU Main-Thread Overhead for 120 FPS ProMotion Butter Smoothness
 */

export interface OpticalProperties {
    /** Gaussian blur radius in pixels */
    backdropBlurRadius: number;
    /** Color saturation multiplier for background legibility */
    backdropSaturation: number;
    /** Ambient contrast adjustment factor */
    brightnessFactor: number;
}

export interface SpecularLighting {
    /** Top hairline highlight opacity (Light mode) */
    topRimOpacityLight: number;
    /** Top hairline highlight opacity (Dark mode) */
    topRimOpacityDark: number;
    /** Hairline Border Color */
    hairlineColor: string;
}

export interface SurfaceTint {
    lightModeTint: string;
    darkModeTint: string;
    popoverTintLight: string;
    popoverTintDark: string;
}

export interface AppleMacOSMaterialSpec {
    readonly specVersion: 'macOS Material Standard';
    opticalProperties: OpticalProperties;
    specularLighting: SpecularLighting;
    surfaceTint: SurfaceTint;
}

export type GlassIntensityMode = 'subtle' | 'balanced' | 'strong' | 'ultra-blur';

export interface GlassRenderOptions {
    enabled: boolean;
    mode: GlassIntensityMode;
    textBlurEnabled: boolean;
    performanceMode: boolean;
}

/**
 * Standard Apple macOS Material Specification Preset
 */
export const APPLE_MACOS_MATERIAL_SPEC: AppleMacOSMaterialSpec = {
    specVersion: 'macOS Material Standard',
    opticalProperties: {
        backdropBlurRadius: 16,
        backdropSaturation: 1.35,
        brightnessFactor: 1.02,
    },
    specularLighting: {
        topRimOpacityLight: 0.60,
        topRimOpacityDark: 0.50,
        hairlineColor: 'rgba(255, 255, 255, 0.14)',
    },
    surfaceTint: {
        lightModeTint: 'rgba(255, 255, 255, 0.68)',
        darkModeTint: 'rgba(26, 28, 36, 0.65)',
        popoverTintLight: 'rgba(255, 255, 255, 0.85)',
        popoverTintDark: 'rgba(34, 36, 48, 0.82)',
    },
};

/**
 * TypeScript Apple macOS Material Controller Class
 */
export class AppleMacOSMaterialController {
    private spec: AppleMacOSMaterialSpec;
    private options: GlassRenderOptions;

    constructor(customSpec?: Partial<AppleMacOSMaterialSpec>) {
        this.spec = { ...APPLE_MACOS_MATERIAL_SPEC, ...customSpec };
        this.options = {
            enabled: true,
            mode: 'balanced',
            textBlurEnabled: true,
            performanceMode: false,
        };
    }

    public getSpec(): Readonly<AppleMacOSMaterialSpec> {
        return this.spec;
    }

    public applyOptions(options: Partial<GlassRenderOptions>): void {
        this.options = { ...this.options, ...options };
        const root = document.documentElement;

        document.body.classList.toggle('glass-disabled', !this.options.enabled);
        document.body.classList.toggle('glass-performance', this.options.enabled && this.options.performanceMode);
        document.body.dataset.glassMode = this.options.enabled ? this.options.mode : '';

        if (!this.options.enabled) {
            root.style.setProperty('--glass-blur', '0px');
            root.style.setProperty('--glass-blur-popover', '0px');
            return;
        }

        let blurPx = '16px';
        let blurPopoverPx = '20px';
        let saturation = '1.35';

        switch (this.options.mode) {
            case 'subtle':
                blurPx = '10px';
                blurPopoverPx = '14px';
                saturation = '1.20';
                break;
            case 'strong':
            case 'ultra-blur':
                blurPx = '24px';
                blurPopoverPx = '32px';
                saturation = '1.50';
                break;
            case 'balanced':
            default:
                blurPx = '16px';
                blurPopoverPx = '20px';
                saturation = '1.35';
                break;
        }

        root.style.setProperty('--glass-blur', this.options.textBlurEnabled ? blurPx : '0px');
        root.style.setProperty('--glass-blur-popover', this.options.textBlurEnabled ? blurPopoverPx : '0px');
        root.style.setProperty('--glass-saturation', saturation);
    }
}
