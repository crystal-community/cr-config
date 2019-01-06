# cr-cfg

A simple Model based config generator and parser. You just define the config you want and
if it doesn't exist, a sample one will be generated based on how you defined it. If it does
exist, it will parse the config options it knows about into local variables of the correct
type.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  cr-cfg:
    git: https://sornson.io/gogs/tsornson/cr-cfg
```

## Usage

A full sample file

```crystal
require "cr-cfg"

class MyConfig
  include CrCfg

  # defaults to config.txt if not specified
  file_name "my_config.txt"

  header "Something that can describe the config file
    May take multiple lines"

  # You may use this macro so passing in -h or --help to the program well exit when the help generated
  # by this config gets printed. Useful to omit if there are multiple argument parsers at work
  # exit_on_help

  option myOption1 : String,
    description: "While optional, it helps to have a description of your option",
    default: "my option" # also optional

  option myOption2 : Int32,
    description: "Some options can be made required, which means they need to be defined in the config.
    Adding a default to an option negates its requiredness.",
    required: true

  option myOption3 : Bool,
    description "Bool options are, well, for booleans",
    flag: "--boolean"

  option myOption4 : String,
    description: "Argument flag can now be supplied. Your param can be defined in a config but overwritten by an argument passed in",
    shortflag: "-s",
    longflag: "--option4"

  option myOption5 : String,
    description: "NEW! You can set properties as environment variables using the uppercase of the name"

  option lastOption : Float64

  footer "In the event you want a footer for your config."
end

c = MyConfig.new
c.load # will attempt to read and parse my_config.txt. If it doesn't exist, it will generate a sample one and exit

c.generate_config
#### RETURNS IO::Memory WITH CONTENT: ####
# Something that can describe the config file
# May take multiple lines

# While optional, it helps to have a description of your option
myOption1 = my option

# Some options can be made required, which means they need to be defined in the config
myOption2 = VALUE

# Bool options are, well, for booleans
myOption3 = VALUE

# NEW! Argument flag can now be supplied. Your param can be defined in a config but overwritten by an argument passed in
myOption4 = VALUE
lastOption = VALUE

# In the event you want a footer for your config.
#### END OUTPUT ####
c.myOption1
c.myOption2
c.lastOption
```

Running your program with the `-h` or `--help` cli arguments will print
```
Something that can describe the config file
May take multiple lines
    --boolean                     Bool options are, well, for booleans
    -s S, --option4 OPTION4       NEW! Argument flag can now be supplied. Your param can be defined in a config but overwritten by an argument passed in
```
When using this project to parse arguments, it leaves the ARGV global variable
intact so multiple arg parsers can be run with it.

## Wish List
- [ ] Fill out config for missing options in event model is updated
- [ ] Support of lists
- [X] support argument parsing
- [X] support environment variables

## Contributors

- Troy A. Sornson - creator, maintainer
