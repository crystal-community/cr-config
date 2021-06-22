# Crystal Config
This library aims to provide robust configuration management for long running crystal processes
where a CLI interface isn't enough. It aims to provide these configurations through a strongly
typed class. Goals are:

- [ ] Declarative construction of config files (through macro driven classes)
- [ ] Auto generated config files if missing
- [ ] New configurations automatically get added to config file if missing
- [ ] Supports property loading hierarchy
- [ ] * Supports loading from file
- [ ] ** Supports JSON
- [ ] ** Supports YAML
- [ ] ** Supports dotenv files
- [ ] ** Load different config file based on environment
- [ ] * Supports loading from environment variables
- [ ] * Supports loading from command line argument overrides (does not conflict with option_parser)
- [ ] * hierarchy can be configured
- [ ] * can support custom config loaders
- [ ] Supports runtime config overrides
- [ ] Supports property validators

