PYTHON ?= python3
VENV ?= .venv

.PHONY: install install-dev run tests lint clean

install:
	$(PYTHON) -m venv $(VENV)
	. $(VENV)/bin/activate && pip install -r requirements.txt

run:
	. $(VENV)/bin/activate && uvicorn app:app --reload

tests:
	. $(VENV)/bin/activate && pytest

clean:
	rm -rf $(VENV)

