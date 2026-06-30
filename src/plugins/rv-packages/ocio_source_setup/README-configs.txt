This package now includes a bundled ACES 1.3 CG config compatible with OpenRV 3.1 / OpenColorIO 2.3.x.

Bundled default:
- config/aces_1.3/config.ocio
- source: ACESCentral / ASWF OpenColorIO-Config-ACES
- upstream file: cg-config-v2.2.0_aces-v1.3_ocio-v2.3.ocio

Additional configs can also be placed here if you want OpenRV to find one without the OCIO environment variable.

Recognized default locations are:
- config/aces_1.3/config.ocio
- config/aces-1.3/config.ocio
- config/aces_2.0/config.ocio
- config/aces-2.0/config.ocio
- config/config.ocio

When an OCIO config is available, the default source policy is:
- EXR uses EXR/colorInteropID when it contains a recognizable color space such as ACEScg.
- EXR falls back to ACEScg when no recognizable metadata is present.
- Non-EXR media stays on RV's native path, so ACES/OCIO is not enabled for it by default.
