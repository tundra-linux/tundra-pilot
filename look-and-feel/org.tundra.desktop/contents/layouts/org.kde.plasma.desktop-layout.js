/*
 * Tundra default desktop layout.
 *
 * plasmashell runs this once, for a user who has no applet configuration yet, after reading
 * LookAndFeelPackage from kdeglobals. It is the only supported way to ship a distribution
 * default panel: nothing in /etc/skel may name a Plasma applet, because skel reaches only
 * accounts created after it was seeded.
 *
 * The arrangement is the Windows one — launcher at the far left, task buttons filling the
 * middle, status and clock at the right — and Plasma does all of it natively, with no
 * extension layer to maintain.
 *
 * Layout script API: https://develop.kde.org/docs/plasma/scripting/
 */

var desktop = desktopForScreen(0) || desktops()[0];
desktop.wallpaperPlugin = "org.kde.image";

var panel = new Panel("org.kde.panel");
panel.location = "bottom";
panel.alignment = "left";

/* 44px matches the Windows 11 taskbar closely enough that migrants do not notice it, and is
 * tall enough for the icons-only task manager to stay legible on a HiDPI panel. */
panel.height = 44;
panel.hiding = "none";

/* Left: the application launcher. Kickoff rather than the alternatives because it is the one
 * that looks and behaves like a Start menu. */
panel.addWidget("org.kde.plasma.kickoff");

/* Middle: icons-only task buttons, which is the Windows 11 arrangement. This widget expands
 * to fill whatever the fixed-width widgets either side of it do not use, so it is what pushes
 * the tray to the right edge. */
panel.addWidget("org.kde.plasma.icontasks");

/* Right: status, clock, and the show-desktop strip at the very edge — the last of which is a
 * Windows behaviour people reach for without knowing they have learned it. */
panel.addWidget("org.kde.plasma.marginsseparator");
panel.addWidget("org.kde.plasma.systemtray");
panel.addWidget("org.kde.plasma.digitalclock");
panel.addWidget("org.kde.plasma.showdesktop");
