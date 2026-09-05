{ desktopFeatures, lib, pkgs, ... }:

let
  version = "0.35.0";
  agentManagerHash = "sha256-72+j6XTkdHJaIt0qoV3I/04vwKslY3WC4fBhhuDWVUU=";
  farmEnabled = desktopFeatures.ollamaFarm or false;
  autoAiRouterEnabled = desktopFeatures.autoAiRouter or false;
  localOnlyProfile = !farmEnabled;

  piModel = id: name: reasoning: {
    inherit id name reasoning;
    input = [ "text" ];
    contextWindow = 65536;
    maxTokens = 4096;
    cost = { input = 0; output = 0; cacheRead = 0; cacheWrite = 0; };
  };

  # Keep every LiteLLM alias selectable in Pi; AUTO remains the default.
  piModels = map (entry: piModel entry.id entry.name entry.reasoning) [
    { id = "auto"; name = "LiteLLM AUTO (Qwen3.8)"; reasoning = false; }
    { id = "router"; name = "LiteLLM Router (Qwen3.5)"; reasoning = false; }
    { id = "vision"; name = "LiteLLM Vision (Qwen3.5)"; reasoning = false; }
    { id = "reasoning"; name = "LiteLLM Reasoning (Qwen3.8)"; reasoning = true; }
    { id = "coder"; name = "LiteLLM Coder (Qwen3.8)"; reasoning = true; }
    { id = "rog-qwen35-off"; name = "ROG Qwen3.5 off"; reasoning = false; }
    { id = "rog-qwen35-thinking"; name = "ROG Qwen3.5 thinking"; reasoning = true; }
    { id = "white-qwen38-off"; name = "White Monster Qwen3.8 off"; reasoning = false; }
    { id = "white-qwen38-low"; name = "White Monster Qwen3.8 low"; reasoning = true; }
    { id = "white-qwen38-medium"; name = "White Monster Qwen3.8 medium"; reasoning = true; }
    { id = "white-qwen38-xhigh"; name = "White Monster Qwen3.8 xhigh"; reasoning = true; }
  ];

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

  piVersion = "0.85.0";
  # Official standalone Pi release. Pinning the binary keeps the installed
  # agent independent from a mutable global npm prefix.
  piCore = pkgs.stdenvNoCC.mkDerivation {
    pname = "pi-coding-agent";
    version = piVersion;

    src = pkgs.fetchurl {
      url = "https://github.com/earendil-works/pi/releases/download/v${piVersion}/pi-linux-x64.tar.gz";
      hash = "sha256-p+fGXx3FKNLhfn2UatK2HfDisPmVL67neAfCSEtGTW4=";
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
      # Keep the official archive layout: the executable resolves built-in
      # themes and other assets relative to its sibling files under bin/.
      mkdir -p "$out/bin"
      cp -r pi/. "$out/bin/"
      chmod 0755 "$out/bin/pi"
      runHook postInstall
    '';

    meta = {
      description = "Minimal terminal coding agent";
      homepage = "https://pi.dev";
      license = lib.licenses.mit;
      mainProgram = "pi";
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
      On this local-only host, choose only tool="codex" or tool="pi" for
      every child; no remote Ollama farm profiles are installed on this host.
    '' else ''
      Choose tool="codex" or tool="pi" for every child. Pi always uses the
      configured LiteLLM alias and must not be replaced with a compatibility
      CLI profile.
    ''}
    State its backend, objective, authority, expected handoff, and exact file
    scope.
    Use Agent Manager tasks, file reservations, messages, and
    wait_for_session. Do not use native Codex subagents; every worker must stay
    visible and controllable in Agent Manager.
  '';

  # Keep the local SearXNG integration dependency-free. It speaks the small
  # stdio subset of MCP needed by Pi and caps results before they reach a
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

  # Pi stays on LiteLLM's logical `auto` model and lets AUTO select the final
  # Qwen worker. The wrapper keeps the secret out of persisted Pi JSON.
  piLauncher = pkgs.writeShellApplication {
    name = "pi";
    runtimeInputs = [ agentManager pkgs.tmux ];
    text = ''
      inventory="''${XDG_CONFIG_HOME:-$HOME/.config}/ollama-router/hosts.env"
      if [[ ! -r "$inventory" ]]; then
        printf 'Missing LiteLLM inventory: %s\nRun ~/Dev/Ollama/init-litellm-env first.\n' "$inventory" >&2
        exit 1
      fi
      # shellcheck disable=SC1090
      source "$inventory"
      if [[ -z "''${LITELLM_MASTER_KEY:-}" ]]; then
        printf 'LITELLM_MASTER_KEY is missing in %s\n' "$inventory" >&2
        exit 1
      fi

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

      exec ${piCore}/bin/pi "$@"
    '';
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

      rog_endpoint="''${OLLAMA_ROG_BASE_URL:-''${OLLAMA_ROG_URL:-http://rog-polamaniec.local:11434}}"
      white_endpoint="''${OLLAMA_WHITE_MONSTER_BASE_URL:-''${OLLAMA_WHITE_MONSTER_URL:-http://white-monster.local:11434}}"
      if [[ "''${rog_endpoint%/v1}" == "http://ollama:11434" ]]; then
        # `ollama` is the Compose-network name used by LiteLLM. This status
        # helper runs on the host, where the same service is published locally.
        rog_endpoint=http://127.0.0.1:11434
      fi
      jq -s '.' \
        <(check_host "rog-polamaniec" "''${rog_endpoint%/v1}" "''${OLLAMA_ROG_MODEL:-qwen3.5:9b}") \
        <(check_host "white-monster" "''${white_endpoint%/v1}" "''${OLLAMA_WHITE_MONSTER_MODEL:-qwen38-mtp2}")
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

in

{
  home.packages = [
    agentManager
    codexAgent
    # Pi installs the lazy MCP adapter through npm during Home Manager activation.
    pkgs.nodejs
    piLauncher
    updateAgentManager
  ] ++ lib.optionals farmEnabled [
    ollamaFarmStatus
  ];

  home.file = {
    ".pi/agent/settings.json".text = builtins.toJSON {
      defaultProvider = "litellm";
      defaultModel = "auto";
      defaultThinkingLevel = "off";
      defaultTools = [ "read" "write" "edit" "bash" ];
      quietStartup = true;
      enableInstallTelemetry = false;
      # Show compaction diagnostics in the transcript, so an incomplete local
      # model response is distinguishable from an Agent Manager display issue.
      showCacheMissNotices = true;
      compaction = {
        enabled = true;
        # A 64k local context needs room for the summary, tool-call retries,
        # and a 4096-token reply. Compact at ~53k and retain only the active
        # task tail; this avoids summaries themselves reaching the token cap.
        reserveTokens = 12288;
        keepRecentTokens = 8000;
      };
      packages = [ "npm:pi-mcp-adapter@2.31.0" ];
    };

    ".pi/agent/models.json".text = builtins.toJSON {
      providers.litellm = {
        baseUrl = "http://127.0.0.1:4000/v1";
        api = "openai-completions";
        apiKey = "$LITELLM_MASTER_KEY";
        authHeader = true;
        compat = {
          supportsDeveloperRole = false;
          supportsReasoningEffort = false;
        };
        models = piModels;
      };
    };

    ".pi/agent/SYSTEM.md".text = ''
      Read only the files needed for the task and make small local changes.
      Do not paste large files or logs when a focused read, rg search, or a
      short summary is enough. Keep tool output and each agent turn bounded;
      finish one coherent task before starting another. Run relevant tests after
      changes. Use MCP only when it is needed: SearXNG for current facts, Agent
      Manager for short, bounded delegation. Give each worker only its task,
      required files, and necessary decisions; do not forward chat history.
      Treat SPEC.md, PLAN.md, STATUS.md, and ARCHITECTURE.md as durable project
      memory. For large work, update PLAN.md and STATUS.md instead of relying on
      chat history.
    '';
  };

  xdg.configFile."mcp/mcp.json".text = builtins.toJSON {
    settings = {
      idleTimeout = 10;
      directTools = false;
      outputGuard = {
        maxBytes = 12000;
        maxLines = 300;
        detailsMaxBytes = 4000;
      };
    };
    mcpServers = {
      searxng = {
        command = "${searxngMcp}/bin/searxng-mcp";
        # pi-mcp-adapter passes env values literally; use the local published
        # SearXNG endpoint instead of an unexpanded shell placeholder.
        env.SEARXNG_URL = "http://127.0.0.1:8080";
        lifecycle = "lazy";
        idleTimeout = 5;
      };
      "agent-manager" = {
        command = "${agentManager}/bin/agent-manager";
        args = [ "mcp" ];
        env = {
          AGENT_MANAGER_SESSION_ID = "$AGENT_MANAGER_SESSION_ID";
          TMUX_TMPDIR = "$TMUX_TMPDIR";
          XDG_RUNTIME_DIR = "$XDG_RUNTIME_DIR";
        };
        lifecycle = "lazy";
        idleTimeout = 5;
      };
    };
  };

  # Pi packages are mutable runtime state below ~/.pi/agent/npm; the version
  # is pinned here and installed during the user-owned Home Manager activation.
  home.activation.installPiMcpAdapter = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD env PATH="${pkgs.nodejs}/bin:$PATH" ${piCore}/bin/pi install npm:pi-mcp-adapter@2.31.0
  '';

  # Cline was installed only through this Home Manager profile. Remove all of
  # its user-only state after the new Pi configuration has been written.
  home.activation.removeClineData = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD rm -rf "$HOME/.cline"
  '';

  # One Codex tool handles explicit Codex sessions. Pi is the sole local
  # coding-agent profile and receives its session identity from its launcher.
  xdg.configFile."agent-manager/config.toml".text = ''
    poll_interval = "2s"

    [tools.codex]
    command = "codex-agent"

    [tools.pi]
    command = "pi"
    default_status = "idle"
    session_id_flag = "--session-id"
    resume_by_id_command = "pi --session {id}"
    fork_command = "pi --session {id} --fork --session-id {new_id}"
    rules = [
      { state = "errored", pattern = "(?im)^\\s*error\\b" },
      { state = "working", pattern = "(?i)working|thinking|esc to interrupt" },
    ]
  '';
}
