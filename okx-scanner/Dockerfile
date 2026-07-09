FROM python:3.11-slim

# system certs are enough for ccxt/aiohttp; keep the image small
ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY okx_scanner ./okx_scanner
COPY main.py ./

# config.yaml, .env, state/ and logs/ are mounted at runtime (see compose)
ENTRYPOINT ["python", "main.py"]
CMD ["scan"]
