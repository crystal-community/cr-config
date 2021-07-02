test:
	crystal spec

refresh-docs:
	crystal docs --project-name "Crystal Config" --project-version=1.0.0 --canonical-base-url="https://github.com/tsornson/cr-config/"
