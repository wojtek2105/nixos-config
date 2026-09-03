{ desktopFeatures, lib, pkgs, ... }:

let
  version = "0.33.0";
  agentManagerHash = "sha256-rne6ZzaPolj4JySB8Q2YohGcoIAy5BVFOF3EIToAWDw=";
  crabcodeVersion = "0.0.11";
  farmEnabled = desktopFeatures.ollamaFarm or false;
  localOnlyProfile = !farmEnabled;

  crabcodeRelease =
    if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-u+fIA8NMKd/HMq7LhvKI8wbliiXgIxsFznDShnsTf3Y=";
    } else if pkgs.stdenv.hostPlatform.system == "aarch64-linux" then {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-XUoftb4/1bKixioVWcia++4FBk3bI77Yc+nnhutJpn4=";
    } else
      throw "Crabcode ${crabcodeVersion} nie udostępnia paczki dla ${pkgs.stdenv.hostPlatform.system}";

  # Upstream publishes checksummed native binaries but is not yet available
  # in the pinned Nixpkgs. Keep the release and both supported Linux hashes
  # explicit so every host gets a reproducible package without curl installers.
  crabcodePackage = pkgs.stdenvNoCC.mkDerivation {
    pname = "crabcode";
    version = crabcodeVersion;

    src = pkgs.fetchurl {
      url = "https://github.com/Blankeos/crabcode/releases/download/v${crabcodeVersion}/crabcode-${crabcodeRelease.target}.tar.xz";
      inherit (crabcodeRelease) hash;
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [
      pkgs.openssl
      pkgs.stdenv.cc.cc.lib
    ];

    installPhase = ''
      runHook preInstall
      install -Dm755 crabcode "$out/bin/crabcode"
      install -Dm644 LICENSE "$out/share/licenses/crabcode/LICENSE"
      install -Dm644 README.md "$out/share/doc/crabcode/README.md"
      install -Dm644 CHANGELOG.md "$out/share/doc/crabcode/CHANGELOG.md"
      runHook postInstall
    '';

    meta = {
      description = "Fast Rust terminal coding agent with OpenCode-compatible configuration";
      homepage = "https://crabcode.rs";
      license = lib.licenses.mit;
      mainProgram = "crabcode";
      platforms = [ "x86_64-linux" "aarch64-linux" ];
    };
  };

  languagePolicy = ''
    Always answer in the language of the most recent end-user request unless
    the user explicitly asks for another language. Answer Polish requests in
    Polish. Preserve code, commands, logs, API names, identifiers, and other
    technical literals in their original form. When creating a child session,
    explicitly state the end user's response language; a delegated worker must
    follow that stated language instead of inferring it from technical
    instructions written in English.
  '';

  agentManager = pkgs.stdenvNoCC.mkDerivation {
    pname = "agent-manager";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/YoanWai/agent-manager/releases/download/v${version}/agent-manager_${version}_linux_amd64.tar.gz";
      hash = agentManagerHash;
    };

    nativeBuildInputs = [ pkgs.makeWrapper ];

    unpackPhase = ''
      runHook preUnpack
      tar -xzf "$src"
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 agent-manager "$out/bin/agent-manager"
      install -Dm644 LICENSE "$out/share/licenses/agent-manager/LICENSE"
      install -Dm644 NOTICE "$out/share/licenses/agent-manager/NOTICE"
      install -Dm644 README.md "$out/share/doc/agent-manager/README.md"
      wrapProgram "$out/bin/agent-manager" \
        --run 'export TMUX_TMPDIR="''${XDG_RUNTIME_DIR:?}"' \
        --prefix PATH : ${lib.makeBinPath [
          pkgs.git
          pkgs.tmux
          pkgs.wl-clipboard
        ]}
      runHook postInstall
    '';

    meta = {
      description = "TUI for managing persistent AI coding-agent sessions";
      homepage = "https://github.com/YoanWai/agent-manager";
      license = lib.licenses.asl20;
      mainProgram = "agent-manager";
      platforms = [ "x86_64-linux" ];
    };
  };

  codexInstructions = languagePolicy + ''
    You are a visible Agent Manager session. If the user started you as the root
    session, keep ownership of requirements, decomposition, coordination,
    review, integration, and the final answer. If another session assigned you
    bounded work, stay within that scope and return concrete evidence and a
    concise handoff. Delegate independent work through Agent Manager MCP and
    ${if localOnlyProfile then ''
      On this local-only host, choose only tool="codex" or tool="crabcode" for every child;
      no remote Ollama farm profiles are installed on this host.
    '' else ''
      Choose tool="codex", "crabcode", or an explicit "crabcode-*" tool for
      every child.
    ''}
    State its backend, objective, authority, expected handoff, and exact file
    scope.
    Use Agent Manager tasks, file reservations, messages, and
    wait_for_session. Do not use native Codex subagents; every worker must stay
    visible and controllable in Agent Manager.
  '';

  localWorkerInstructions = pkgs.writeText "crabcode-language-instructions.md"
    languagePolicy;
  localManagerInstructions = pkgs.writeText "crabcode-manager-instructions.md"
    (builtins.readFile ./crabcode-manager.md + "\n" + languagePolicy);
  localOnlyManagerInstructions = pkgs.writeText "crabcode-local-manager-instructions.md"
    (builtins.readFile ./crabcode-local-manager.md + "\n" + languagePolicy);
  whiteMonsterInstructions = pkgs.writeText "crabcode-white-monster-instructions.md"
    (builtins.readFile ./crabcode-white-monster.md + "\n" + languagePolicy);

  mkCodexLauncher = name: model: reasoningEffort: instructions:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.codex ];
      text = ''
        # A manager-created Codex must not inherit the parent API session's
        # one-shot CI mode, identity or sandbox profile. Agent Manager supplies
        # its own AGENT_MANAGER_SESSION_ID separately for MCP coordination.
        unset \
          CODEX_CI \
          CODEX_PERMISSION_PROFILE \
          CODEX_SANDBOX_NETWORK_DISABLED \
          CODEX_SESSION_ID \
          CODEX_THREAD_ID

        # Agent Manager injects a Codex MCP override which forwards only the
        # session id. Codex then starts the MCP server without TMUX_TMPDIR and
        # it looks under /tmp, while the TUI uses the socket in XDG_RUNTIME_DIR.
        # Extend that exact override so both sides always inspect one server.
        codex_args=()
        for arg in "$@"; do
          if [[ "$arg" == 'mcp_servers.agent-manager.env_vars=["AGENT_MANAGER_SESSION_ID"]' ]]; then
            arg='mcp_servers.agent-manager.env_vars=["AGENT_MANAGER_SESSION_ID","TMUX_TMPDIR","XDG_RUNTIME_DIR"]'
          fi
          codex_args+=("$arg")
        done

        exec codex \
          -c ${lib.escapeShellArg ''model="${model}"''} \
          -c ${lib.escapeShellArg ''model_reasoning_effort="${reasoningEffort}"''} \
          -c ${lib.escapeShellArg ''features.multi_agent=false''} \
          -c ${lib.escapeShellArg "developer_instructions=${builtins.toJSON instructions}"} \
          "''${codex_args[@]}"
      '';
    };

  # One neutral Codex profile can own a root task or execute delegated work.
  # Medium reasoning keeps concurrent visible sessions responsive and economical.
  codexAgent = mkCodexLauncher "codex-agent" "gpt-5.6-terra" "medium" codexInstructions;

  # Crabcode receives only the endpoint and model chosen in the mutable farm
  # inventory. Model inventories remain host-specific and outside Nix/Git.
  mkCrabcodeOllama =
    {
      extraRuntimeInputs ? [ ],
      instructions ? localWorkerInstructions,
      name,
      endpointVariable,
      fallbackModel ? "qwen3:4b-instruct",
      modelVariable,
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        crabcodePackage
        pkgs.coreutils
        pkgs.findutils
        pkgs.jq
      ] ++ extraRuntimeInputs;
      text = ''
        persistent_config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
        config_file="$persistent_config_home/ollama-router/hosts.env"
        if [[ -r "$config_file" ]]; then
          # This mutable per-user file holds only LAN addresses and model names.
          # It is deliberately outside Nix and Git because every host differs.
          # shellcheck disable=SC1090
          source "$config_file"
        fi
        endpoint_variable=${lib.escapeShellArg endpointVariable}
        model_variable=${lib.escapeShellArg modelVariable}
        declare -n endpoint_ref="$endpoint_variable"
        declare -n model_ref="$model_variable"
        endpoint="''${endpoint_ref:-http://127.0.0.1:11434/v1}"
        model="''${model_ref:-${fallbackModel}}"

        # Crabcode can change effort interactively, but the initial value must
        # still match the selected GGUF. Unknown models deliberately receive no
        # effort override instead of an unsupported provider parameter.
        model_key="$(printf '%s' "$model" | tr '[:upper:]' '[:lower:]')"
        default_reasoning=""
        reasoning_options='[]'
        case "$model_key" in
          *qwen3.8*)
            default_reasoning='low'
            reasoning_options='[{"type":"effort","values":["low","medium","xhigh"]}]'
            ;;
          *qwen3.5*)
            default_reasoning='low'
            reasoning_options='[{"type":"effort","values":["low","medium","high"]}]'
            ;;
          *granite4.2*)
            default_reasoning='low'
            reasoning_options='[{"type":"effort","values":["low","high"]}]'
            ;;
        esac

        # Agent Manager 0.33.0 has no native Crabcode registration style. It
        # does generate a valid OpenCode-compatible MCP fragment, though.
        # Merge that fragment into an isolated Crabcode config so concurrent
        # host profiles never overwrite each other. Preserve the real config
        # home for the nested `agent-manager mcp` process, which needs its own
        # state database rather than this temporary Crabcode directory.
        manager_config='{}'
        if [[ -n "''${OPENCODE_CONFIG:-}" ]]; then
          if [[ ! -r "$OPENCODE_CONFIG" ]]; then
            printf 'Nie można odczytać konfiguracji MCP Agent Managera: %s\n' \
              "$OPENCODE_CONFIG" >&2
            exit 1
          fi
          manager_config="$(jq -c 'if type == "object" then . else error("expected an object") end' "$OPENCODE_CONFIG")"
        fi

        runtime_parent="''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}}"
        runtime_config_home="$(mktemp -d "$runtime_parent/crabcode-config.XXXXXX")"
        trap 'rm -rf -- "$runtime_config_home"' EXIT HUP INT TERM

        # Keep the caller's other XDG configuration visible to tools started
        # by Crabcode. Exclude both agent config directories: an old OpenCode
        # provider could reintroduce the removed model, while Crabcode's main
        # config is generated below. Preserve auxiliary Crabcode assets such as
        # themes, commands and AGENTS.md.
        if [[ -d "$persistent_config_home" ]]; then
          while IFS= read -r -d "" config_entry; do
            config_name="$(basename "$config_entry")"
            ln -s "$config_entry" "$runtime_config_home/$config_name"
          done < <(find "$persistent_config_home" -mindepth 1 -maxdepth 1 \
            ! -name crabcode ! -name opencode -print0)
        fi
        mkdir -p "$runtime_config_home/crabcode"
        if [[ -d "$persistent_config_home/crabcode" ]]; then
          while IFS= read -r -d "" crabcode_entry; do
            crabcode_name="$(basename "$crabcode_entry")"
            ln -s "$crabcode_entry" \
              "$runtime_config_home/crabcode/$crabcode_name"
          done < <(find "$persistent_config_home/crabcode" \
            -mindepth 1 -maxdepth 1 \
            ! -name crabcode.json ! -name crabcode.jsonc -print0)
        fi
        runtime_config="$runtime_config_home/crabcode/crabcode.json"

        jq -nc \
          --arg baseURL "$endpoint" \
          --arg instructions ${lib.escapeShellArg (toString instructions)} \
          --arg model "$model" \
          --arg persistentConfigHome "$persistent_config_home" \
          --argjson managerConfig "$manager_config" \
          --argjson reasoningOptions "$reasoning_options" \
          '{
            "$schema": "https://raw.githubusercontent.com/Blankeos/crabcode/main/crabcode.schema.json",
            provider: {
              "ollama-farm": {
                npm: "@ai-sdk/openai-compatible",
                name: "Ollama model farm",
                options: {
                  baseURL: $baseURL
                },
                models: {
                  ($model): ({
                    name: $model,
                    tool_call: true
                  } + (if ($reasoningOptions | length) > 0 then {
                    reasoning: true,
                    reasoning_options: $reasoningOptions
                  } else {} end))
                }
              }
            },
            model: ("ollama-farm/" + $model),
            default_agent: "build"
          } + (if $instructions == "" then {} else {
            instructions: [$instructions]
          } end)
          * $managerConfig
          | if .mcp."agent-manager"? then
              .mcp."agent-manager".environment =
                ((.mcp."agent-manager".environment // {}) + {
                  XDG_CONFIG_HOME: $persistentConfigHome
                })
            else . end' > "$runtime_config"

        crabcode_args=(--model "ollama-farm/$model")
        if [[ -n "$default_reasoning" ]]; then
          crabcode_args+=(--reasoning-effort "$default_reasoning")
        fi

        XDG_CONFIG_HOME="$runtime_config_home" \
          crabcode "''${crabcode_args[@]}" "$@"
      '';
    };

  crabcodeLocal = mkCrabcodeOllama {
    # On farm hosts the normal entry point shares the ROG profile. Iza's host
    # deliberately binds it only to its own loopback Ollama instance.
    # Its packaged binary is prepended to PATH, so the final invocation does
    # not recurse into this Home Manager wrapper.
    name = "crabcode";
    endpointVariable = if localOnlyProfile then "OLLAMA_LOCAL_URL" else "OLLAMA_ROG_URL";
    modelVariable = if localOnlyProfile then "OLLAMA_LOCAL_MODEL" else "OLLAMA_ROG_MODEL";
    fallbackModel = "qwen3.5:9b";
  };
  crabcodeOpenCodeCompat = mkCrabcodeOllama {
    # Agent Manager 0.33 always restores a built-in entry named `opencode`.
    # Give that unavoidable alias a distinct process command so it cannot be
    # confused with the real `crabcode` profile during pane inspection.
    name = "crabcode-opencode-compat";
    endpointVariable = if localOnlyProfile then "OLLAMA_LOCAL_URL" else "OLLAMA_ROG_URL";
    modelVariable = if localOnlyProfile then "OLLAMA_LOCAL_MODEL" else "OLLAMA_ROG_MODEL";
    fallbackModel = "qwen3.5:9b";
  };
  crabcodeRog = mkCrabcodeOllama {
    name = "crabcode-ollama-rog-polamaniec";
    endpointVariable = "OLLAMA_ROG_URL";
    modelVariable = "OLLAMA_ROG_MODEL";
    fallbackModel = "qwen3.5:9b";
  };
  crabcodeWhiteMonster = mkCrabcodeOllama {
    name = "crabcode-ollama-white-monster";
    endpointVariable = "OLLAMA_WHITE_MONSTER_URL";
    modelVariable = "OLLAMA_WHITE_MONSTER_MODEL";
    instructions = whiteMonsterInstructions;
  };
  crabcodeArmaniec = mkCrabcodeOllama {
    name = "crabcode-ollama-armaniec";
    endpointVariable = "OLLAMA_ARMANIEC_URL";
    modelVariable = "OLLAMA_ARMANIEC_MODEL";
  };

  ollamaFarmStatus = pkgs.writeShellApplication {
    name = "ollama-farm-status";
    runtimeInputs = with pkgs; [ coreutils curl jq ];
    text = ''
      config_file="''${XDG_CONFIG_HOME:-$HOME/.config}/ollama-router/hosts.env"
      if [[ -r "$config_file" ]]; then
        # shellcheck disable=SC1090
        source "$config_file"
      fi

      check_host() {
        local name="$1" endpoint="$2" model="$3"
        local api_root elapsed installed installed_models response started tags
        api_root="''${endpoint%/v1}"
        started="$(date +%s%3N)"
        if tags="$(curl --fail --silent --show-error --max-time 2 "$api_root/api/tags" 2>/dev/null)"; then
          elapsed="$(( $(date +%s%3N) - started ))"
          installed_models="$(printf '%s' "$tags" | jq '[.models[]? | (.name // .model)]')"
          installed="$(printf '%s' "$installed_models" | jq --arg model "$model" \
            'any(.[]; . == $model or . == ($model + ":latest"))')"
          if [[ "$installed" != true ]]; then
            jq -cn --arg name "$name" --arg endpoint "$endpoint" --arg model "$model" \
              --argjson latency_ms "$elapsed" --argjson installed_models "$installed_models" \
              '{name: $name, endpoint: $endpoint, configured_model: $model, latency_ms: $latency_ms, installed_models: $installed_models, unavailable: true, reason: "configured_model_missing"}'
            return
          fi
          response="$(curl --fail --silent --show-error --max-time 2 "$api_root/api/ps" 2>/dev/null || printf '{"models":[]}')"
          jq -cn --arg name "$name" --arg endpoint "$endpoint" --arg model "$model" \
            --argjson latency_ms "$elapsed" --argjson running "$(printf '%s' "$response" | jq '[.models[]?.name]')" \
            '{name: $name, endpoint: $endpoint, configured_model: $model, latency_ms: $latency_ms, running_models: $running}'
        else
          jq -cn --arg name "$name" --arg endpoint "$endpoint" --arg model "$model" \
            '{name: $name, endpoint: $endpoint, configured_model: $model, unavailable: true}'
        fi
      }

      jq -s '.' \
        <(check_host "rog-polamaniec" "''${OLLAMA_ROG_URL:-http://rog-polamaniec.local:11434/v1}" "''${OLLAMA_ROG_MODEL:-qwen3.5:9b}") \
        <(check_host "white-monster" "''${OLLAMA_WHITE_MONSTER_URL:-http://white-monster.local:11434/v1}" "''${OLLAMA_WHITE_MONSTER_MODEL:-qwen3:30b}") \
        <(check_host "armaniec" "''${OLLAMA_ARMANIEC_URL:-http://armaniec.local:11434/v1}" "''${OLLAMA_ARMANIEC_MODEL:-qwen3:4b-instruct}")
    '';
  };

  crabcodeManager = mkCrabcodeOllama {
    name = "crabcode-manager";
    endpointVariable = if localOnlyProfile then "OLLAMA_LOCAL_URL" else "OLLAMA_ROUTER_URL";
    modelVariable = if localOnlyProfile then "OLLAMA_LOCAL_MODEL" else "OLLAMA_ROUTER_MODEL";
    # Qwen 3.5 9B keeps the router multilingual and tool-capable while low
    # reasoning limits its latency. It needs roughly 6.6 GiB in Q4_K_M form.
    fallbackModel = "qwen3.5:9b";
    instructions = if localOnlyProfile then localOnlyManagerInstructions else localManagerInstructions;
    extraRuntimeInputs = lib.optionals farmEnabled [ ollamaFarmStatus ];
  };

  updateAgentManager = pkgs.writeShellApplication {
    name = "update-agent-manager";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gawk
      git
      gnugrep
      gnused
      nix
    ];
    text = ''
      repo_root="''${1:-$PWD}"
      module_path="$repo_root/home/base/agent-manager.nix"

      if [[ ! -f "$module_path" ]]; then
        printf 'Nie znaleziono %s; uruchom polecenie w katalogu repo albo podaj jego ścieżkę.\n' "$module_path" >&2
        exit 1
      fi

      latest_url="$(curl -fsSIL -o /dev/null -w '%{url_effective}' \
        https://github.com/YoanWai/agent-manager/releases/latest)"
      tag="''${latest_url##*/}"
      if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        printf 'Nieprawidłowy tag latest: %s\n' "$tag" >&2
        exit 1
      fi

      latest_version="''${tag#v}"
      archive="agent-manager_''${latest_version}_linux_amd64.tar.gz"
      release_url="https://github.com/YoanWai/agent-manager/releases/download/$tag"
      update_tmp="$(mktemp -d)"
      trap 'rm -rf "$update_tmp"' EXIT

      curl -fsSL -o "$update_tmp/$archive" "$release_url/$archive"
      curl -fsSL -o "$update_tmp/checksums.txt" "$release_url/checksums.txt"

      expected="$(awk -v archive="$archive" '$2 == archive { print $1 }' \
        "$update_tmp/checksums.txt")"
      actual="$(sha256sum "$update_tmp/$archive" | awk '{ print $1 }')"
      if [[ -z "$expected" || "$actual" != "$expected" ]]; then
        printf 'Weryfikacja SHA-256 nie powiodła się dla %s.\n' "$archive" >&2
        exit 1
      fi

      sri_hash="$(nix hash file --type sha256 "$update_tmp/$archive")"
      version_matches="$(grep -Ec '^  version = "[0-9]+\.[0-9]+\.[0-9]+";$' "$module_path")"
      hash_matches="$(grep -Ec '^  agentManagerHash = "sha256-[^"]+";$' "$module_path")"
      if [[ "$version_matches" != 1 || "$hash_matches" != 1 ]]; then
        printf 'Odmowa zmiany: format wersji lub hasha w %s jest nieoczekiwany.\n' "$module_path" >&2
        exit 1
      fi

      updated="$update_tmp/agent-manager.nix"
      sed -E \
        -e "s|^  version = \"[0-9]+\.[0-9]+\.[0-9]+\";|  version = \"$latest_version\";|" \
        -e "s|^  agentManagerHash = \"sha256-[^\"]+\";|  agentManagerHash = \"$sri_hash\";|" \
        "$module_path" > "$updated"

      if cmp -s "$module_path" "$updated"; then
        printf 'Agent Manager %s jest już przypięty.\n' "$tag"
        exit 0
      fi

      install -m 0644 "$updated" "$module_path"
      printf 'Przypięto Agent Manager %s. Sprawdź diff i uruchom walidację Nix.\n' "$tag"
      git -C "$repo_root" diff -- home/base/agent-manager.nix
    '';
  };

  # Agent Manager sends the startup prompt only after it recognizes Crabcode's
  # input boundary. Custom profiles do not inherit the built-in detector.
  crabcodeToolBehavior = ''
    mcp = "opencode"
    prompt_mode = "send"
    default_status = "idle"
    activity_cutoff = "(?m)^\\s*╹"
    input_prefix = "(?m)^\\s*┃"
    turn_end = "^\\s*▣ +.+· [\\dhms. ]+\\s*$"
    chrome_line = "^\\s*(┃.*)?$"
    limit_line = "(?i)usage limit|rate limit|context length|context window"
    rules = [
      { state = "errored", pattern = "(?im)^\\s*error\\b" },
      { state = "working", pattern = "(?m)^\\s*▣ +[^·\\n]+· [^·\\n]+$" },
      { state = "working", pattern = "esc (?:to )?interrupt" },
    ]
  '';
in

{
  home.packages = [
    agentManager
    codexAgent
    crabcodeLocal
    crabcodeOpenCodeCompat
    crabcodeManager
    updateAgentManager
  ] ++ lib.optionals farmEnabled [
    crabcodeRog
    crabcodeWhiteMonster
    crabcodeArmaniec
    ollamaFarmStatus
  ];

  # One Codex tool handles both root and delegated sessions. Missing fields in
  # the built-in block come from Agent Manager v0.33.0 defaults.
  xdg.configFile."agent-manager/config.toml".text = ''
    poll_interval = "2s"

    [tools.codex]
    command = "codex-agent"

    # Agent Manager 0.33.0 always backfills its built-in OpenCode entry. Point
    # that compatibility slot at Crabcode too, so no selectable profile calls
    # the removed OpenCode binary. New automation should use crabcode-* names.
    [tools.opencode]
    command = "crabcode-opencode-compat"
    ${crabcodeToolBehavior}

    [tools.crabcode]
    command = "crabcode"
    ${crabcodeToolBehavior}

    ${lib.optionalString farmEnabled ''
    [tools.crabcode-rog-polamaniec]
    command = "crabcode-ollama-rog-polamaniec"
    ${crabcodeToolBehavior}

    [tools.crabcode-white-monster]
    command = "crabcode-ollama-white-monster"
    ${crabcodeToolBehavior}

    [tools.crabcode-armaniec]
    command = "crabcode-ollama-armaniec"
    ${crabcodeToolBehavior}
    ''}

    [tools.crabcode-manager]
    command = "crabcode-manager"
    ${crabcodeToolBehavior}
  '';
}
