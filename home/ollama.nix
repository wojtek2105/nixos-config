{ desktopFeatures, lib, pkgs, ... }:

let
  ollamaEnabled = desktopFeatures.ollama or false;
  ollamaFarmEnabled = desktopFeatures.ollamaFarm or false;
  openWebUiSystemPrompt = ''Zawsze odpowiadaj w języku ostatniej wiadomości użytkownika, chyba że użytkownik wyraźnie poprosi o inny język. Na polskie wiadomości odpowiadaj po polsku. Kod, polecenia, logi, nazwy API i identyfikatory pozostawiaj w oryginalnej formie.'';
  litellmModels = if ollamaFarmEnabled then ''
    model_list:
      - model_name: rog-qwen35-off
        litellm_params:
          model: os.environ/LITELLM_ROG_MODEL
          api_base: os.environ/LITELLM_ROG_API_BASE
          think: false
          additional_drop_params: [reasoning_effort]
      - model_name: rog-qwen35-thinking
        litellm_params:
          model: os.environ/LITELLM_ROG_MODEL
          api_base: os.environ/LITELLM_ROG_API_BASE
          think: true
          additional_drop_params: [reasoning_effort]
      - model_name: white-qwen38-off
        litellm_params:
          model: os.environ/LITELLM_WHITE_MODEL
          api_base: os.environ/LITELLM_WHITE_API_BASE
          think: false
          additional_drop_params: [reasoning_effort]
      - model_name: white-qwen38-low
        litellm_params:
          model: os.environ/LITELLM_WHITE_MODEL
          api_base: os.environ/LITELLM_WHITE_API_BASE
          think: low
          additional_drop_params: [reasoning_effort]
      - model_name: white-qwen38-medium
        litellm_params:
          model: os.environ/LITELLM_WHITE_MODEL
          api_base: os.environ/LITELLM_WHITE_API_BASE
          think: medium
          additional_drop_params: [reasoning_effort]
      - model_name: white-qwen38-xhigh
        litellm_params:
          model: os.environ/LITELLM_WHITE_MODEL
          api_base: os.environ/LITELLM_WHITE_API_BASE
          think: xhigh
          additional_drop_params: [reasoning_effort]
  '' else ''
    model_list:
      - model_name: local-qwen35-off
        litellm_params:
          model: os.environ/LITELLM_LOCAL_MODEL
          api_base: http://ollama:11434
          think: false
          additional_drop_params: [reasoning_effort]
      - model_name: local-qwen35-thinking
        litellm_params:
          model: os.environ/LITELLM_LOCAL_MODEL
          api_base: http://ollama:11434
          think: true
          additional_drop_params: [reasoning_effort]
  '';
in
{
  # Home Manager owns the stack definition and helper scripts. Runtime data and
  # generated secrets stay mutable below Dev/Ollama/data and outside the store.
  home.file = lib.mkIf ollamaEnabled {
    "Dev/Ollama/compose.yaml".text = ''
      services:
        open-webui:
          image: ghcr.io/open-webui/open-webui:main
          container_name: open-webui
          restart: unless-stopped
          ports:
            - "0.0.0.0:3000:8080"
          environment:
            OLLAMA_BASE_URL: http://ollama:11434
            ENABLE_OPENAI_API: "True"
            OPENAI_API_BASE_URL: http://litellm:4000/v1
            OPENAI_API_KEY: ollama
            OPENAI_API_BASE_URLS: http://litellm:4000/v1
            OPENAI_API_KEYS: ollama
            # Built-in search_web is available to Native function-calling
            # models; these limits keep fetched pages within a 16k context.
            ENABLE_WEB_SEARCH: "True"
            WEB_SEARCH_ENGINE: searxng
            SEARXNG_QUERY_URL: http://searxng:8080/search?q=<query>&format=json
            WEB_SEARCH_RESULT_COUNT: "3"
            WEB_LOADER_CONCURRENT_REQUESTS: "3"
            WEB_FETCH_MAX_CONTENT_LENGTH: "12000"
            # Capability makes search available; defaultFeatureIds also turns it
            # on for every new chat using a model without its own override.
            DEFAULT_MODEL_METADATA: '{"capabilities":{"web_search":true},"defaultFeatureIds":["web_search"]}'
            # New chats inherit Web Search and a language-following account
            # prompt. Per-model system prompts still have higher precedence.
            DEFAULT_INTERFACE_SETTINGS: '${builtins.toJSON {
              webSearch = "always";
              system = openWebUiSystemPrompt;
            }}'
            # Native tool calling and streaming are the safe global baseline.
            # Deliberately omit max_tokens: Ollama then lets each model stop
            # naturally, bounded only by its shared 16k context window.
            DEFAULT_MODEL_PARAMS: '{"function_calling":"native","stream":true}'
            # Summarize older chat turns before the 16k Ollama window is full.
            # Keep recent turns verbatim for tool state and immediate continuity.
            ENABLE_CONTEXT_COMPACTION: "True"
            CONTEXT_COMPACTION_TOKEN_THRESHOLD: "11000"
            CONTEXT_COMPACTION_TOKEN_CAP: "12000"
            CONTEXT_COMPACTION_RETENTION_PERCENTAGE: "40"
            TASK_MODEL_PARAMS: '{"temperature":0.2,"max_tokens":1200}'
          volumes:
            - ./data/open-webui:/app/backend/data
            # The reconciler changes only declared global ConfigVars in SQLite;
            # user accounts, chats, models and provider connections stay mutable.
            - ./apply-webui-defaults.py:/opt/ollama-stack/apply-webui-defaults.py:ro
          depends_on:
            - litellm

        litellm:
          image: docker.litellm.ai/berriai/litellm:main-stable
          container_name: litellm
          restart: unless-stopped
          command: ["--config", "/app/config.yaml", "--port", "4000"]
          ports:
            - "127.0.0.1:4000:4000"
          environment:
            ${if ollamaFarmEnabled then ''
            LITELLM_ROG_MODEL: "ollama_chat/''${OLLAMA_ROG_MODEL:-qwen3.5:9b}"
            LITELLM_ROG_API_BASE: "''${OLLAMA_ROG_BASE_URL:-http://ollama:11434}"
            LITELLM_WHITE_MODEL: "ollama_chat/''${OLLAMA_WHITE_MONSTER_MODEL:-qwen3.8:27b}"
            LITELLM_WHITE_API_BASE: "''${OLLAMA_WHITE_MONSTER_BASE_URL:-http://white-monster.local:11434}"
            '' else ''
            LITELLM_LOCAL_MODEL: "ollama_chat/''${OLLAMA_LOCAL_MODEL:-qwen3.5:9b}"
            ''}
          volumes:
            - ./litellm-config.yaml:/app/config.yaml:ro

        searxng:
          image: searxng/searxng:latest
          container_name: searxng
          # Make exports the invoking user's numeric IDs. Defaults match the
          # first regular NixOS user and its standard users group.
          user: "''${OLLAMA_UID:-1000}:''${OLLAMA_GID:-100}"
          restart: unless-stopped
          ports:
            - "0.0.0.0:8080:8080"
          environment:
            # The upstream default recursively changes bind mounts to its own
            # uid 977. Keep host-side files editable by the stack owner.
            FORCE_OWNERSHIP: "false"
            # This instance is LAN-only and has no Valkey service. Disabling
            # the public-instance limiter also avoids proxy-header checks.
            SEARXNG_LIMITER: "false"
          volumes:
            # Keep the complete mutable configuration directory together with
            # its generated secret. init-searxng-config creates settings.yml.
            - ./data/searxng/config:/etc/searxng
            - ./data/searxng/cache:/var/cache/searxng

        ollama-vulkan:
          profiles: ["vulkan"]
          image: ollama/ollama:latest
          container_name: ollama-vulkan
          restart: unless-stopped
          ports:
            - "0.0.0.0:11434:11434"
          devices:
            - /dev/kfd
            - /dev/dri
          environment:
            OLLAMA_VULKAN: "1"
            # 16k is a practical shared default for chat and web search. Flash
            # Attention plus an 8-bit KV cache keeps its VRAM cost manageable.
            OLLAMA_CONTEXT_LENGTH: "16384"
            OLLAMA_FLASH_ATTENTION: "1"
            OLLAMA_KV_CACHE_TYPE: q8_0
          volumes:
            - ./data/ollama-vulkan:/root/.ollama
          networks:
            default:
              aliases: ["ollama"]

        ollama-rocm:
          profiles: ["rocm"]
          image: ollama/ollama:rocm
          container_name: ollama-rocm
          restart: unless-stopped
          ports:
            - "0.0.0.0:11434:11434"
          devices:
            - /dev/kfd
            - /dev/dri
          environment:
            OLLAMA_CONTEXT_LENGTH: "16384"
            OLLAMA_FLASH_ATTENTION: "1"
            OLLAMA_KV_CACHE_TYPE: q8_0
          volumes:
            - ./data/ollama-rocm:/root/.ollama
          networks:
            default:
              aliases: ["ollama"]

        ollama-cpu:
          profiles: ["cpu"]
          image: ollama/ollama:latest
          container_name: ollama-cpu
          restart: unless-stopped
          ports:
            - "0.0.0.0:11435:11434"
          environment:
            OLLAMA_CONTEXT_LENGTH: "16384"
            OLLAMA_FLASH_ATTENTION: "1"
            OLLAMA_KV_CACHE_TYPE: q8_0
          volumes:
            - ./data/ollama-cpu:/root/.ollama
    '';

    "Dev/Ollama/litellm-config.yaml".text = litellmModels;

    "Dev/Ollama/README.md".text = ''
      # Ollama + Open WebUI

      ```bash
      sudo systemctl start docker
      cd ~/Dev/Ollama
      make vulkan  # laptop / bezpieczny fallback
      # albo: make rocm
      ```

      Open WebUI działa pod `http://ADRES-LAN:3000`, SearXNG pod
      `http://ADRES-LAN:8080`, API GPU pod `http://ADRES-LAN:11434`, a
      lokalny gateway LiteLLM pod `http://127.0.0.1:4000/v1`.
      Aktualny adres komputera pokaże `hostname -I`.

      Te porty są otwarte dla całej sieci lokalnej. Ollama i SearXNG nie mają
      uwierzytelniania, więc używaj tylko zaufanej sieci; w Open WebUI utwórz
      konto administratora przed dopuszczeniem innych użytkowników.

      Open WebUI ma już włączone web search przez SearXNG oraz kontekst Ollamy
      16k. Wyszukiwanie jest natywnym narzędziem modelu (Native function
      calling), a nie promptowym trybem Legacy. Przed uruchomieniem stosu cele
      `make vulkan`, `make rocm` i `make cpu` tworzą, jeśli go brakuje,
      `data/searxng/config/settings.yml`. Plik zawiera format JSON wymagany przez
      Open WebUI oraz unikalny 256-bitowy `server.secret_key`; sekret pozostaje
      wyłącznie w mutowalnym `data/` i nie trafia do Nix store ani Git. Po
      zmianie konfiguracji NixOS odtwórz stos przez `make down` i uruchom
      wybrany profil ponownie. Jeśli katalog pochodzi ze starszej wersji stosu
      i należy do `root`, `nobody` albo kontenerowego UID 977, jednorazowo
      uruchom `make fix-searxng-permissions`.

      Odpowiedzi są domyślnie strumieniowane token po tokenie, a Web Search jest
      włączony w każdym nowym czacie. Możesz je wyłączyć tylko dla konkretnego
      czatu lub modelu w jego Advanced Params.

      Open WebUI używa aliasów LiteLLM jako głównego katalogu modeli, ale
      zachowuje natywną Ollamę jako połączenie awaryjne. SearXNG nadal obsługuje
      Open WebUI bezpośrednio. Aliasy wymuszają `think` w gatewayu i ignorują
      przesłany `reasoning_effort`, dlatego nie przypinaj do nich Function
      `Reasoning Effort Selector`.

      Globalne parametry celowo nie zawierają `max_tokens`. Brak tego opcjonalnego
      pola pozwala każdemu modelowi zakończyć odpowiedź samodzielnie; rzeczywistą
      granicą pozostaje wspólne okno kontekstu 16k, obejmujące prompt, historię,
      wyniki narzędzi i odpowiedź. Limit `1200` dotyczy tylko krótkich zadań
      pomocniczych Open WebUI, a nie normalnych odpowiedzi czatu.

      Open WebUI zapisuje część ustawień administratora w SQLite. Po każdej
      zmianie tej konfiguracji NixOS uruchom wybrany profil, a następnie
      `make apply-webui-defaults`. Polecenie deklaratywnie synchronizuje tylko
      ustawienia stosu (WWW, SearXNG, streaming, kompaktowanie i globalne
      domyślne parametry), pokazuje diff zmienionych kluczy i restartuje sam
      panel. Nie usuwa modeli, kont, rozmów, ręcznych modeli ani endpointów API.

      Limit trzech wyników po maksymalnie 12 000 znaków chroni 16k kontekstu
      przed przepełnieniem stronami WWW. Model musi faktycznie obsługiwać native
      tool calling; dla małych modeli może być ono mniej niezawodne niż dla
      większych modeli na White Monsterze.

      Context Compaction działa automatycznie od około 11k tokenów: starsza
      część rozmowy jest streszczana, a ostatnie 40% wiadomości zostaje bez
      zmian. Pełna historia czatu nadal jest widoczna w GUI; skrót wpływa tylko
      na to, co jest wysyłane do modelu. Streszczenie używa aktualnego modelu
      zadań Open WebUI, więc dla ważnych długich rozmów wybierz do niego model
      mocniejszy niż mały worker.

      ## Qwen3.8: poziom reasoning w Open WebUI

      Awaryjne natywne połączenie Ollama pokazuje w modelu wyłącznie `Reasoning Tags`.
      Służą one do zwijania `<think>...</think>` i **nie** ustawiają poziomu
      reasoning. Dla tego połączenia używamy ręcznie zainstalowanej Function
      [Reasoning Effort Selector](https://openwebui.com/posts/reasoning_effort_selector_ee572967).
      Function jest zewnętrznym kodem Python, więc przed aktualizacją należy
      przeczytać jego źródło w GUI.

      Aby wybór nie wymagał każdorazowego klikania ikonki rombów przy polu
      wiadomości, administrator ustawia Function jako filtr domyślny:

      1. `Workspace -> Functions`: włącz `Reasoning Effort`, a w menu `...`
         zaznacz ikonę globu, aby filtr był globalny.
      2. `Workspace -> Models -> <Qwen3.8> -> Filters`: zaznacz `Reasoning
         Effort`.
      3. W `Default Filters` wybierz `Reasoning Effort`, po czym otwórz nowy
         czat. Funkcja jest wtedy aktywna automatycznie dla tego modelu.
      4. W ustawieniach/Valve Function wybierz `low` jako wartość domyślną.

      Dla Qwen3.8 poprawne poziomy to `low`, `medium` i `xhigh` — nie `high`.
      Zmiana dotyczy następnej wiadomości; nie zmienia odpowiedzi, które już
      powstały. Gdy plugin nie zapamięta wartości Valve po nowym czacie, nie
      wybieraj go ręcznie przy każdej wiadomości: zostaw filtr jako domyślny i
      ustaw wartość globalną w jego konfiguracji.

      ${if !ollamaFarmEnabled then ''
      ## Lokalny Cline w Agent Managerze

      Profile `local-off` i `local-thinking` używają wyłącznie lokalnej Ollamy
      przez LiteLLM. `local-off` jest kierownikiem; domyślnym modelem jest
      `qwen3.5:9b`. Nadpisanie przechowuj poza Git w pliku
      `~/.config/ollama-router/hosts.env`:

      ```bash
      OLLAMA_LOCAL_MODEL=qwen3.5:9b
      ```

      Po zmianie modelu wykonaj `make restart-litellm`, aby odtworzyć gateway
      z nową wartością zmiennej.

      `local-off` może przez MCP utworzyć lokalnego workera albo, tylko dla
      naprawdę trudnego zadania, workera `codex`. Profile ROG, White Monster i
      `ollama-farm-status` nie są na tym hoście
      instalowane ani pokazywane w selektorze Agent Managera.

      Przed pierwszym uruchomieniem pobierz model do lokalnego kontenera:

      ```bash
      docker compose --profile rocm exec ollama-rocm ollama pull qwen3.5:9b
      ```

      Profile wymuszają odpowiednio `think=false` i `think=true` dla Qwena 3.5.
      Zwykłe `cline` uruchamia profil off. Playwright jest dostępny w ekranie
      MCP tego samego TUI, ale pozostaje domyślnie wyłączony.

      Agent Manager 0.33 zawsze dodaje wbudowany wpis `opencode`. Jest to tylko
      alias zgodnościowy uruchamiający Cline; możesz ukryć go raz przez
      `s -> CLIs`, odznaczając `opencode`.
      '' else ''
      ## Local workers in Agent Manager

      Profile `rog-polamaniec-off` i `rog-polamaniec-thinking` uruchamiają
      Qwena 3.5 9B. `rog-polamaniec-off` jest kierownikiem; model obu zmieniasz
      w `OLLAMA_ROG_MODEL`.

      ## Lokalny manager całej farmy modeli

      Agent Manager udostępnia dwa profile ROG i po skonfigurowaniu White
      Monstera cztery profile Qwena 3.8. `rog-polamaniec-off` działa domyślnie
      na Qwenie 3.5 9B bez thinking,
      może wykonywać zadania samodzielnie i przez MCP domyślnie tworzy workery
      Cline/Ollama. Naprawdę trudną architekturę, diagnozę, integrację lub
      przegląd wysokiego ryzyka przekazuje najpierw do większego Qwena na
      `white-monster`. Ten worker może przez MCP uruchomić Codexa, jeśli lokalne
      rozumowanie nie wystarczy. Gdy White Monster jest niedostępny, manager może
      uruchomić Codexa bezpośrednio. Sonda sprawdza dostępność i czas odpowiedzi
      API oraz wykrywa już załadowany model, ale nie mierzy kolejki generowania.

      Na każdym koncie używającym panelu utwórz prywatny plik
      `~/.config/ollama-router/hosts.env` (nie zapisuj go w Git) z adresami LAN
      i domyślnym modelem każdego hosta:

      ```bash
      OLLAMA_ROG_BASE_URL=http://192.168.1.10:11434
      OLLAMA_ROG_MODEL=qwen3.5:9b
      OLLAMA_WHITE_MONSTER_BASE_URL=http://192.168.1.20:11434
      OLLAMA_WHITE_MONSTER_MODEL=qwen3.8:27b
      ```

      Cele startowe same tworzą brakujący plik i migrują starsze zmienne URL.
      Po ręcznej zmianie inventory wykonaj `make restart-litellm`, aby odtworzyć
      kontener z nowym środowiskiem.

      Przed pierwszym uruchomieniem routera pobierz jego model na ROG-u:

      ```bash
      docker compose --profile vulkan exec ollama-vulkan ollama pull qwen3.5:9b
      ```

      Qwen 3.5 ma aliasy `off` i `thinking`, a Qwen3.8 `off`, `low`, `medium`
      i `xhigh`. Zwykłe `cline` uruchamia profil off. Poziom zmieniasz przez
      `/model`, wybierając inny alias bez utraty kontekstu. Playwright jest zarejestrowany w
      każdym profilu, ale domyślnie wyłączony, aby nie obciążać sesji Qwena
      jego schematami narzędzi.

      Każdy wpis modelu musi istnieć na wskazanym hoście. Adresy odczytasz na
      nim przez `hostname -I`; użyj stałych adresów DHCP lub własnego DNS.
      Farmę można uruchamiać etapami: nieskonfigurowany host będzie oznaczony
      jako `unavailable` i manager go nie wybierze, więc początkowo może działać
      wyłącznie ROG.
      Następnie uruchom `agent-manager` i utwórz sesję `rog-polamaniec-off`.
      Polecenie `ollama-farm-status` pokazuje ręcznie ten sam status, którego
      manager używa przed wyborem workera. Aby pracować po wyczerpaniu limitu,
      poleć managerowi działać wyłącznie lokalnie; po błędzie limitu sam nie
      ponowi Codexa. Kontekst nie jest przenoszony automatycznie pomiędzy CLI.

      Agent Manager 0.33 zawsze dodaje wbudowany wpis `opencode`. Jest to tylko
      zgodnościowy alias przekierowany tutaj do profilu off; OpenCode nie jest
      instalowany. Możesz ukryć go raz przez `s -> CLIs`, odznaczając
      `opencode`. Cline zachowuje historię w `~/.cline/`; zamknięcie samego
      panelu pozostawia działające sesje tmux bez zmian.
      ''}

      Zmiana GPU wymaga najpierw zatrzymania poprzedniego wariantu:

      ```bash
      make down
      make rocm
      ```

      Opcjonalny drugi serwer CPU:

      ```bash
      make rocm-cpu
      ```

      CPU API działa na `127.0.0.1:11435`; dodaj je ręcznie w Open WebUI jako
      `http://ollama-cpu:11434`. Zatrzymanie: `make down`. Aktualizacja obrazów:
      `make pull-rocm`, potem ponownie `make rocm`.

      `data/` zawiera modele, konta, konfigurację Open WebUI oraz lokalny sekret
      SearXNG. Nie usuwaj go, chyba że celowo chcesz skasować te dane.
    '';

    "Dev/Ollama/init-searxng-config" = {
      executable = true;
      text = ''
        #!${pkgs.runtimeShell}
        set -euo pipefail

        config_dir="data/searxng/config"
        settings_file="$config_dir/settings.yml"
        limiter_file="$config_dir/limiter.toml"

        write_settings() {
          secret_value="$1"
          output_file="$2"
          {
            printf '%s\n' \
              '# Generated locally by ./init-searxng-config; never commit this file.' \
              'use_default_settings:' \
              '  engines:' \
              '    remove:' \
              '      - ahmia' \
              '      - torch' \
              "" \
              'server:'
            printf '  secret_key: "%s"\n' "$secret_value"
            printf '%s\n' \
              '  limiter: false' \
              '  public_instance: false' \
              "" \
              'search:' \
              '  formats:' \
              '    - html' \
              '    - json'
          } > "$output_file"
          ${pkgs.coreutils}/bin/chmod 600 "$output_file"
        }

        ${pkgs.coreutils}/bin/mkdir -p "$config_dir"
        if [[ ! -e "$limiter_file" ]]; then
          # Current SearXNG loads this file even when the limiter is disabled.
          # An empty file silences its known missing-file warning.
          ${pkgs.coreutils}/bin/install -m 644 /dev/null "$limiter_file"
        fi

        if [[ -e "$settings_file" ]]; then
          if ${pkgs.gnugrep}/bin/grep -q \
            '^# Generated locally by ./init-searxng-config' "$settings_file"; then
            secret="$(${pkgs.gnused}/bin/sed -nE \
              's/^[[:space:]]*secret_key:[[:space:]]*"([0-9a-f]{64})"[[:space:]]*$/\1/p' \
              "$settings_file")"
            if [[ -z "$secret" ]]; then
              printf 'Cannot preserve the generated SearXNG secret in: %s\n' \
                "$settings_file" >&2
              exit 1
            fi
            temporary_file="$(${pkgs.coreutils}/bin/mktemp "$config_dir/.settings.yml.XXXXXX")"
            trap '${pkgs.coreutils}/bin/rm -f "$temporary_file"' EXIT
            write_settings "$secret" "$temporary_file"
            ${pkgs.coreutils}/bin/mv "$temporary_file" "$settings_file"
            trap - EXIT
            printf 'Updated generated SearXNG config while preserving its secret: %s\n' \
              "$settings_file"
            exit 0
          fi
          if ${pkgs.gnugrep}/bin/grep -q 'ultrasecretkey' "$settings_file"; then
            secret="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
            temporary_file="$(${pkgs.coreutils}/bin/mktemp "$config_dir/.settings.yml.XXXXXX")"
            trap '${pkgs.coreutils}/bin/rm -f "$temporary_file"' EXIT
            ${pkgs.gnused}/bin/sed "s/ultrasecretkey/$secret/g" \
              "$settings_file" > "$temporary_file"
            ${pkgs.coreutils}/bin/chmod 600 "$temporary_file"
            ${pkgs.coreutils}/bin/mv "$temporary_file" "$settings_file"
            trap - EXIT
            printf 'Replaced the default SearXNG secret in: %s\n' "$settings_file"
            exit 0
          fi
          if ! ${pkgs.gnugrep}/bin/grep -Eq '^[[:space:]]*secret_key:' "$settings_file"; then
            printf 'SearXNG config exists but has no server.secret_key: %s\n' \
              "$settings_file" >&2
            printf 'Move it aside and run make init-searxng-config again.\n' >&2
            exit 1
          fi
          printf 'SearXNG config already exists: %s\n' "$settings_file"
          exit 0
        fi

        secret="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
        temporary_file="$(${pkgs.coreutils}/bin/mktemp "$config_dir/.settings.yml.XXXXXX")"
        trap '${pkgs.coreutils}/bin/rm -f "$temporary_file"' EXIT

        write_settings "$secret" "$temporary_file"
        ${pkgs.coreutils}/bin/mv "$temporary_file" "$settings_file"
        trap - EXIT
        printf 'Created SearXNG config with a new local secret: %s\n' "$settings_file"
      '';
    };

    "Dev/Ollama/init-litellm-env" = {
      executable = true;
      text = ''
        #!${pkgs.runtimeShell}
        set -euo pipefail

        config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/ollama-router"
        config_file="$config_dir/hosts.env"
        ${pkgs.coreutils}/bin/mkdir -p "$config_dir"

        if [[ -r "$config_file" ]]; then
          # Preserve the user's existing inventory and migrate the older /v1
          # endpoint names only when the new LiteLLM base variables are absent.
          # shellcheck disable=SC1090
          source "$config_file"
        else
          printf '%s\n' '# Local Ollama farm inventory; never commit this file.' \
            > "$config_file"
        fi

        ensure_setting() {
          local key="$1" value="$2"
          if ! ${pkgs.gnugrep}/bin/grep -q "^$key=" "$config_file"; then
            printf '%s=%s\n' "$key" "$value" >> "$config_file"
          fi
        }

        ${if ollamaFarmEnabled then ''
        legacy_rog="''${OLLAMA_ROG_URL:-http://ollama:11434}"
        legacy_white="''${OLLAMA_WHITE_MONSTER_URL:-http://white-monster.local:11434}"
        case "''${legacy_rog%/v1}" in
          http://127.0.0.1:*|http://localhost:*)
            # LiteLLM runs in Compose, where loopback points at LiteLLM itself.
            # The Ollama service is reachable through its network alias.
            legacy_rog_base=http://ollama:11434
            ;;
          *)
            legacy_rog_base="''${legacy_rog%/v1}"
            ;;
        esac
        ensure_setting OLLAMA_ROG_BASE_URL "$legacy_rog_base"
        if ${pkgs.gnugrep}/bin/grep -Eq \
          '^OLLAMA_ROG_BASE_URL=http://(127\.0\.0\.1|localhost):11434(/v1)?$' \
          "$config_file"; then
          ${pkgs.gnused}/bin/sed -E -i \
            's#^OLLAMA_ROG_BASE_URL=http://(127\.0\.0\.1|localhost):11434(/v1)?$#OLLAMA_ROG_BASE_URL=http://ollama:11434#' \
            "$config_file"
        fi
        ensure_setting OLLAMA_ROG_MODEL "''${OLLAMA_ROG_MODEL:-qwen3.5:9b}"
        ensure_setting OLLAMA_WHITE_MONSTER_BASE_URL "''${legacy_white%/v1}"
        ensure_setting OLLAMA_WHITE_MONSTER_MODEL "''${OLLAMA_WHITE_MONSTER_MODEL:-qwen3.8:27b}"
        '' else ''
        ensure_setting OLLAMA_LOCAL_MODEL "''${OLLAMA_LOCAL_MODEL:-qwen3.5:9b}"
        ''}

        ${pkgs.coreutils}/bin/chmod 600 "$config_file"
        printf 'LiteLLM inventory ready: %s\n' "$config_file"
      '';
    };

    "Dev/Ollama/apply-webui-defaults.py".text = ''
      #!/usr/bin/env python3
      """Reconcile only stack-owned Open WebUI ConfigVars without clearing data."""

      import json
      import sqlite3
      import time
      from pathlib import Path

      database = Path("/app/backend/data/webui.db")
      if not database.is_file():
          raise SystemExit("Open WebUI database does not exist; start the stack first.")

      desired = {
          "chat.context_compaction.enable": True,
          "chat.context_compaction.token_threshold": 11000,
          "chat.context_compaction.token_cap": 12000,
          "chat.context_compaction.retention_percentage": 40,
          "models.default_metadata": {
              "capabilities": {"web_search": True},
              "defaultFeatureIds": ["web_search"],
          },
          # Omitting max_tokens removes the global response cap; inserting a
          # large number would consume the same 16k window used by chat context.
          "models.default_params": {"function_calling": "native", "stream": True},
          "openai.enable": True,
          "openai.api_base_urls": ["http://litellm:4000/v1"],
          "openai.api_keys": ["ollama"],
          "openai.api_configs": {"0": {"enable": True}},
          "task.model.params": {"temperature": 0.2, "max_tokens": 1200},
          "ui.default_interface_settings": {
              "webSearch": "always",
              "system": ${builtins.toJSON openWebUiSystemPrompt},
          },
          "web.search.enable": True,
          "web.search.engine": "searxng",
          "web.search.searxng_query_url": "http://searxng:8080/search?q=<query>&format=json",
          "web.search.result_count": 3,
          "web.loader.concurrent_requests": 3,
          "web.fetch.max_content_length": 12000,
      }

      updated_at = int(time.time())
      with sqlite3.connect(database) as connection:
          previous = dict(
              connection.execute(
                  "SELECT key, value FROM config WHERE key IN ({})".format(
                      ",".join("?" for _ in desired)
                  ),
                  tuple(desired),
              )
          )
          changes = []
          for key, value in desired.items():
              raw_previous = previous.get(key)
              if isinstance(raw_previous, (str, bytes, bytearray)):
                  try:
                      previous_value = json.loads(raw_previous)
                  except (json.JSONDecodeError, UnicodeDecodeError):
                      previous_value = raw_previous
              else:
                  # SQLite is dynamically typed. Older Open WebUI versions may
                  # have stored booleans or numbers directly instead of JSON text.
                  previous_value = raw_previous

              if previous_value != value or type(previous_value) is not type(value):
                  changes.append((key, previous_value, value))

              connection.execute(
                  """
                  INSERT INTO config (key, value, updated_at) VALUES (?, ?, ?)
                  ON CONFLICT(key) DO UPDATE SET
                    value = excluded.value,
                    updated_at = excluded.updated_at
                  """,
                  (key, json.dumps(value), updated_at),
              )

      if not changes:
          print("Open WebUI defaults: no changes.")
      else:
          print(f"Open WebUI defaults: {len(changes)} change(s).")
          for key, previous_value, value in changes:
              try:
                  before = json.dumps(previous_value, ensure_ascii=False, sort_keys=True)
              except TypeError:
                  before = repr(previous_value)
              after = json.dumps(value, ensure_ascii=False, sort_keys=True)
              print(f"~ {key}\n  - {before}\n  + {after}")
    '';

    "Dev/Ollama/Makefile".text = ''
      .DEFAULT_GOAL := help
      .RECIPEPREFIX := >

      OLLAMA_UID := $(shell id -u)
      OLLAMA_GID := $(shell id -g)
      export OLLAMA_UID OLLAMA_GID

      STACK_CONFIG_HOME := $(if $(XDG_CONFIG_HOME),$(XDG_CONFIG_HOME),$(HOME)/.config)
      HOSTS_ENV := $(STACK_CONFIG_HOME)/ollama-router/hosts.env
      COMPOSE := docker-compose --env-file $(HOSTS_ENV)

      MODEL ?=

      .PHONY: help fix-searxng-permissions init-searxng-config init-litellm-env init-stack-config vulkan rocm cpu vulkan-cpu rocm-cpu down apply-webui-defaults pull pull-vulkan pull-rocm pull-cpu pull-searxng pull-litellm restart-litellm restart-searxng logs

      help: ## 📖 Pokaż dostępne polecenia
      >@awk 'BEGIN { FS = ":.*## " } /^[a-zA-Z0-9][a-zA-Z0-9_.-]*:.*## / && $$1 != "help" { printf "\033[36m%-20s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

      fix-searxng-permissions: ## 🔧 Oddaj katalogi SearXNG bieżącemu użytkownikowi
      >sudo chown -R $(OLLAMA_UID):$(OLLAMA_GID) data/searxng

      init-searxng-config: ## 🔐 Utwórz lokalną konfigurację i sekret SearXNG, jeśli ich brakuje
      >./init-searxng-config

      init-litellm-env: ## 🧭 Utwórz lub uzupełnij prywatny inventory LiteLLM
      >./init-litellm-env

      init-stack-config: init-searxng-config init-litellm-env ## ⚙️ Przygotuj lokalne pliki stosu

      vulkan: init-stack-config ## ⚡ Uruchom Ollama z backendem Vulkan
      >$(COMPOSE) --profile vulkan up -d

      rocm: init-stack-config ## 🔴 Uruchom Ollama z backendem ROCm
      >$(COMPOSE) --profile rocm up -d

      cpu: init-stack-config ## 🖥️ Uruchom Ollama tylko na CPU
      >$(COMPOSE) --profile cpu up -d

      vulkan-cpu: init-stack-config ## ⚡🖥️ Uruchom backend Vulkan oraz dodatkowy serwer CPU
      >$(COMPOSE) --profile vulkan --profile cpu up -d

      rocm-cpu: init-stack-config ## 🔴🖥️ Uruchom backend ROCm oraz dodatkowy serwer CPU
      >$(COMPOSE) --profile rocm --profile cpu up -d

      down: init-litellm-env ## 🛑 Zatrzymaj stos wraz ze wszystkimi profilami Ollamy
      >$(COMPOSE) --profile vulkan --profile rocm --profile cpu down

      apply-webui-defaults: init-litellm-env ## ⚙️ Zsynchronizuj globalne ustawienia Open WebUI bez kasowania danych
      >$(COMPOSE) exec -T open-webui python /opt/ollama-stack/apply-webui-defaults.py
      >$(COMPOSE) restart open-webui

      pull-vulkan: init-litellm-env ## ⬇️ Pobierz obrazy wariantu Vulkan
      >$(COMPOSE) --profile vulkan pull

      pull-rocm: init-litellm-env ## ⬇️ Pobierz obrazy wariantu ROCm
      >$(COMPOSE) --profile rocm pull

      pull-cpu: init-litellm-env ## ⬇️ Pobierz obrazy wariantu CPU
      >$(COMPOSE) --profile cpu pull

      pull-searxng: init-litellm-env ## ⬇️ Pobierz obraz SearXNG
      >$(COMPOSE) pull searxng

      pull-litellm: init-litellm-env ## ⬇️ Pobierz stabilny obraz LiteLLM
      >$(COMPOSE) pull litellm

      restart-litellm: init-litellm-env ## 🔄 Odtwórz LiteLLM po zmianie inventory
      >$(COMPOSE) up -d --force-recreate litellm

      pull: init-litellm-env ## 🤖 Pobierz model do uruchomionej Ollamy: make pull MODEL=qwen3.5:9b
      >@test -n "$(MODEL)" || { echo "Podaj MODEL=nazwa:model" >&2; exit 2; }
      >@for service in ollama-vulkan ollama-rocm ollama-cpu; do \
      >  if $(COMPOSE) ps -q "$$service" | grep -q .; then \
      >    $(COMPOSE) exec "$$service" ollama pull "$(MODEL)"; \
      >    exit $$?; \
      >  fi; \
      >done; \
      >echo "Nie działa żaden kontener Ollamy — uruchom najpierw make vulkan, make rocm albo make cpu" >&2; \
      >exit 1

      restart-searxng: init-stack-config ## 🔄 Zrestartuj SearXNG
      >$(COMPOSE) restart searxng

      logs: init-litellm-env ## 📜 Śledź logi wszystkich kontenerów
      >$(COMPOSE) logs --follow
    '';
  };
}
