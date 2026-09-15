# syntax=docker/dockerfile:1
FROM python:3.11-slim

ARG MODEL_URL="https://github.com/hristoskamaja/MyDermaDocAi/releases/download/model-v1/skin_model.pt"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
        torch==2.3.1+cpu torchvision==0.18.1+cpu \
        --extra-index-url https://download.pytorch.org/whl/cpu

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN if [ -f analyses/services/ai_model/skin_model.pt ]; then \
        echo "Using local skin_model.pt"; \
    else \
        echo "skin_model.pt not found locally, downloading from $MODEL_URL..." \
        && mkdir -p analyses/services/ai_model \
        && curl -fL "$MODEL_URL" -o analyses/services/ai_model/skin_model.pt; \
    fi

RUN chmod +x entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["./entrypoint.sh"]
