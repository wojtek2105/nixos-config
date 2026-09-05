# AUTO AI router

## Przepływ

Pi i Open WebUI wysyłają `model=auto` do LiteLLM na porcie `4000`. LiteLLM
przekazuje alias `auto` do routera na porcie `4100`. Router wybiera model
`router`, `vision`, `reasoning` albo `coder` i odsyła odpowiedź przez LiteLLM.

## Konfiguracja

Plik prywatny:

```text
~/.config/ollama-router/hosts.env
```

Zawiera klucz LiteLLM oraz adresy i tagi modeli. Konfiguracja Compose i aliasy
LiteLLM są generowane z `home/ollama.nix`. Router jest zdefiniowany w
`services/auto-ai-router/` i konfigurowany przez `modules/auto-ai-router.nix`.

## Uruchamianie

```bash
cd ~/Dev/Ollama
make init-litellm-env
make vulkan   # albo rocm/cpu
make status
curl -sS http://127.0.0.1:4100/health
curl -sS http://127.0.0.1:4000/v1/models \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY"
```

Zmiana modelu w `hosts.env` wymaga `make restart-litellm`. Zmiana obrazu lub
profilu Ollamy wymaga odtworzenia stosu Compose.

## Zasady dla krótkiego kontekstu

- Pi ogranicza odpowiedź do 4096 tokenów.
- Ollama ma kontekst 65536 i KV cache `q8_0`; White Monster używa profilu
  Qwen3.8 27B MTP z `draft_num_predict=2`.
- SearXNG zwraca mały, ograniczony wynik; pełne strony pobieraj tylko na żądanie.
- Duże zadania zapisuj w `PLAN.md` i `STATUS.md`.
- Nie wysyłaj całej historii master agenta do workera.

## Diagnostyka

```bash
systemctl --user status auto-ai-router
journalctl --user -u auto-ai-router -n 100 --no-pager
docker compose logs --tail=100 litellm
curl -sS http://127.0.0.1:4100/health
```

Jeśli router nie działa, sprawdź najpierw dostępność wybranych endpointów Ollamy
i poprawność nazw modeli w `hosts.env`.
