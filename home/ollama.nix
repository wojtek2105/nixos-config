{ desktopFeatures, lib, pkgs, ... }:

let
  ollamaEnabled = desktopFeatures.ollama or false;
  ollamaFarmEnabled = desktopFeatures.ollamaFarm or false;
  autoAiRouterEnabled = desktopFeatures.autoAiRouter or false;
  openWebUiSystemPrompt = ''Zawsze odpowiadaj w języku ostatniej wiadomości użytkownika, chyba że użytkownik wyraźnie poprosi o inny język. Na polskie wiadomości odpowiadaj po polsku. Kod, polecenia, logi, nazwy API i identyfikatory pozostawiaj w oryginalnej formie.'';
  mkOllamaAlias = model_name: model: api_base: think: {
    inherit model_name;
    litellm_params = {
      inherit api_base model;
      # Pi sends OpenAI's persistence hint; Ollama rejects it.
      additional_drop_params = [ "reasoning_effort" "store" ];
    } // lib.optionalAttrs (think != null) { inherit think; };
  };
  logicalAliases = lib.optionals autoAiRouterEnabled [
    {
      model_name = "auto";
      # AUTO calls only router/vision/reasoning/coder through this gateway.
      # None of those aliases can point back here, preventing recursion.
      litellm_params = {
        model = "openai/auto";
        api_base = "http://host.docker.internal:4100/v1";
        api_key = "auto-internal";
      };
    }
    (mkOllamaAlias "router" "os.environ/LITELLM_ROUTER_MODEL" "os.environ/LITELLM_ROG_API_BASE" false)
    (mkOllamaAlias "vision" "os.environ/LITELLM_ROUTER_MODEL" "os.environ/LITELLM_ROG_API_BASE" false)
    # Ollama maps every explicit `think` level to reasoning_effort and cannot
    # carry xhigh. Omitting it preserves Qwen3.8's documented template default.
    (mkOllamaAlias "reasoning" "os.environ/LITELLM_WHITE_MODEL" "os.environ/LITELLM_WHITE_API_BASE" null)
    (mkOllamaAlias "coder" "os.environ/LITELLM_CODER_MODEL" "os.environ/LITELLM_CODER_API_BASE" "low")
  ];
  farmCompatibilityAliases = [
    (mkOllamaAlias "rog-qwen35-off" "os.environ/LITELLM_ROG_MODEL" "os.environ/LITELLM_ROG_API_BASE" false)
    (mkOllamaAlias "rog-qwen35-thinking" "os.environ/LITELLM_ROG_MODEL" "os.environ/LITELLM_ROG_API_BASE" true)
    (mkOllamaAlias "white-qwen38-off" "os.environ/LITELLM_WHITE_MODEL" "os.environ/LITELLM_WHITE_API_BASE" false)
    (mkOllamaAlias "white-qwen38-low" "os.environ/LITELLM_WHITE_MODEL" "os.environ/LITELLM_WHITE_API_BASE" "low")
    (mkOllamaAlias "white-qwen38-medium" "os.environ/LITELLM_WHITE_MODEL" "os.environ/LITELLM_WHITE_API_BASE" "medium")
    (mkOllamaAlias "white-qwen38-xhigh" "os.environ/LITELLM_WHITE_MODEL" "os.environ/LITELLM_WHITE_API_BASE" null)
  ];
  localAliases = [
    (mkOllamaAlias "local-qwen35-off" "os.environ/LITELLM_LOCAL_MODEL" "http://ollama:11434" false)
    (mkOllamaAlias "local-qwen35-thinking" "os.environ/LITELLM_LOCAL_MODEL" "http://ollama:11434" true)
  ];
  # JSON is valid YAML and avoids indentation-sensitive generated fragments.
  litellmModels = builtins.toJSON {
    model_list = if ollamaFarmEnabled
      then logicalAliases ++ farmCompatibilityAliases
      else localAliases;
    # Keep the gateway key outside Git/Nix store and inject it from hosts.env;
    # inference and both model catalogs remain authenticated.
    general_settings.master_key = "os.environ/LITELLM_MASTER_KEY";
  };
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
            ENABLE_OLLAMA_API: "${if autoAiRouterEnabled then "False" else "True"}"
            ENABLE_OPENAI_API: "True"
            OPENAI_API_BASE_URL: http://litellm:4000/v1
            LITELLM_MASTER_KEY: "''${LITELLM_MASTER_KEY:?Run ./init-litellm-env first}"
            OPENAI_API_KEY: "''${LITELLM_MASTER_KEY:?Run ./init-litellm-env first}"
            OPENAI_API_BASE_URLS: http://litellm:4000/v1
            OPENAI_API_KEYS: "''${LITELLM_MASTER_KEY:?Run ./init-litellm-env first}"
            # Built-in search_web is available to Native function-calling
            # models; these limits keep fetched pages bounded within the 64k
            # shared context window.
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
            # naturally, bounded only by its shared 64k context window.
            DEFAULT_MODEL_PARAMS: '{"function_calling":"native","stream":true}'
            # Summarize older chat turns before the 64k Ollama window is full.
            # Keep recent turns verbatim for tool state and immediate continuity.
            ENABLE_CONTEXT_COMPACTION: "True"
            CONTEXT_COMPACTION_TOKEN_THRESHOLD: "48000"
            CONTEXT_COMPACTION_TOKEN_CAP: "52000"
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
            - "${if autoAiRouterEnabled then "0.0.0.0" else "127.0.0.1"}:4000:4000"
          environment:
            LITELLM_MASTER_KEY: "''${LITELLM_MASTER_KEY:?Run ./init-litellm-env first}"
            LITELLM_ROG_MODEL: "ollama_chat/''${OLLAMA_ROG_MODEL:-qwen3.5:9b}"
            LITELLM_ROUTER_MODEL: "ollama_chat/''${OLLAMA_ROUTER_MODEL:-qwen3.5:4b}"
            LITELLM_ROG_API_BASE: "''${OLLAMA_ROG_BASE_URL:-http://ollama:11434}"
            LITELLM_WHITE_MODEL: "ollama_chat/''${OLLAMA_WHITE_MONSTER_MODEL:-qwen38-mtp2}"
            LITELLM_WHITE_API_BASE: "''${OLLAMA_WHITE_MONSTER_BASE_URL:-http://white-monster.local:11434}"
            LITELLM_CODER_MODEL: "ollama_chat/''${OLLAMA_CODER_MODEL:-qwen38-mtp2}"
            LITELLM_CODER_API_BASE: "''${OLLAMA_CODER_BASE_URL:-http://white-monster.local:11434}"
            LITELLM_LOCAL_MODEL: "ollama_chat/''${OLLAMA_LOCAL_MODEL:-qwen3.5:9b}"
          volumes:
            - ./litellm-config.yaml:/app/config.yaml:ro
          extra_hosts:
            - "host.docker.internal:host-gateway"

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
            # 64k is the shared limit for Pi and Open WebUI. Flash Attention
            # enables q8 KV cache with negligible quality loss at long context.
            OLLAMA_CONTEXT_LENGTH: "65536"
            OLLAMA_FLASH_ATTENTION: "1"
            OLLAMA_KV_CACHE_TYPE: q8_0
            # One 64k context is the safe VRAM budget for the large MTP model;
            # higher values multiply its cache allocation instead of speeding it up.
            OLLAMA_NUM_PARALLEL: "1"
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
            OLLAMA_CONTEXT_LENGTH: "65536"
            OLLAMA_FLASH_ATTENTION: "1"
            OLLAMA_KV_CACHE_TYPE: q8_0
            OLLAMA_NUM_PARALLEL: "1"
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
            OLLAMA_CONTEXT_LENGTH: "65536"
            OLLAMA_FLASH_ATTENTION: "1"
            OLLAMA_KV_CACHE_TYPE: q8_0
            OLLAMA_NUM_PARALLEL: "1"
          volumes:
            - ./data/ollama-cpu:/root/.ollama

      networks:
        default:
          name: ollama-ai-internal
          driver: bridge
          driver_opts:
            com.docker.network.bridge.name: ai-gateway0
    '';

    "Dev/Ollama/litellm-config.yaml".text = litellmModels;

    # The model has the MTP head; this alias selects the best measured draft
    # depth for it. It is mutable Ollama state and must be created after the
    # ROCm container and source model exist.
    "Dev/Ollama/Modelfile.qwen38-mtp2".text = ''
      FROM Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp:latest
      PARAMETER draft_num_predict 2
    '';

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
      gateway LiteLLM pod
      `${if autoAiRouterEnabled then "http://ADRES-LAN:4000/v1" else "http://127.0.0.1:4000/v1"}`.
      Aktualny adres komputera pokaże `hostname -I`.

      Te porty są otwarte dla całej sieci lokalnej. Ollama i SearXNG nie mają
      uwierzytelniania, więc używaj tylko zaufanej sieci; w Open WebUI utwórz
      konto administratora przed dopuszczeniem innych użytkowników.

      Open WebUI ma już włączone web search przez SearXNG oraz kontekst Ollamy
      64k. Wyszukiwanie jest natywnym narzędziem modelu (Native function
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

      Open WebUI używa aliasów LiteLLM jako głównego katalogu modeli.
      ${if autoAiRouterEnabled then "Na centralnym ROG-u bezpośredni provider Ollamy jest wyłączony, aby żaden czat nie omijał AUTO." else "Na tym hoście zachowuje natywną Ollamę jako połączenie awaryjne."}
      SearXNG nadal obsługuje Open WebUI bezpośrednio. Aliasy `off`, `low` i
      `medium` wymuszają `think` w gatewayu; `xhigh` nie wysyła żadnego poziomu,
      aby zachować domyślny `reasoning_effort=xhigh` szablonu Qwen3.8. Nie
      przypinaj do nich Function `Reasoning Effort Selector`, bo poziom określa
      wybrany alias.

      Globalne parametry celowo nie zawierają `max_tokens`. Brak tego opcjonalnego
      pola pozwala każdemu modelowi zakończyć odpowiedź samodzielnie; rzeczywistą
      granicą pozostaje wspólne okno kontekstu 64k, obejmujące prompt, historię,
      wyniki narzędzi i odpowiedź. Limit `1200` dotyczy tylko krótkich zadań
      pomocniczych Open WebUI, a nie normalnych odpowiedzi czatu.

      Open WebUI zapisuje część ustawień administratora w SQLite. Po każdej
      zmianie tej konfiguracji NixOS uruchom wybrany profil, a następnie
      `make apply-webui-defaults`. Polecenie deklaratywnie synchronizuje tylko
      ustawienia stosu (WWW, SearXNG, streaming, kompaktowanie i globalne
      domyślne parametry), pokazuje diff zmienionych kluczy i restartuje sam
      panel. Nie usuwa modeli, kont, rozmów, ręcznych modeli ani endpointów API.

      Limit trzech wyników po maksymalnie 12 000 znaków chroni 64k kontekstu
      przed przepełnieniem stronami WWW. Model musi faktycznie obsługiwać native
      tool calling; dla małych modeli może być ono mniej niezawodne niż dla
      większych modeli na White Monsterze.

      Context Compaction działa automatycznie od około 30k tokenów: starsza
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

      Najmocniejszy profil Qwen3.8 na White Monsterze pomija `think` oraz
      `reasoning_effort`. Każde jawne `think` Ollama mapuje na własny poziom
      reasoning, natomiast brak parametru zachowuje domyślny `xhigh` szablonu.
      Zmiana dotyczy następnej wiadomości; nie zmienia odpowiedzi, które już
      powstały. Gdy plugin nie zapamięta wartości Valve po nowym czacie, nie
      wybieraj go ręcznie przy każdej wiadomości: zostaw filtr jako domyślny i
      ustaw wartość globalną w jego konfiguracji.

      ${if !ollamaFarmEnabled then ''
      ## Lokalny Pi w Agent Managerze

      Pi używa wyłącznie lokalnej Ollamy przez LiteLLM. Domyślnym modelem jest
      `auto`; gdy AUTO nie jest włączony, wybór aliasu pozostaje po stronie
      LiteLLM. Nadpisanie przechowuj poza Git w pliku
      `~/.config/ollama-router/hosts.env`:

      ```bash
      OLLAMA_LOCAL_MODEL=qwen3.5:9b
      ```

      Po zmianie modelu wykonaj `make restart-litellm`, aby odtworzyć gateway
      z nową wartością zmiennej.

      Pi może przez lazy MCP utworzyć lokalnego workera albo, tylko dla naprawdę
      trudnego zadania, workera `codex`. Profile ROG, White Monster i
      `ollama-farm-status` nie są na tym hoście pokazywane w Agent Managerze.

      Przed pierwszym uruchomieniem pobierz model do lokalnego kontenera:

      ```bash
      docker compose --profile rocm exec ollama-rocm ollama pull qwen3.5:9b
      ```

      Pi ma cztery narzędzia bazowe oraz jeden lazy proxy MCP dla SearXNG i
      Agent Managera; dodatkowe serwery nie są ładowane do kontekstu.
      '' else ''
      ## Local workers in Agent Manager

      Profile `rog-polamaniec-off` i `rog-polamaniec-thinking` uruchamiają
      Qwena 3.5 9B. Są bezpośrednimi profilami diagnostycznymi; model obu
      zmieniasz w `OLLAMA_ROG_MODEL`.

      ## Lokalny manager całej farmy modeli

      Agent Manager udostępnia Pi jako jedyny lokalny profil agentowy. `auto`
      jest domyślnym modelem LiteLLM, który kieruje pracę kodową do Qwena 3.8.
      Worker Pi może przez lazy MCP uruchomić kolejnego, krótko żyjącego workera
      Pi lub — wyłącznie dla wyraźnej eskalacji — Codexa. Sonda nadal sprawdza
      dostępność hostów i modeli, ale nie mierzy kolejki generowania.

      Na każdym koncie używającym panelu utwórz prywatny plik
      `~/.config/ollama-router/hosts.env` (nie zapisuj go w Git) z adresami LAN
      i domyślnym modelem każdego hosta:

      ```bash
      OLLAMA_ROG_BASE_URL=http://192.168.1.10:11434
      OLLAMA_ROG_MODEL=qwen3.5:9b
      OLLAMA_ROUTER_MODEL=qwen3.5:4b
      OLLAMA_WHITE_MONSTER_BASE_URL=http://192.168.1.20:11434
      OLLAMA_WHITE_MONSTER_MODEL=qwen38-mtp2
      OLLAMA_CODER_BASE_URL=http://192.168.1.20:11434
      OLLAMA_CODER_MODEL=qwen38-mtp2
      ```

      Cele startowe same tworzą brakujący plik i migrują starsze zmienne URL.
      Po ręcznej zmianie inventory wykonaj `make restart-litellm`, aby odtworzyć
      kontener z nowym środowiskiem.

      Na White Monsterze profil `qwen38-mtp2` ustawia `draft_num_predict 2` dla
      dołączonej głowicy MTP — jest to liczba propozycji na krok, nie limit
      długości odpowiedzi. Po aktywacji, uruchomionym profilu ROCm i pobraniu
      modelu źródłowego utwórz go raz poleceniem `make mtp2`.

      Przed pierwszym uruchomieniem routera pobierz jego model na ROG-u:

      ```bash
      make pull MODEL=qwen3.5:4b
      ```

      ${lib.optionalString autoAiRouterEnabled ''
      Pi oraz jego profil w Agent Managerze korzystają z `model=auto`.
      LiteLLM jest jedynym publicznym endpointem modeli pod
      `http://ADRES-ROG:4000/v1`; systemdowy `auto-ai-router` używa portu 4100
      dostępnego wyłącznie z nazwanej sieci Compose. Opis przepływu, health
      checków, curl i przyszłego Codera znajduje się w repozytorium w
      `docs/auto-ai-router.md`.
      ''}

      Qwen 3.5 ma aliasy `off` i `thinking`, a Qwen3.8 `off`, `low`, `medium`
      i `xhigh`, realizowany przez brak jawnego poziomu i domyślny
      `reasoning_effort=xhigh` szablonu Qwen3.8. Na centralnym
      ROG-u Pi uruchamia `auto`. Pi ma lokalny provider LiteLLM dla Chat
      Completions i przekazuje klucz automatycznie. SearXNG oraz Agent Manager
      są dostępne tylko przez lazy proxy MCP, aby nie obciążać sesji Qwena
      zestawem pełnych schemas.

      Każdy wpis modelu musi istnieć na wskazanym hoście. Adresy odczytasz na
      nim przez `hostname -I`; użyj stałych adresów DHCP lub własnego DNS.
      Farmę można uruchamiać etapami: nieskonfigurowany host będzie oznaczony
      jako `unavailable` i manager go nie wybierze, więc początkowo może działać
      wyłącznie ROG.
      Następnie uruchom `agent-manager` i utwórz sesję `auto`.
      Polecenie `ollama-farm-status` pokazuje ręcznie ten sam status, którego
      manager używa przed wyborem workera. Aby pracować po wyczerpaniu limitu,
      poleć managerowi działać wyłącznie lokalnie; po błędzie limitu sam nie
      ponowi Codexa. Kontekst nie jest przenoszony automatycznie pomiędzy CLI.

      Pi zachowuje historię w `~/.pi/agent/sessions/`; zamknięcie samego panelu
      pozostawia działające sesje tmux bez zmian.
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

        # LiteLLM protects /model/info and all inference endpoints with this
        # local key. Generate it once; never print or replace an existing key.
        if ${pkgs.gnugrep}/bin/grep -q '^LITELLM_MASTER_KEY=' "$config_file" \
          && ! ${pkgs.gnugrep}/bin/grep -Eq '^LITELLM_MASTER_KEY=sk-.+' "$config_file"; then
          printf 'LITELLM_MASTER_KEY in %s must be non-empty and start with sk-.\n' \
            "$config_file" >&2
          exit 2
        fi
        ensure_setting LITELLM_MASTER_KEY \
          "''${LITELLM_MASTER_KEY:-sk-$(${pkgs.openssl}/bin/openssl rand -hex 32)}"

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
        ensure_setting OLLAMA_ROUTER_MODEL "''${OLLAMA_ROUTER_MODEL:-qwen3.5:4b}"
        ensure_setting OLLAMA_WHITE_MONSTER_BASE_URL "''${legacy_white%/v1}"
        ensure_setting OLLAMA_WHITE_MONSTER_MODEL "''${OLLAMA_WHITE_MONSTER_MODEL:-qwen38-mtp2}"
        if ${pkgs.gnugrep}/bin/grep -q '^OLLAMA_WHITE_MONSTER_MODEL=qwen38-mtp3$' "$config_file"; then
          ${pkgs.gnused}/bin/sed -i 's/^OLLAMA_WHITE_MONSTER_MODEL=qwen38-mtp3$/OLLAMA_WHITE_MONSTER_MODEL=qwen38-mtp2/' "$config_file"
          OLLAMA_WHITE_MONSTER_MODEL=qwen38-mtp2
        fi
        if ${pkgs.gnugrep}/bin/grep -q \
          '^OLLAMA_WHITE_MONSTER_MODEL=Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp:latest$' \
          "$config_file"; then
          ${pkgs.gnused}/bin/sed -i \
            's/^OLLAMA_WHITE_MONSTER_MODEL=Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp:latest$/OLLAMA_WHITE_MONSTER_MODEL=qwen38-mtp2/' \
            "$config_file"
          OLLAMA_WHITE_MONSTER_MODEL=qwen38-mtp2
        fi
        ensure_setting OLLAMA_CODER_BASE_URL "''${OLLAMA_CODER_BASE_URL:-''${legacy_white%/v1}}"
        ensure_setting OLLAMA_CODER_MODEL "''${OLLAMA_CODER_MODEL:-''${OLLAMA_WHITE_MONSTER_MODEL:-qwen38-mtp2}}"
        if ${pkgs.gnugrep}/bin/grep -q '^OLLAMA_CODER_MODEL=qwen38-mtp3$' "$config_file"; then
          ${pkgs.gnused}/bin/sed -i 's/^OLLAMA_CODER_MODEL=qwen38-mtp3$/OLLAMA_CODER_MODEL=qwen38-mtp2/' "$config_file"
          OLLAMA_CODER_MODEL=qwen38-mtp2
        fi
        if ${pkgs.gnugrep}/bin/grep -q \
          '^OLLAMA_CODER_MODEL=Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp:latest$' \
          "$config_file"; then
          ${pkgs.gnused}/bin/sed -i \
            's/^OLLAMA_CODER_MODEL=Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp:latest$/OLLAMA_CODER_MODEL=qwen38-mtp2/' \
            "$config_file"
          OLLAMA_CODER_MODEL=qwen38-mtp2
        fi
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
      import os
      import sqlite3
      import time
      from pathlib import Path

      database = Path("/app/backend/data/webui.db")
      if not database.is_file():
          raise SystemExit("Open WebUI database does not exist; start the stack first.")

      desired = {
          "chat.context_compaction.enable": True,
          "chat.context_compaction.token_threshold": 48000,
          "chat.context_compaction.token_cap": 52000,
          "chat.context_compaction.retention_percentage": 40,
          "models.default_metadata": {
              "capabilities": {"web_search": True},
              "defaultFeatureIds": ["web_search"],
          },
          # Omitting max_tokens removes the global response cap; inserting a
          # large number would consume the same 64k window used by chat context.
          "models.default_params": {"function_calling": "native", "stream": True},
          "ollama.enable": ${if autoAiRouterEnabled then "False" else "True"},
          "openai.enable": True,
          "openai.api_base_urls": ["http://litellm:4000/v1"],
          "openai.api_keys": [os.environ["LITELLM_MASTER_KEY"]],
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

      .PHONY: help fix-searxng-permissions init-searxng-config init-litellm-env init-stack-config vulkan rocm cpu vulkan-cpu rocm-cpu down apply-webui-defaults pull pull-vulkan pull-rocm pull-cpu pull-searxng pull-litellm restart-litellm restart-searxng mtp2 logs

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

      mtp2: ## ⚡ Utwórz profil Qwen3.8 MTP z dwiema propozycjami na krok (tylko White Monster/ROCm)
      >$(COMPOSE) --profile rocm exec -T ollama-rocm ollama create qwen38-mtp2 -f /dev/stdin < Modelfile.qwen38-mtp2

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
