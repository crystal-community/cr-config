# Crystal Config
This library aims to provide robust configuration management for long running crystal processes
where a CLI interface isn't enough. It aims to provide these configurations through a strongly
typed class. Goals are:

- [X] Declarative construction of config files (through macro driven classes)
- [ ] Auto generated config files if missing
- [ ] New configurations automatically get added to config file if missing
- [X] Supports property loading hierarchy
- [X] * Supports loading from file
- [X] ** Supports JSON
- [X] ** Supports YAML
- [X] ** Supports dotenv files
- [X] ** Load different config file based on environment
- [X] * Supports loading from environment variables
- [X] * Supports loading from command line argument overrides (does not conflict with option_parser)
- [X] * hierarchy can be configured
- [X] * can support custom config loaders
- [ ] Supports runtime config overrides
- [ ] Supports property validators
- [ ] Supports lists of subconfigs

