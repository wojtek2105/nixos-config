{ pkgs, ... }:

{
  # asus-armoury entered mainline after the default 6.18 kernel. It exposes
  # firmware attributes used by current asusctl releases on this GA402RK.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "asus-armoury" ];

  services.asusd = {
    enable = true;
    # Keep one thermal/power policy regardless of AC state. The previous
    # mutable asusd state selected Quiet on battery and Performance on AC,
    # which could leave the laptop in Quiet after reconnecting the adapter.
    asusdConfig.text = ''
      (
          charge_control_end_threshold: 100,
          base_charge_control_end_threshold: 0,
          disable_nvidia_powerd_on_battery: true,
          ac_command: "",
          bat_command: "",
          platform_profile_linked_epp: true,
          platform_profile_on_battery: Performance,
          change_platform_profile_on_battery: false,
          platform_profile_on_ac: Performance,
          change_platform_profile_on_ac: false,
          profile_quiet_epp: Power,
          profile_balanced_epp: BalancePower,
          profile_custom_epp: Performance,
          profile_performance_epp: Performance,
          ac_profile_tunings: {
              Performance: (
                  enabled: true,
                  group: {
                      PptPlatformSppt: 115,
                      PptApuSppt: 80,
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
  };
  services.upower.enable = true;
  # asusd and this host policy own the platform profile. A second profile
  # daemon could otherwise overwrite Performance after an AC/battery event.
  services.power-profiles-daemon.enable = false;

  systemd.services.asus-performance-profile = {
    description = "Force the ASUS platform profile to Performance";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      profile=/sys/firmware/acpi/platform_profile
      if [[ -w "$profile" ]]; then
        printf '%s\n' performance > "$profile"
      fi
    '';
  };

  # Firmware can restore its default policy across suspend, so reapply the
  # single allowed profile before the graphical session resumes work.
  powerManagement.resumeCommands = ''
    profile=/sys/firmware/acpi/platform_profile
    if [ -w "$profile" ]; then
      printf '%s\n' performance > "$profile"
    fi
  '';

  programs.rog-control-center = {
    enable = true;
    # nixpkgs currently expects a desktop file that asusctl 6.4 no longer ships.
    # Keep the application available without the broken autostart derivation.
    autoStart = false;
  };
}
