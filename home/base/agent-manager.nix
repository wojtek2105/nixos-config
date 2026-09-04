{ desktopFeatures, lib, pkgs, ... }:

let
  version = "0.33.0";
  agentManagerHash = "sha256-rne6ZzaPolj4JySB8Q2YohGcoIAy5BVFOF3EIToAWDw=";
  farmEnabled = desktopFeatures.ollamaFarm or false;
  localOnlyProfile = !farmEnabled;

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

  clineVersion = "3.0.61";
  clineCli = pkgs.stdenvNoCC.mkDerivation {
    pname = "cline-cli";
    version = clineVersion;

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@cline/cli-linux-x64/-/cli-linux-x64-${clineVersion}.tgz";
      hash = "sha256-4PFWZ6XObZAuYVRmBbQPMsJCrAXz9M6N+OC6yWsJctA=";
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    dontStrip = true;

    unpackPhase = ''
      runHook preUnpack
      tar -xzf "$src"
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin" "$out/lib/cline"
      cp -R package/. "$out/lib/cline/"
      ln -s ../lib/cline/bin/cline "$out/bin/cline"
      runHook postInstall
    '';

    meta = {
      description = "Terminal coding agent with Plan and Act modes";
      homepage = "https://github.com/cline/cline";
      license = lib.licenses.asl20;
      mainProgram = "cline";
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
      On this local-only host, choose only tool="codex", "local-low",
      "local-medium", or "local-high" for every child;
      no remote Ollama farm profiles are installed on this host.
    '' else ''
      Choose tool="codex" or an explicit ROG/White Monster effort profile for
      every child. Do not use the hidden OpenCode compatibility alias.
    ''}
    State its backend, objective, authority, expected handoff, and exact file
    scope.
    Use Agent Manager tasks, file reservations, messages, and
    wait_for_session. Do not use native Codex subagents; every worker must stay
    visible and controllable in Agent Manager.
  '';

  localWorkerInstructions = pkgs.writeText "cline-language-instructions.md"
    languagePolicy;
  localManagerInstructions = pkgs.writeText "cline-manager-instructions.md"
    (builtins.readFile ./cline-manager.md + "\n" + languagePolicy);
  localOnlyManagerInstructions = pkgs.writeText "cline-local-manager-instructions.md"
    (builtins.readFile ./cline-local-manager.md + "\n" + languagePolicy);
  whiteMonsterInstructions = pkgs.writeText "cline-white-monster-instructions.md"
    (builtins.readFile ./cline-white-monster.md + "\n" + languagePolicy);

  # Keep the local SearXNG integration dependency-free. It speaks the small
  # stdio subset of MCP needed by Cline and caps results before they reach a
  # model's context window.
  searxngMcpProgram = pkgs.writeText "searxng-mcp.py" ''
    import json
    import os
    import sys
    import urllib.parse
    import urllib.request

    server_info = {"name": "searxng", "version": "1.0.0"}
    search_tool = {
        "name": "search",
        "description": "Search the local SearXNG instance and return compact web results.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "minLength": 1},
                "max_results": {"type": "integer", "minimum": 1, "maximum": 5},
            },
            "required": ["query"],
            "additionalProperties": False,
        },
    }

    def respond(message):
        print(json.dumps(message, ensure_ascii=False), flush=True)

    def search(arguments):
        query = arguments.get("query")
        if not isinstance(query, str) or not query.strip():
            raise ValueError("query must be a non-empty string")
        limit = arguments.get("max_results", 5)
        if not isinstance(limit, int):
            raise ValueError("max_results must be an integer")
        limit = min(max(limit, 1), 5)
        endpoint = os.environ.get("SEARXNG_URL", "http://127.0.0.1:8080").rstrip("/")
        url = endpoint + "/search?" + urllib.parse.urlencode({"q": query, "format": "json"})
        request = urllib.request.Request(url, headers={"Accept": "application/json"})
        with urllib.request.urlopen(request, timeout=10) as response:
            payload = json.load(response)
        results = []
        for result in payload.get("results", [])[:limit]:
            results.append({
                "title": result.get("title", ""),
                "url": result.get("url", ""),
                "snippet": result.get("content", "")[:800],
                "engine": result.get("engine", ""),
            })
        return results

    for line in sys.stdin:
        try:
            request = json.loads(line)
            method = request.get("method")
            request_id = request.get("id")
            if method == "initialize":
                result = {
                    "protocolVersion": "2025-06-18",
                    "capabilities": {"tools": {}},
                    "serverInfo": server_info,
                }
            elif method == "tools/list":
                result = {"tools": [search_tool]}
            elif method == "tools/call":
                params = request.get("params", {})
                if params.get("name") != "search":
                    raise ValueError("unknown tool")
                results = search(params.get("arguments", {}))
                result = {
                    "content": [{"type": "text", "text": json.dumps(results, ensure_ascii=False)}],
                    "structuredContent": {"results": results},
                }
            elif method and request_id is None:
                continue
            else:
                raise ValueError("method not found")
            if request_id is not None:
                respond({"jsonrpc": "2.0", "id": request_id, "result": result})
        except Exception as error:
            if "request_id" in locals() and request_id is not None:
                respond({
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "error": {"code": -32602, "message": str(error)},
                })
  '';

  searxngMcp = pkgs.writeShellApplication {
    name = "searxng-mcp";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${searxngMcpProgram}
    '';
  };

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

  # Each launcher creates isolated provider and MCP settings. Cline's shared
  # session database remains untouched, so history survives profile changes.
  mkClineOllama =
    {
      instructions ? localWorkerInstructions,
      name,
      endpointVariable,
      fallbackModel ? "qwen3.5:9b",
      modelVariable,
      reasoningEffort ? "low",
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        agentManager
        clineCli
        pkgs.coreutils
        pkgs.git
        pkgs.jq
        pkgs.playwright-mcp
        pkgs.ripgrep
        pkgs.tmux
        searxngMcp
      ];
      text = ''
        persistent_config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
        config_file="$persistent_config_home/ollama-router/hosts.env"
        if [[ -r "$config_file" ]]; then
          # Per-host inventory stays mutable and intentionally outside Git.
          # shellcheck disable=SC1090
          source "$config_file"
        fi
        endpoint_variable=${lib.escapeShellArg endpointVariable}
        model_variable=${lib.escapeShellArg modelVariable}
        declare -n endpoint_ref="$endpoint_variable"
        declare -n model_ref="$model_variable"
        endpoint="''${endpoint_ref:-http://127.0.0.1:11434/v1}"
        model="''${model_ref:-${fallbackModel}}"
        requested_reasoning=${lib.escapeShellArg reasoningEffort}
        model_key="$(printf '%s' "$model" | tr '[:upper:]' '[:lower:]')"

        case "$model_key:$requested_reasoning" in
          *qwen3.8*:low|*qwen3.8*:medium|*qwen3.8*:xhigh|*qwen3.5*:low|*qwen3.5*:medium|*qwen3.5*:high)
            ;;
          *)
            printf 'Profil %s wymaga effort=%s, ale model %s go nie obsługuje.\n' \
              ${lib.escapeShellArg name} "$requested_reasoning" "$model" >&2
            exit 2
            ;;
        esac

        runtime_parent="''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}}"
        runtime_config_dir="$(mktemp -d "$runtime_parent/cline-profile.XXXXXX")"
        runtime_settings_dir="$runtime_config_dir/settings"
        mkdir -p "$runtime_settings_dir"
        provider_settings="$runtime_settings_dir/providers.json"
        models_registry="$runtime_settings_dir/models.json"
        mcp_settings="$runtime_settings_dir/cline_mcp_settings.json"
        trap 'rm -rf -- "$runtime_config_dir"' EXIT HUP INT TERM

        # Agent Manager 0.33 does not export its id for every custom MCP style.
        # A managed pane is always named am_<session-id>, so recover the exact
        # id from tmux. A standalone `cline` intentionally has no manager MCP.
        session_id="''${AGENT_MANAGER_SESSION_ID:-}"
        if [[ -z "$session_id" && -n "''${TMUX_PANE:-}" ]]; then
          manager_session="$(tmux display-message -p -t "$TMUX_PANE" '#S' 2>/dev/null || true)"
          if [[ "$manager_session" == am_* ]]; then
            session_id="''${manager_session#am_}"
          fi
        fi
        if [[ -n "$session_id" ]]; then
          export AGENT_MANAGER_SESSION_ID="$session_id"
        fi

        # Cline's native Ollama adapter reduces every non-zero effort to the
        # boolean `think=true`. Use Ollama's OpenAI-compatible endpoint and
        # declare the local model capability so Cline exposes the effort picker
        # and forwards low/medium/high/xhigh instead.
        endpoint="''${endpoint%/}"
        endpoint="''${endpoint%/v1}/v1"
        jq -n \
          --arg endpoint "$endpoint" \
          --arg model "$model" \
          '{"ollama-farm": {
            provider: "ollama-farm",
            apiKey: "ollama",
            baseUrl: $endpoint,
            model: $model
          }}' \
          > "$provider_settings"

        # Cline stores custom model metadata in models.json next to
        # providers.json. A named provider avoids the built-in generic
        # provider's manual model-id screen.
        jq -n \
          --arg endpoint "$endpoint" \
          --arg model "$model" \
          '{version: 1, providers: {
            "ollama-farm": {
              provider: {
                name: "Ollama farm",
                baseUrl: $endpoint,
                defaultModelId: $model,
                protocol: "openai-chat",
                client: "openai-compatible",
                capabilities: ["streaming", "tools", "reasoning"]
              },
              models: {
                ($model): {
                  id: $model,
                  name: $model,
                  contextWindow: 16384,
                  maxInputTokens: 16384,
                  maxTokens: 8192,
                  capabilities: ["streaming", "tools", "reasoning"],
                  supportsReasoning: true
                }
              }
            }
          }}' \
          > "$models_registry"

        # Playwright is registered but disabled until enabled in Cline's MCP
        # screen. No source-control MCP is installed.
        jq -n \
          --arg agent_manager "${agentManager}/bin/agent-manager" \
          --arg session_id "$session_id" \
          --arg tmux_tmpdir "''${TMUX_TMPDIR:-}" \
          --arg runtime_dir "''${XDG_RUNTIME_DIR:-}" \
          --arg searxng "${searxngMcp}/bin/searxng-mcp" \
          --arg searxng_url "''${SEARXNG_URL:-http://127.0.0.1:8080}" \
          --arg playwright "${pkgs.playwright-mcp}/bin/playwright-mcp" \
          '{mcpServers: {
            "agent-manager": {
              command: $agent_manager, args: ["mcp"],
              env: {AGENT_MANAGER_SESSION_ID: $session_id,
                TMUX_TMPDIR: $tmux_tmpdir, XDG_RUNTIME_DIR: $runtime_dir},
              disabled: ($session_id == ""), autoApprove: []
            },
            searxng: {
              command: $searxng, env: {SEARXNG_URL: $searxng_url},
              disabled: false, autoApprove: []
            },
            context7: {
              type: "streamableHttp", url: "https://mcp.context7.com/mcp",
              disabled: false, autoApprove: []
            },
            playwright: {
              command: $playwright, args: ["--headless"],
              disabled: true, autoApprove: []
            }
          }}' > "$mcp_settings"

        system_prompt="$(<${instructions})"
        export CLINE_PROVIDER_SETTINGS_PATH="$provider_settings"
        export CLINE_MCP_SETTINGS_PATH="$mcp_settings"
        ${clineCli}/bin/cline \
          --provider ollama-farm \
          --model "$model" \
          --thinking "$requested_reasoning" \
          --system "$system_prompt" \
          "$@"
      '';
    };

  clineLocalLow = mkClineOllama {
    name = if localOnlyProfile then "cline-local-low" else "cline-rog-polamaniec-low";
    endpointVariable = if localOnlyProfile then "OLLAMA_LOCAL_URL" else "OLLAMA_ROG_URL";
    modelVariable = if localOnlyProfile then "OLLAMA_LOCAL_MODEL" else "OLLAMA_ROG_MODEL";
    fallbackModel = "qwen3.5:9b";
    reasoningEffort = "low";
    instructions = if localOnlyProfile then localOnlyManagerInstructions else localManagerInstructions;
  };
  # One direct command opens the same low-effort manager used by Agent Manager.
  clineDefault = mkClineOllama {
    name = "cline";
    endpointVariable = if localOnlyProfile then "OLLAMA_LOCAL_URL" else "OLLAMA_ROG_URL";
    modelVariable = if localOnlyProfile then "OLLAMA_LOCAL_MODEL" else "OLLAMA_ROG_MODEL";
    fallbackModel = "qwen3.5:9b";
    reasoningEffort = "low";
    instructions = if localOnlyProfile then localOnlyManagerInstructions else localManagerInstructions;
  };
  clineLocalMedium = mkClineOllama {
    name = if localOnlyProfile then "cline-local-medium" else "cline-rog-polamaniec-medium";
    endpointVariable = if localOnlyProfile then "OLLAMA_LOCAL_URL" else "OLLAMA_ROG_URL";
    modelVariable = if localOnlyProfile then "OLLAMA_LOCAL_MODEL" else "OLLAMA_ROG_MODEL";
    fallbackModel = "qwen3.5:9b";
    reasoningEffort = "medium";
  };
  clineLocalHigh = mkClineOllama {
    name = if localOnlyProfile then "cline-local-high" else "cline-rog-polamaniec-high";
    endpointVariable = if localOnlyProfile then "OLLAMA_LOCAL_URL" else "OLLAMA_ROG_URL";
    modelVariable = if localOnlyProfile then "OLLAMA_LOCAL_MODEL" else "OLLAMA_ROG_MODEL";
    fallbackModel = "qwen3.5:9b";
    reasoningEffort = "high";
  };
  clineWhiteMonsterLow = mkClineOllama {
    name = "cline-white-monster-low";
    endpointVariable = "OLLAMA_WHITE_MONSTER_URL";
    modelVariable = "OLLAMA_WHITE_MONSTER_MODEL";
    fallbackModel = "qwen3.8:27b";
    instructions = whiteMonsterInstructions;
    reasoningEffort = "low";
  };
  clineWhiteMonsterMedium = mkClineOllama {
    name = "cline-white-monster-medium";
    endpointVariable = "OLLAMA_WHITE_MONSTER_URL";
    modelVariable = "OLLAMA_WHITE_MONSTER_MODEL";
    fallbackModel = "qwen3.8:27b";
    instructions = whiteMonsterInstructions;
    reasoningEffort = "medium";
  };
  clineWhiteMonsterXhigh = mkClineOllama {
    name = "cline-white-monster-xhigh";
    endpointVariable = "OLLAMA_WHITE_MONSTER_URL";
    modelVariable = "OLLAMA_WHITE_MONSTER_MODEL";
    fallbackModel = "qwen3.8:27b";
    instructions = whiteMonsterInstructions;
    reasoningEffort = "xhigh";
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
        <(check_host "white-monster" "''${OLLAMA_WHITE_MONSTER_URL:-http://white-monster.local:11434/v1}" "''${OLLAMA_WHITE_MONSTER_MODEL:-qwen3.8:27b}")
    '';
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

  # Agent Manager's OpenCode-compatible bootstrap is retained solely to export
  # the session identifier; Cline reads its full MCP setup from the launcher.
  clineToolBehavior = ''
    mcp = "opencode"
    prompt_mode = "send"
    default_status = "idle"
    limit_line = "(?i)usage limit|rate limit|context length|context window"
    rules = [
      { state = "errored", pattern = "(?im)^\\s*error\\b" },
      { state = "working", pattern = "(?i)thinking|working|esc (?:to )?interrupt" },
    ]
  '';
in

{
  home.packages = [
    agentManager
    codexAgent
    clineDefault
    clineLocalLow
    clineLocalMedium
    clineLocalHigh
    updateAgentManager
  ] ++ lib.optionals farmEnabled [
    clineWhiteMonsterLow
    clineWhiteMonsterMedium
    clineWhiteMonsterXhigh
    ollamaFarmStatus
  ];

  # One Codex tool handles both root and delegated sessions. Missing fields in
  # the built-in block come from Agent Manager v0.33.0 defaults.
  xdg.configFile."agent-manager/config.toml".text = ''
    poll_interval = "2s"

    [tools.codex]
    command = "codex-agent"

    # Agent Manager 0.33.0 always backfills this built-in compatibility entry.
    # It cannot be removed declaratively; `s -> CLIs` hides it once in the TUI.
    # Point it at the normal low-effort root so accidental use remains safe.
    [tools.opencode]
    command = "${if localOnlyProfile then "cline-local-low" else "cline-rog-polamaniec-low"}"
    ${clineToolBehavior}

    [tools.${if localOnlyProfile then "local-low" else "rog-polamaniec-low"}]
    command = "${if localOnlyProfile then "cline-local-low" else "cline-rog-polamaniec-low"}"
    ${clineToolBehavior}

    [tools.${if localOnlyProfile then "local-medium" else "rog-polamaniec-medium"}]
    command = "${if localOnlyProfile then "cline-local-medium" else "cline-rog-polamaniec-medium"}"
    ${clineToolBehavior}

    [tools.${if localOnlyProfile then "local-high" else "rog-polamaniec-high"}]
    command = "${if localOnlyProfile then "cline-local-high" else "cline-rog-polamaniec-high"}"
    ${clineToolBehavior}

    ${lib.optionalString farmEnabled ''
    [tools.white-monster-low]
    command = "cline-white-monster-low"
    ${clineToolBehavior}

    [tools.white-monster-medium]
    command = "cline-white-monster-medium"
    ${clineToolBehavior}

    [tools.white-monster-xhigh]
    command = "cline-white-monster-xhigh"
    ${clineToolBehavior}
    ''}
  '';
}
