PYTHON_FILES=process_report.py
PYLINT_RCFILE=.pylint

lint:
	pylint --rcfile $(PYLINT_RCFILE) $(PYTHON_FILES)
