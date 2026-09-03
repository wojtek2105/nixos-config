{ desktopTheme, hostName, pkgs, ... }:

let
  c = desktopTheme.colors;
  # A true OLED black is reserved for the short boot splash; the interactive
  # desktop keeps Biscuit's warmer background for surface separation.
  splashBackground = "000000";
  hexDigit = digit: {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "A" = 10;
    "B" = 11;
    "C" = 12;
    "D" = 13;
    "E" = 14;
    "F" = 15;
  }.${digit};
  hexComponent = color: offset:
    hexDigit (builtins.substring offset 1 color) * 16
    + hexDigit (builtins.substring (offset + 1) 1 color);
  channel = color: offset: toString (hexComponent color offset / 255.0);
  # Plymouth's script renderer uses PNG assets. Derive it from the selected
  # source SVG at build time so branding has one canonical full mascot file.
  biscuitPlymouthMascot = pkgs.runCommand "wojtech-totem-plymouth.png" {
    nativeBuildInputs = [ pkgs.librsvg ];
  } ''
    # Keep more source detail than the 560 px on-screen size requires so the
    # large mascot remains clean on high-density panels.
    rsvg-convert --width 640 ${../assets/branding/wojtech-tux-totem-transparent.svg} > "$out"
  '';
  # A tiny transparent vector is rasterised once for the initrd. Thirty cached
  # rotations give a smooth spinner without reading files or redrawing paths
  # during boot.
  biscuitPlymouthSpinnerSvg = pkgs.writeText "biscuit-plymouth-spinner.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
      <circle cx="32" cy="32" r="23" fill="none" stroke="#${c.muted}" stroke-width="3" opacity="0.36"/>
      <path d="M32 9 A23 23 0 0 1 53.5 24" fill="none" stroke="#${c.accent}" stroke-width="3" stroke-linecap="round"/>
    </svg>
  '';
  biscuitPlymouthSpinner = pkgs.runCommand "biscuit-plymouth-spinner.png" {
    nativeBuildInputs = [ pkgs.librsvg ];
  } ''
    rsvg-convert ${biscuitPlymouthSpinnerSvg} > "$out"
  '';
  biscuitPlymouthScript = pkgs.writeText "biscuit-plymouth.script" ''
    # Match the permanent desktop palette with one large mascot and a small,
    # cached spinner. Keeping the initrd script compact makes the hand-off
    # reliable on every host.
    Window.SetBackgroundTopColor(${channel splashBackground 0}, ${channel splashBackground 2}, ${channel splashBackground 4});
    Window.SetBackgroundBottomColor(${channel splashBackground 0}, ${channel splashBackground 2}, ${channel splashBackground 4});

    mascot.source = Image("wojtech-totem.png");
    # 720 px keeps the mascot readable on high-density displays; reduce this
    # only for panels shorter than 900 px, so the spinner remains below it
    # rather than clipping at the bottom edge.
    mascot.image = mascot.source.Scale(720, 720);
    mascot.sprite = Sprite(mascot.image);
    spinner.source = Image("spinner.png");
    spinner.steps = 30;
    for (i = 0; i < spinner.steps; i++)
      {
        spinner.image[i] = spinner.source.Rotate((Math.Pi * 2 * i) / spinner.steps);
      }
    spinner.index = 0;
    spinner.sprite = Sprite(spinner.image[spinner.index]);
    refresh = 0;

    fun layout ()
      {
        center_x = Window.GetX() + Window.GetWidth() / 2;
        mascot_y = Window.GetY() + Window.GetHeight() / 2 - mascot.image.GetHeight() / 2 - 24;
        mascot.sprite.SetPosition(center_x - mascot.image.GetWidth() / 2, mascot_y, 10);
        spinner.sprite.SetPosition(center_x - spinner.source.GetWidth() / 2, mascot_y + mascot.image.GetHeight() + 28, 10);
      }

    fun refresh_callback ()
      {
        # Plymouth calls refresh up to 50 times per second. Three updates in
        # every five callbacks target roughly 30 FPS while reducing initrd work.
        if (refresh % 5 < 3)
          {
            spinner.index = (spinner.index + 1) % spinner.steps;
            spinner.sprite.SetImage(spinner.image[spinner.index]);
          }
        refresh++;
        layout();
      }

    layout();
    Plymouth.SetRefreshFunction (refresh_callback);
  '';
  biscuitPlymouthTheme = pkgs.runCommand "biscuit-plymouth-theme" { } ''
    theme_dir="$out/share/plymouth/themes/biscuit"
    mkdir -p "$theme_dir"
    cp ${biscuitPlymouthScript} "$theme_dir/biscuit.script"
    cp ${biscuitPlymouthMascot} "$theme_dir/wojtech-totem.png"
    cp ${biscuitPlymouthSpinner} "$theme_dir/spinner.png"
    cat > "$theme_dir/biscuit.plymouth" <<EOF
    [Plymouth Theme]
    Name=Biscuit
    Description=Minimal Biscuit boot sequence.
    ModuleName=script

    [script]
    ImageDir=$theme_dir
    ScriptFile=$theme_dir/biscuit.script
    ConsoleLogBackgroundColor=0x${splashBackground}
    EOF
  '';
in
{
  # Plymouth keeps the same Biscuit visual language as Tuigreet and Ironbar.
  # It starts from the initrd and exits before greetd owns VT1, so it adds no
  # resident process after login. Press Esc during boot for diagnostics.
  boot = {
    plymouth = {
      enable = true;
      theme = "biscuit";
      themePackages = [ biscuitPlymouthTheme ];
      # Render immediately; a fast machine should still show a clean hand-off
      # instead of a flash of console text before the greeter.
      showDelay = 0;
    };

    # Keep ordinary boot quiet while retaining warning-and-higher-priority
    # messages for the Esc diagnostic view. Values below 3 would also hide
    # useful failures, making recovery needlessly harder.
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "rd.systemd.show_status=auto"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
  };
}
