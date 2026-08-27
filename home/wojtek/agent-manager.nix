{ lib, pkgs, ... }:

let
  version = "0.33.0";

  agentManager = pkgs.stdenvNoCC.mkDerivation {
    pname = "agent-manager";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/YoanWai/agent-manager/releases/download/v${version}/agent-manager_${version}_linux_amd64.tar.gz";
      hash = "sha256-rne6ZzaPolj4JySB8Q2YohGcoIAy5BVFOF3EIToAWDw=";
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
          pkgs.libnotify
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

  managerInstructions = ''
    You are the primary manager for a visible Agent Manager team. Keep ownership
    of requirements, decomposition, coordination, review, and the final answer.
    Delegate independent, bounded work through the Agent Manager MCP server by
    calling create_session with tool="codex"; those sessions are the workers.
    Prefer a separate git worktree for parallel write tasks. Use the shared task
    list, file reservations, messages, and wait_for_session to coordinate them.
    Inspect and integrate their results instead of forwarding them blindly.
    Do not create more than four worker sessions unless the user explicitly asks
    for a larger team. Do not use Codex native subagents: every worker must stay
    visible and controllable in Agent Manager.
  '';

  workerInstructions = ''
    You are an execution worker managed by a primary Codex session. Complete the
    bounded task you were assigned, stay within its scope, and return concrete
    evidence and a concise handoff to the manager. Use Agent Manager messages,
    tasks, and file reservations for coordination. Do not spawn more sessions or
    native Codex subagents. Escalate blockers to the manager instead of silently
    broadening the task.
  '';

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

  # Luna keeps frequent planning and coordination responsive at a low cost;
  # medium reasoning is enough to decompose work and review worker handoffs.
  codexManager = mkCodexLauncher "codex-manager" "gpt-5.6-luna" "medium" managerInstructions;

  # Terra gives workers stronger implementation and review capability than the
  # manager. Medium reasoning keeps several concurrent workers responsive and
  # economical; increase it only for a task with a measured quality need.
  codexWorker = mkCodexLauncher "codex-worker" "gpt-5.6-terra" "medium" workerInstructions;

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
      module_path="$repo_root/home/wojtek/agent-manager.nix"

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
      hash_matches="$(grep -Ec '^      hash = "sha256-[^"]+";$' "$module_path")"
      if [[ "$version_matches" != 1 || "$hash_matches" != 1 ]]; then
        printf 'Odmowa zmiany: format wersji lub hasha w %s jest nieoczekiwany.\n' "$module_path" >&2
        exit 1
      fi

      updated="$update_tmp/agent-manager.nix"
      sed -E \
        -e "s|^  version = \"[0-9]+\.[0-9]+\.[0-9]+\";|  version = \"$latest_version\";|" \
        -e "s|^      hash = \"sha256-[^\"]+\";|      hash = \"$sri_hash\";|" \
        "$module_path" > "$updated"

      if cmp -s "$module_path" "$updated"; then
        printf 'Agent Manager %s jest już przypięty.\n' "$tag"
        exit 0
      fi

      install -m 0644 "$updated" "$module_path"
      printf 'Przypięto Agent Manager %s. Sprawdź diff i uruchom walidację Nix.\n' "$tag"
      git -C "$repo_root" diff -- home/wojtek/agent-manager.nix
    '';
  };
in

{
  home.packages = [
    agentManager
    codexManager
    codexWorker
    updateAgentManager
  ];

  # `codex` is the worker tool so create_session(tool="codex") always gets the
  # stronger Terra/high profile. The separately named Luna/medium manager
  # profile is selected only for
  # the root session. Missing fields in the built-in `codex` block are filled
  # from Agent Manager v0.33.0 defaults without rewriting this managed file.
  xdg.configFile."agent-manager/config.toml".text = ''
    poll_interval = "2s"

    [tools.codex]
    command = "codex-worker"

    [tools.codex-manager]
    command = "codex-manager"
    session_store = "codex"
    resume_by_id_command = "codex-manager resume {id}"
    fork_command = "codex-manager fork {id}"
    revive_command = "codex-manager resume --last"
    mcp = "codex"
    default_status = "idle"
    activity_cutoff = "(?m)^›"
    turn_end = "(?m)^─+ Worked for [\\dhms. ]+─"
    chrome_line = "^\\s*─*\\s*$"
    limit_line = "(?m)You've hit your usage limit"
    rules = [
      { state = "waiting", pattern = "(?m)^\\s*›\\s+\\d+\\." },
      { state = "waiting", pattern = "(?m)Press enter to (confirm|continue)\\b" },
      { state = "waiting", pattern = "(?m)enter to submit answer\\b" },
      { state = "working", pattern = "(?m)^[ \\t]*(?:• )?[^\\n]*\\([\\dhms. ]+ [•·] esc to interrupt\\)(?: · [^\\n]*)?[ \\t]*\\n(?:[ \\t]+└[^\\n]*\\n(?:[ \\t]{4}[^\\n]*\\n)*)?[ \\t\\n]*\\z" },
      { state = "errored", pattern = "(?im)^\\s*■.*\\berror\\b" },
    ]
  '';
}
