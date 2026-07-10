.PHONY: help install test scan backtest universe docker-build docker-up docker-logs clean

help:
	@echo "Targets:"
	@echo "  install       create venv and install requirements"
	@echo "  test          run the pytest suite"
	@echo "  scan          run the scanner (mode from config.yaml)"
	@echo "  backtest      run the historical backtest + report"
	@echo "  universe      print the symbols that would be scanned"
	@echo "  docker-build  build the docker image"
	@echo "  docker-up     run via docker compose (detached)"
	@echo "  docker-logs   tail container logs"

install:
	python3 -m venv .venv
	.venv/bin/pip install -r requirements.txt
	@echo "Now: cp config.example.yaml config.yaml && cp .env.example .env"

test:
	.venv/bin/pytest -q

scan:
	.venv/bin/python main.py scan

backtest:
	.venv/bin/python main.py backtest

optimize:
	.venv/bin/python main.py optimize

universe:
	.venv/bin/python main.py universe

docker-build:
	docker compose build

docker-up:
	docker compose up -d

docker-logs:
	docker compose logs -f

clean:
	rm -rf .venv .pytest_cache **/__pycache__ logs/*.log
