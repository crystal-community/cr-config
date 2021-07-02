# Crystal Config
Find the full documentation [here](http://troy.sornson.io/cr-config/#examples)

This library aims to provide robust configuration management for long running crystal processes
where a CLI interface isn't enough. It aims to provide these configurations through a strongly
typed class. Goals are:

- [X] Declarative construction of config files (through macro driven classes)
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
- [X] Supports runtime config overrides
- [X] Supports property validators
- [ ] Supports enum values
- [ ] Supports lists of subconfigs
- [ ] Auto generated config files if missing
- [ ] New configurations automatically get added to config file if missing

# Examples

## Defining a configuration class

```crystal
require "cr-config"

class ServerConfig
  include CrConfig

  option domain : String
  option ports : Array(Int32)
  option timeout : Float32

  option client : ClientConfig
  option database : Database
end

class ClientConfig
  include CrConfig

  option host : String
  option port : Int32?
  option auth_token : String
end

class Database
  include CrConfig

  option hostname : String, default: "localhost"
  option port : Int32
  option schema : String, default: "http"
  option username : String?
  option password : String?
end

# ...Configure providers, validators, interceptors here. See examples below...

config = ServerConfig.instance # Will load and create a new instance of the config. Can be called repeatedly and it only loads the first time

config.domain            # => All valid properties of the relevant type
config.ports             # => All valid properties of the relevant type
config.timeout           # => All valid properties of the relevant type
config.database.hostname # => All valid properties of the relevant type
config.database.port     # => All valid properties of the relevant type
config.database.schema   # => All valid properties of the relevant type
config.database.username # => All valid properties of the relevant type
config.database.password # => All valid properties of the relevant type

```

The `option` macro can work with `String`, `Int32`, `Int64`, `Float32`, `Float64`, `Bool`, `UInt32`, `UInt64`, `Array`'s of any
of those, and any other configuration class (but NOT `Array`'s of other configuration classes, though it's on the wishlist).

## Configuration Providers
Configuration providers are, well, providers of configuration. During the creation and loading of a config class,
configuration providers are iterated through to obtain the config values and store them into the config class.
Crystal Config provides a list of some standard ones, but also provides a way for custom providers to be implemented.

```crystal
# Using above example classes

# We use the static method to define a list of providers that we want to provide configuration for us.
# The order of the list matters - this will be the order that the providers get run in, and define the
# order of precedence on which value gets set if it's found from multiple providers.
# Last config provider wins.
ServerConfig.providers do
  [
    CrConfig::SimpleFileProvider("config.json"), # This will read a named config file, supporting json, yaml, and .env file formats
    CrConfig::EnvVarProvider.new,                # Let environment variables set (and override) configuration values
    CrConfig::CommandLineParser.new              # Let the command line start up of the server also provide a way to override config values (useful for devs)
  ]
end

# Custom providers can be defined through a block, the builder that's passed in has a single method of `.set("<name>", val)`
# and is shared across all providers. Calling `set` will return true if a config value was set, or false if the config name
# doesn't exist.
#
# There are no limits to how many custom providers can be defined through the `provider` method, they will all be added
# sequentially to the same list of config providers.
ServerConfig.provider do |builder|
  builder.set("database.hostname", "example.com")
end

# The below call will trigger the above providers to be iterated through to construct the instance of ServerConfig
s = ServerConfig.instance
s.database.hostname # => "example.com"

```

## Configuration Validators
Validators are custom validators that will be run on all configurations during building of the config class. Crystal
Config already validates that values are not-nil (where appropriate) and of the type they need to be, but extra
validation might be needed to ensure bad configuration values don't cause problems.

```crystal
# Using the above example classes

# This example uses a single validator, but multiple can be defined through the `validator` method sequentially,
# and they'll be called in the order they're defined.
ServerConfig.validator do |name, val|
  next if name == "schema"

  if val != "https" && val != "http"
    raise "Unsupported server schema #{val}, expected 'http' or 'https'"
  end
end

ServerConfig.provider do |builder|
  builder.set("schema", "nope")
end

ServerConfig.instance # => ConfigException(name: "schema", type: CustomValidatorError, message: "...")

```

## Runtime Configuration Interceptors
After a configuration class has been built and set, it can be desirable to temporarily override those values
to something else (i.e. temporarily reroute requests to a different hostname).

```crystal
# Using above example classes

use_stable = false
ServerConfig.runtime_interceptor do |name, real_val|
  next unless name == "client.host"

  next "stable.example.com" if use_stable
end

ServerConfig.provider do |builder|
  builder.set("client.host", "example.com")
end

s = ServerConfig.instance

s.client.host # => example.com

use_stable = true
s.client.host # => stable.example.com
```

Ironically, runtime interceptors can't be further configured at runtime, only at config build time.
