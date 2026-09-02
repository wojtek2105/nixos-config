{ pkgs, ... }:

let
  setGameModePerformance = pkgs.writeShellApplication {
    name = "asus-gamemode-performance";
    runtimeInputs = [ pkgs.asusctl ];
    text = ''
      exec asusctl profile set Performance
    '';
  };

  restoreAsusPowerProfile = pkgs.writeShellApplication {
    name = "asus-gamemode-restore-profile";
    runtimeInputs = [ pkgs.asusctl pkgs.coreutils ];
    text = ''
      # Match the host's normal asusd policy after the last GameMode client.
      for supply in /sys/class/power_supply/*; do
        if [ -r "$supply/type" ] && [ "$(cat "$supply/type")" = "Mains" ] \
          && [ "$(cat "$supply/online")" = "1" ]; then
          exec asusctl profile set Balanced
        fi
      done

      exec asusctl profile set Quiet
    '';
  };
in

{
  # asus-armoury entered mainline after the default 6.18 kernel. It exposes
  # firmware attributes used by current asusctl releases on this GA402RK.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "asus-armoury" ];

  services.asusd = {
    enable = true;
    # Let asusd own profile switching: Quiet limits heat and power draw on
    # battery, while Balanced keeps full everyday responsiveness on AC.
    # GameMode may still select Performance temporarily for a running game.
    # Performance on AC uses the GA402RK firmware maxima: 80 W APU and 115 W
    # platform. Read other hardware limits from the matching asus-armoury
    # attributes under /sys/class/firmware-attributes before changing them.
    asusdConfig.text = ''
      (
          charge_control_end_threshold: 100,
          base_charge_control_end_threshold: 0,
          disable_nvidia_powerd_on_battery: true,
          ac_command: "",
          bat_command: "",
          platform_profile_linked_epp: true,
          platform_profile_on_battery: Quiet,
          change_platform_profile_on_battery: true,
          platform_profile_on_ac: Balanced,
          change_platform_profile_on_ac: true,
          profile_quiet_epp: Power,
          profile_balanced_epp: BalancePower,
          profile_custom_epp: Performance,
          profile_performance_epp: Performance,
          ac_profile_tunings: {
              Performance: (
                  enabled: true,
                  group: {
                      PptApuSppt: 80,
                      PptPlatformSppt: 115,
                  },
              ),
          },
          dc_profile_tunings: {
              Performance: (
                  enabled: false,
                  group: {},
              ),
          },
          armoury_settings: {},
      )
    '';

    # Eight points per fan are temperatures in degrees Celsius and raw PWM
    # values from 0 to 255. These curves start cooling earlier than the EC
    # defaults, reach full speed at 100 C, and cover every built-in profile so
    # a manual change or GameMode cannot fall back to a warmer firmware curve.
    fanCurvesConfig.text = ''
      (
          profiles: (
              balanced: [
                  (
                      fan: CPU,
                      pwm: (26, 38, 64, 102, 148, 191, 230, 255),
                      temp: (30, 40, 50, 60, 70, 80, 90, 100),
                      enabled: true,
                  ),
                  (
                      fan: GPU,
                      pwm: (26, 38, 71, 115, 158, 199, 235, 255),
                      temp: (30, 40, 50, 60, 70, 80, 90, 100),
                      enabled: true,
                  ),
              ],
              performance: [
                  (
                      fan: CPU,
                      pwm: (38, 51, 77, 122, 173, 209, 242, 255),
                      temp: (30, 40, 50, 60, 70, 80, 90, 100),
                      enabled: true,
                  ),
                  (
                      fan: GPU,
                      pwm: (38, 51, 77, 122, 173, 209, 242, 255),
                      temp: (30, 40, 50, 60, 70, 80, 90, 100),
                      enabled: true,
                  ),
              ],
              quiet: [
                  (
                      fan: CPU,
                      pwm: (0, 20, 46, 82, 122, 166, 209, 255),
                      temp: (30, 40, 50, 60, 70, 80, 90, 100),
                      enabled: true,
                  ),
                  (
                      fan: GPU,
                      pwm: (0, 20, 51, 89, 133, 179, 224, 255),
                      temp: (30, 40, 50, 60, 70, 80, 90, 100),
                      enabled: true,
                  ),
              ],
              custom: [],
          ),
      )
    '';
  };

  services.upower.enable = true;
  # asusd owns the AC/battery profile policy. A second profile daemon could
  # race it and select a profile whose matching fan curve was not intended.
  services.power-profiles-daemon.enable = false;

  # GameMode's desiredprof targets power-profiles-daemon, which is disabled
  # here so it cannot race asusd. These hooks call asusd through asusctl on
  # the first game start and after the final game exits. The restore follows
  # this host's AC=Balanced / battery=Quiet policy.
  programs.gamemode.settings.custom = {
    start = "${setGameModePerformance}/bin/asus-gamemode-performance";
    end = "${restoreAsusPowerProfile}/bin/asus-gamemode-restore-profile";
    script_timeout = 10;
  };

  programs.rog-control-center = {
    enable = true;
    # nixpkgs currently expects a desktop file that asusctl 6.4 no longer ships.
    # Keep the application available without the broken autostart derivation.
    autoStart = false;
  };
}
