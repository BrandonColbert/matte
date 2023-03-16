# Matte

Matte is scripting language that transpiles into Lua. It features modern syntax along with optional types, improved modules, and an extended standard library. Scripts are created with the ".mt" extension.

Matte's transpiler is written in Lua using the matter API.

Since Lua is both the output target and the source language, both Matte and Matter will run in any environment that supports Lua. This makes matte ideal for use in game modding or native applications with Love2D.

# Matter

Matter is a parser generator written in Lua. Token and rule symbols are used to define how lexing and parsing take place in the produced parser.

Token symbols utilize Lua patterns to find matches in the source code. Rule symbols utilize a branching list of requirements consisting of other symbols. The required symbols may involve quantity specifiers which indicate things such as optionality or repetition count, branch names, and precedence/associativity relations to other rule symbols. Requirements involving recursive symbols are also supported.

# Matterialize