PYTHON_FILES=src/report/process_report.py src/posts/process_posts.py
PYLINT_RCFILE=.pylint

lint:
	pylint --rcfile $(PYLINT_RCFILE) $(PYTHON_FILES)

validate:
	@cd terraform; terraform validate

plan:
	@cd terraform; terraform plan

apply:
	@cd terraform; terraform apply
