{ inputs }:

let
  colors = {
    background = "1A1515";
    surface = "2D2424";
    selection = "453636";
    muted = "725A5A";
    subtle = "9C8181";
    foreground = "DCC9BC";
    bright = "FFE9C7";
    red = "CF223E";
    orange = "F07342";
    yellow = "E39C45";
    olive = "959A6B";
    green = "768F80";
    violet = "756D94";
    blue = "614F76";
    magenta = "7B3D79";
    accent = "AE3F82";
  };
in
{
  name = "Biscuit de Mar Dark";

  fonts = {
    interface = "CommitMono Nerd Font Propo";
    monospace = "CommitMono Nerd Font Mono";
    sans = "Inter";
  };

  inherit colors;

  metricPopup = {
    label = colors.subtle;
    value = colors.bright;
    secondary = colors.foreground;
    cpu = colors.violet;
    memory = colors.accent;
    positive = colors.green;
    upload = colors.violet;
    disk = colors.orange;
    gpu = colors.blue;
    vram = colors.magenta;
    thermal = colors.yellow;
    warning = colors.orange;
    critical = colors.red;
  };

  semantic = {
    panel = colors.surface;
    panelHover = colors.selection;
    border = colors.muted;
    active = colors.accent;
    info = colors.violet;
    success = colors.green;
    warning = colors.orange;
    thermal = colors.yellow;
    critical = colors.red;
  };

  # One canonical scene order drives all three aspect families. Keeping the
  # names in lexical scope prevents a timer tick from selecting mismatched scenes.
  wallpapers = let
    wallpaperNames = [
    "01-frieren"
    "02-frieren"
    "03-frieren-miratsumi-field"
    "07-solo-leveling-shadow-dungeon-core-v1"
    "07-vrising-vampire-throne"
    "08-solo-leveling-igris-throne-core-v1"
    "08-vrising-castle-heart-chamber"
    "09-solo-leveling-shadow-gate-core-v1"
    "09-vrising-balcony-blood-moon"
    "10-valheim-black-fjord-core-v1"
    "10-valheim-longship-fjord"
    "10-vrising-gothic-forge"
    "11-valheim-meadow-longhouse"
    "11-valheim-meadows-longhouse-core-v1"
    "12-valheim-black-forest-fire"
    "12-valheim-mountain-forge-core-v1"
    "13-pal-mountain-workshop"
    "13-valheim-mountain-peak"
    "13-vrising-castle-heart-core-v1"
    "14-blood-certificate-domain"
    "14-vrising-blood-moon-balcony-core-v1"
    "15-castle-heart-failover"
    "15-vrising-gothic-forge-core-v1"
    "16-palworld-palbox-night-base-core-lite-v1"
    "16-servant-armory"
    "16-servant-armory_1"
    "16-signed-servant-armory"
    "17-black-fjord"
    "17-black-fjord_1"
    "17-csm-makima-rooftop"
    "17-palworld-chillet-workshop-core-v1"
    "18-csm-aki-fox-balcony"
    "18-csm-power-meowy"
    "18-first-snow-core-v1"
    "18-first-snow-core-v2"
    "18-first-snow"
    "19-world-seed-core-v2"
    "19-world-seed-outpost"
    "23287880-2079-4f73-82ac-a18c6d9b18a4"
    "26-demonslayer-rengoku-overlook"
    "27-demonslayer-shinobu-wisteria"
    "28-demonslayer-nezuko-bamboo"
    "903adc1e-0b3b-4751-9fed-0b3f21f73f3e"
    "Gemini_Generated_Image_c52jltc52jltc52j"
    "Gemini_Generated_Image_cxk72pcxk72pcxk7"
    "Gemini_Generated_Image_faxgjofaxgjofaxg"
    "Gemini_Generated_Image_ryz9rsryz9rsryz9"
    "davinci_edit_composition_priority__place_every_character__face_"
    ];

    # Lists are synchronized by index: every position names the same scene in
    # three aspect families. Hyprland selects the family matching the monitor,
    # while the shared index keeps the same scene on mixed-aspect displays.
    in {
      aspect16x9 = map (name: ./wallpapers/16x9/${name}.png) wallpaperNames;
      aspect21x9 = map (name: ./wallpapers/21x9/${name}.png) wallpaperNames;
      aspect32x9 = map (name: ./wallpapers/32x9/${name}.png) wallpaperNames;
    };

  gtkTheme = "biscuit-dark";
  gtkThemeSource = "${inputs.biscuit-gtk}/biscuit-dark";
  iconTheme = "papirus-biscuit-dark";
  iconThemeSource = "${inputs.biscuit-gtk}/papirus-biscuit-dark";
}
