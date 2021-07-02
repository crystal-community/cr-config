test:
	crystal spec

refresh-docs:
	crystal docs --project-name "Crystal Config" --project-version=2.0.0 --source-url-pattern="https://github.com/tsornson/cr-config/"
