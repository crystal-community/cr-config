test:
	crystal spec

refresh-docs:
	crystal docs --project-name "Crystal Config" --project-version=3.0.2 --source-refname=master --source-url-pattern="https://github.com/vici37/cr-config/blob/%{refname}/%{path}#L%{line}" --canonical-base-url="https://github.com/tsornson/cr-config/"
