# Plasma 6.6 compatibility evidence

Original commit: 30ef04b4922948e77b0c5a0d37e022c0808d71db.

- Original run [46027335315](https://github.com/chmodmasx/gruvbox-plus-kde/actions/runs/46027335315): both desktop themes and color schemes apply; global package installation returns success but metadata discovery/list/apply fails for both variants.
- KWin initially failed with EPERM before execution. The disposable CI container now removes only the optional scheduling file capability if present. No host or user system changes are made.
- [46028165785](https://github.com/chmodmasx/gruvbox-plus-kde/actions/runs/46028165785): both variants passed on Plasma 6.6.7 after converting only the global package metadata to JSON. KWin virtual Wayland, PlasmaShell desktop/panel, and a Wayland client remained alive.
- KDE Aurorae [6.6](https://github.com/KDE/aurorae/blob/Plasma/6.6/v1/aurorae.cpp) and [6.7](https://github.com/KDE/aurorae/blob/Plasma/6.7/v1/aurorae.cpp) both still implement the original SVG loader. Their v1 CMake files both install org.kde.kwin.aurorae; the v2 provider still requires metadata.desktop for Aurorae themes. Do not migrate or convert Aurorae metadata without an observed incompatibility.
- KDE [KSplash 6.6](https://github.com/KDE/plasma-workspace/blob/Plasma/6.6/ksplash/ksplashqml/splashapp.cpp) adopts existing screens before advancing to initial and wm stages; stage 1 is therefore not intrinsically incompatible with Wayland. Test the original QML using ksplashqml --test --nofork and inspect captures before changing it.
- Next CI adds KWin supportInformation, desktop/window/splash captures with KDE Spectacle and the actual splash test. Screenshots and full visual fidelity are not yet verified. External icon pack is outside this test.

No original graphics, colors, Aurorae assets or splash assets have been modified. The only theme change is the global metadata conversion.
