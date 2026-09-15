# syntax=docker/dockerfile:1
FROM python:3.11-slim

# Edit this once you've uploaded skin_model.pt as a GitHub Release asset
# (see DOCKER_K8S_GUIDE.md's "AI model in CI-built images" section) -
# it's what lets a from-scratch `git clone` build (GitHub Actions) still
# end up with a working model, even though the file itself is gitignored
# (see skin_backend/.gitignore's comment - it's a large binary, never
# meant to live in git history).
ARG MODEL_URL="https://github.com/hristoskamaja/MyDermaDocAi/releases/download/model-v1/skin_model.pt"

# Keeps Python from writing .pyc files / buffering stdout - the second one
# matters most in containers, otherwise `docker logs` can lag behind or
# batch output oddly since stdout isn't a real terminal.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# libgomp1: torch's CPU wheel needs it for OpenMP threading at runtime and
# python:3.11-slim doesn't include it - without this, importing torch
# fails with "libgomp.so.1: cannot open shared object file" the first
# time a scan is attempted, not at container start (torch is imported
# lazily - see skin_model_service.py), so this is easy to miss until then.
# curl: needed for the model-download step further down.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 curl \
    && rm -rf /var/lib/apt/lists/*

# Installed separately, BEFORE requirements.txt, pinned to the +cpu
# build from PyTorch's own wheel index. The plain PyPI torch/torchvision
# wheels bundle ~2GB of NVIDIA CUDA libraries this container will never
# use (no GPU here) - that's what made the previous build download for
# 19+ minutes and then fail with a hash mismatch on one of those huge
# files. requirements.txt keeps its plain torch/torchvision entries
# (>=2.2,<2.4 / >=0.17,<0.19) unchanged for local, non-Docker dev - pip
# sees a version in that range is already installed here and skips
# reinstalling it, so this CPU build is what actually ends up in the image.
RUN pip install --no-cache-dir \
        torch==2.3.1+cpu torchvision==0.18.1+cpu \
        --extra-index-url https://download.pytorch.org/whl/cpu

# Installed before copying the rest of the source so Docker's layer cache
# only re-runs this when requirements.txt itself changes, not on every
# code edit.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Local builds already have the real skin_model.pt via the COPY above
# (assuming you've trained it - see skin_disease_training.ipynb), so this
# only downloads when it's actually missing - which is exactly the case
# for a fresh `git clone` (the file is gitignored, so GitHub Actions'
# checkout never has it). Local builds stay fast/offline and always use
# your exact local file; CI ends up with a working model too.
RUN if [ -f analyses/services/ai_model/skin_model.pt ]; then \
        echo "Using local skin_model.pt"; \
    else \
        echo "skin_model.pt not found locally, downloading from $MODEL_URL..." \
        && curl -fL "$MODEL_URL" -o analyses/services/ai_model/skin_model.pt; \
    fi

RUN chmod +x entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["./entrypoint.sh"]
