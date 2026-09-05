{ config, lib, pkgs, username, ... }:

let
  cfg = config.services.autoAiRouter;
  python = pkgs.python3.withPackages (ps: with ps; [
    fastapi
    httpx
    pydantic
    pytest
    pytest-asyncio
    uvicorn
  ]);
  autoAiRouterPackage = pkgs.stdenvNoCC.mkDerivation {
    pname = "auto-ai-router";
    version = "1.0.0";
    src = ../services/auto-ai-router;

    nativeBuildInputs = [ pkgs.makeWrapper ];
    doCheck = true;

    checkPhase = ''
      runHook preCheck
      PYTHONPATH="$PWD" ${python}/bin/python -m pytest -q
      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall
      install -Dm644 auto_ai_router.py "$out/lib/auto-ai-router/auto_ai_router.py"
      makeWrapper ${python}/bin/uvicorn "$out/bin/auto-ai-router" \
        --add-flags "auto_ai_router:app" \
        --add-flags "--app-dir $out/lib/auto-ai-router"
      runHook postInstall
    '';
  };
in
{
  options.services.autoAiRouter = {
    enable = lib.mkEnableOption "local OpenAI-compatible AUTO AI orchestrator";

    package = lib.mkOption {
      type = lib.types.package;
      default = autoAiRouterPackage;
      description = "AUTO orchestrator package, including its Python runtime.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      # The LiteLLM container reaches this address through Docker's host gateway.
      # Port 4100 is accepted only on the named Compose bridge.
      default = "0.0.0.0";
      description = "Address used by uvicorn; firewall access is limited to Compose.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4100;
      description = "Internal HTTP port used between LiteLLM and AUTO.";
    };

    litellmBaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:4000/v1";
      description = "Host-side LiteLLM URL used for internal worker calls.";
    };

    routerModel = lib.mkOption {
      type = lib.types.str;
      default = "router";
      description = "LiteLLM alias used only for structured routing decisions.";
    };

    visionModel = lib.mkOption {
      type = lib.types.str;
      default = "vision";
      description = "LiteLLM alias that must inspect every attached image.";
    };

    reasoningModel = lib.mkOption {
      type = lib.types.str;
      default = "reasoning";
      description = "LiteLLM alias used for senior reasoning and safe fallback.";
    };

    coderModel = lib.mkOption {
      type = lib.types.str;
      default = "coder";
      description = "LiteLLM coding alias; it can be repointed without changing AUTO.";
    };

    routerTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 15;
      description = "Router timeout in seconds; failure falls back to reasoning.";
    };

    visionTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 180;
      description = "Vision timeout in seconds before an explicit failure report.";
    };

    finalTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 900;
      description = "Reasoning or coding backend timeout in seconds.";
    };

    routerConfidence = lib.mkOption {
      type = lib.types.float;
      default = 0.65;
      description = "Minimum accepted router confidence; lower values use reasoning.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !builtins.elem "auto" [
          cfg.routerModel
          cfg.visionModel
          cfg.reasoningModel
          cfg.coderModel
        ];
        message = "AUTO worker aliases must never point back to model 'auto'.";
      }
      {
        assertion = cfg.port != 4000;
        message = "AUTO's internal port must differ from the public LiteLLM port 4000.";
      }
      {
        assertion = cfg.routerConfidence >= 0.0 && cfg.routerConfidence <= 1.0;
        message = "services.autoAiRouter.routerConfidence must be between 0 and 1.";
      }
    ];

    # Only the central ROG gateway imports this enabled module. AUTO's port is
    # accepted solely from the named Compose bridge; LAN clients use 4000.
    networking.firewall.allowedTCPPorts = [ 4000 ];
    networking.firewall.interfaces."ai-gateway0".allowedTCPPorts = [ cfg.port ];

    systemd.services.auto-ai-router = {
      description = "Local AUTO AI routing orchestrator";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" "docker.service" ];

      environment = {
        AUTO_AI_LITELLM_BASE_URL = cfg.litellmBaseUrl;
        AUTO_AI_ROUTER_MODEL = cfg.routerModel;
        AUTO_AI_VISION_MODEL = cfg.visionModel;
        AUTO_AI_REASONING_MODEL = cfg.reasoningModel;
        AUTO_AI_CODER_MODEL = cfg.coderModel;
        AUTO_AI_ROUTER_TIMEOUT = toString cfg.routerTimeout;
        AUTO_AI_VISION_TIMEOUT = toString cfg.visionTimeout;
        AUTO_AI_FINAL_TIMEOUT = toString cfg.finalTimeout;
        AUTO_AI_ROUTER_CONFIDENCE = toString cfg.routerConfidence;
        PYTHONUNBUFFERED = "1";
      };

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/auto-ai-router --host ${cfg.listenAddress} --port ${toString cfg.port}";
        # PID 1 reads the private per-user inventory before dropping privileges
        # to DynamicUser. A leading '-' keeps diagnostics available before the
        # user has run init-litellm-env for the first time.
        EnvironmentFile = "-${config.users.users.${username}.home}/.config/ollama-router/hosts.env";
        Restart = "on-failure";
        RestartSec = "2s";
        DynamicUser = true;
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
        SystemCallArchitectures = "native";
      };
    };
  };
}
