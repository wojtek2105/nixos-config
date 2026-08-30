# SDXL mask-only outpaint — RX 9070 XT

Generuje wyłącznie lewą połowę płótna 32:9; prawa połowa pozostaje poza maską i
nie jest objęta edycją. Domyślne `2560×720` jest bezpiecznym etapem przed upscale'em do
`5120×1440`; `SDXL_OUTPAINT_STEPS=36` faworyzuje jakość ponad szybkość.
Domyślny `SDXL_OUTPAINT_OVERLAP=512` daje modelowi szeroki pas na płynne
połączenie korzeni, mgły i światła z prawym rdzeniem.

Po przygotowaniu środowiska ROCm z Diffusers uruchom w kontenerze AMD ROCm:

```bash
PYTHONPATH=/runtime/python python3 tools/wallpapers/sdxl-outpaint/outpaint.py \
  home/wojtek/wallpapers/new-upscaled/02-frieren.png \
  home/wojtek/wallpapers/work/regenerate-2026-08-27/candidates/02-forest-sdxl.png \
  home/wojtek/wallpapers/prompts/regenerate-32x9/02-frieren-forest-camp-characters-locked-v4.4-5.txt
```

Najpierw przygotuj overlay Pythona zawierający `requirements-runtime.txt` oraz
ROCm-enabled PyTorch; nie instaluj koła CUDA z PyPI. Model checkpoint zostanie
pobrany do cache Hugging Face przy pierwszym uruchomieniu.
