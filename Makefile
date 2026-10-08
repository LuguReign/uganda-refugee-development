.PHONY: analysis test reports all
analysis:
	python run_analysis.py
test:
	python -m unittest discover -s tests -v
reports:
	python build_outputs.py
all: analysis test reports
