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

  # Some properties can be "base" properties (think primitive types, and Arrays of them)
  option domain : String
  option ports : Array(Int32)
  option timeout : Float32
  option use_http : Bool

  # Some properties can be other configuration classes
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

builder = ServerConfig.new_builder

# ...Configure providers, validators, interceptors here. See examples below...

config = builder.build # Will load and create a new instance of the config. Can be called repeatedly and return new instances every time

# There's an optional to use `instance` method now on the class, and can be set with the `set_instance` class method
ServerConfig.set_instance(config)
ServerConfig.instance # => config

# These are all valid calls, and will return the relevant type
config.domain
config.ports
config.timeout
config.use_http?         # Note the '?' due to it being a bool property
config.database.hostname
config.database.port
config.database.schema
config.database.username
config.database.password

# After an instance of the configuration class has been created, you can also use the `.get_config_names` static method
# on the config class to get a set of all config names
ServerConfig.get_config_names # => Set{"domain", "ports", ... , "database.hostname", "database.schema", ...}
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
builder.providers do
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
builder.provider do |bob|
  bob.set("database.hostname", "example.com")
end

# The below call will trigger the above providers to be iterated through to construct the instance of ServerConfig
s = builder.build
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
builder.validator do |name, val|
  next if name == "schema"

  if val != "https" && val != "http"
    raise "Unsupported server schema #{val}, expected 'http' or 'https'"
  end
end

builder.provider do |builder|
  builder.set("schema", "nope")
end

builder.build # => ConfigException(name: "schema", type: CustomValidatorError, message: "...")

```

## Runtime Configuration Interceptors
After a configuration class has been built and set, it can be desirable to temporarily override those values
to something else (i.e. temporarily reroute requests to a different hostname). Runtime interceptors will only
be invoked once per configuration property access, so if an interceptor also uses the config class in its
logic and accesses other config properties, the second time a property is accessed will return what the providers
defined it to be at config build time. This is to protect against infinite loops.

```crystal
# Using above example classes

use_stable = false
builder.runtime_interceptor do |name, real_val|
  next unless name == "client.host"

  # Runtime interceptors are called after the `instance` config gets created, so this access is safe.
  # Trying to use the `instance` before it gets set will throw an exception.
  # This specific call will not invoke this runtime handler again, as the "client.host" will have already
  # recorded it's running runtime interceptors and not re-invoke them a second time.
  ServerConfig.instance.client.host

  next "stable.example.com" if use_stable
end

builder.provider do |builder|
  builder.set("client.host", "example.com")
end

s = builder.build

s.client.host # => example.com

use_stable = true
s.client.host # => stable.example.com
```

Ironically, runtime interceptors can't be further configured at runtime, only at config build time.
