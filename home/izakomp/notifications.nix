{ inputs, ... }:

let
  theme = import ./theme.nix { inherit inputs; };
  c = theme.colors;
in
{
  services.swaync = {
    enable = true;
    settings = {
      ignore-gtk-theme = true;
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      layer-shell = true;
      layer-shell-cover-screen = true;
      cssPriority = "user";
      control-center-positionX = "right";
      control-center-positionY = "top";
      control-center-layer = "top";
      control-center-margin-top = 40;
      control-center-margin-bottom = 10;
      control-center-margin-right = 6;
      notification-window-width = 360;
      control-center-width = 360;
      fit-to-screen = true;
      hide-on-clear = true;
      hide-on-action = true;
      relative-timestamps = true;
      notification-grouping = true;
      image-visibility = "when-available";
      image-size = 72;
      transition-time = 180;
      timeout = 6;
      timeout-low = 3;
      timeout-critical = 0;
      text-empty = "Wszystko przeczytane";
      widgets = [
        "title"
        "notifications"
      ];
      widget-config = {
        title = {
          text = "Powiadomienia";
          clear-all-button = true;
          button-text = "Wyczyść wszystko";
        };
        notifications.vexpand = true;
      };
    };

    style = ''
      :root {
        --notification-icon-size: 42px;
        --notification-app-icon-size: 18px;
        --notification-group-icon-size: 22px;
        --font-size-summary: 12.5px;
        --font-size-body: 11px;
      }

      * {
        font-family: "${theme.fonts.interface}";
        font-size: 12px;
        color: #${c.foreground};
      }

      notificationwindow,
      blankwindow,
      .floating-notifications,
      .notification-row {
        background: transparent;
      }

      .floating-notifications {
        padding: 38px 6px 6px 6px;
      }

      .control-center {
        background: alpha(#${c.background}, 0.98);
        border: 1px solid alpha(#${c.accent}, 0.76);
        border-radius: 20px;
        padding: 10px;
        box-shadow: 0 10px 32px alpha(#${c.background}, 0.76);
      }

      .control-center .control-center-list,
      .control-center .widget-notifications,
      .notification-group,
      .notification-group:focus,
      .notification-row,
      .notification-row:focus {
        background: transparent;
        outline: none;
      }

      .control-center .widget-notifications {
        margin: 0 2px 4px 2px;
        padding: 0;
        border-radius: 0;
      }

      .notification-row .notification-background {
        background: transparent;
        border: none;
        margin: 5px 2px;
        padding: 0;
      }

      .floating-notifications .notification-row .notification-background {
        margin: 4px 0;
      }

      .notification-row .notification-background .notification {
        background: alpha(#${c.surface}, 0.985);
        border: 1px solid alpha(#${c.accent}, 0.62);
        border-radius: 16px;
        padding: 0;
        box-shadow: 0 6px 20px alpha(#${c.background}, 0.68);
      }

      .notification-row .notification-background .notification.low {
        border-color: alpha(#${c.green}, 0.72);
      }

      .notification-row .notification-background .notification.critical {
        border-color: alpha(#${c.red}, 0.88);
      }

      .notification-row .notification-background .notification:hover {
        background: #${c.selection};
        border-color: alpha(#${c.yellow}, 0.62);
      }

      .notification-group.collapsed .notification-row .notification {
        background: alpha(#${c.surface}, 0.985);
      }

      .notification-row .notification-background .notification .notification-default-action {
        color: #${c.foreground};
        background: transparent;
        border: none;
        border-radius: 15px;
        padding: 0;
      }

      .notification-row .notification-background .notification .notification-default-action:hover {
        background: transparent;
      }

      .notification-row .notification-background .notification .notification-default-action .notification-content {
        background: transparent;
        padding: 12px 13px;
      }

      .notification-row .notification-background .notification .notification-default-action .notification-content .image {
        margin: 1px 12px 1px 0;
        border-radius: 12px;
      }

      .notification-row .notification-background .notification .notification-default-action .notification-content .app-icon {
        margin: 3px;
      }

      .notification-row .notification-background .notification .notification-default-action .notification-content .text-box .summary {
        color: #${c.bright};
        font-size: 12.5px;
        font-weight: 700;
      }

      .notification-row .notification-background .notification .notification-default-action .notification-content .text-box .time {
        color: #${c.subtle};
        font-family: "${theme.fonts.monospace}";
        font-size: 9.5px;
        font-weight: 600;
        margin-left: 8px;
        margin-right: 23px;
      }

      .notification-row .notification-background .notification .notification-default-action .notification-content .text-box .body {
        color: #${c.foreground};
        font-size: 11px;
        font-weight: 500;
        margin-top: 3px;
      }

      .notification-group .notification-group-headers {
        color: #${c.subtle};
        margin: 7px 10px 2px 10px;
      }

      .notification-group .notification-group-headers .notification-group-icon {
        color: #${c.accent};
      }

      .notification-group .notification-group-headers .notification-group-header {
        color: #${c.subtle};
        font-size: 10.5px;
        font-weight: 600;
      }

      .close-button {
        min-width: 21px;
        min-height: 21px;
        margin: 8px;
        padding: 0;
        color: #${c.foreground};
        background: alpha(#${c.selection}, 0.92);
        border: 1px solid alpha(#${c.muted}, 0.54);
        border-radius: 99px;
      }

      .close-button:hover {
        color: #${c.bright};
        background: #${c.red};
      }

      .widget-title {
        margin: 0 2px 8px 2px;
        padding: 7px 8px;
        background: transparent;
      }

      .widget-title > label {
        color: #${c.bright};
        font-size: 14px;
        font-weight: 700;
      }

      .widget-title > button {
        color: #${c.foreground};
        background: alpha(#${c.selection}, 0.88);
        border: 1px solid alpha(#${c.muted}, 0.58);
        border-radius: 11px;
        padding: 6px 10px;
        font-size: 10.5px;
        font-weight: 600;
      }

      .widget-title > button:hover {
        color: #${c.bright};
        background: #${c.accent};
        border-color: #${c.accent};
      }

      .notification-row .notification-background .notification .notification-action > button,
      .notification-row .notification-background .notification .inline-reply-button {
        color: #${c.foreground};
        background: #${c.selection};
        border: 1px solid alpha(#${c.muted}, 0.58);
        border-radius: 9px;
        margin: 4px;
        padding: 6px;
      }

      .notification-row .notification-background .notification .notification-action > button:hover,
      .notification-row .notification-background .notification .inline-reply-button:hover {
        color: #${c.bright};
        background: #${c.accent};
      }

      .control-center-list-placeholder {
        color: #${c.subtle};
        font-size: 11px;
        padding: 32px 12px;
      }
    '';
  };
}
