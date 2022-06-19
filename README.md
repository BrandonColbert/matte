# Descent

Descent is a scripting language that transpiles into Lua. It features modern syntax, optional types, improved modules, and an extended standard library. Scripts are created with the ".dt" extension.

Descent's transpiler is written in Lua and uses Descend to build its parser.

By targeting Lua for output and being written in it, both Descent code and Descent's transpiler will run in any environment that supports Lua, such as game modding or native applications with Love2D.

## Descend

Descend is a parser generator written in Lua. Token and rule symbols are used to define how lexing and parsing take place in the produced parser.

Token symbols utilize Lua patterns to find matches in the source code. Rule symbols utilize a branching list of requirements consisting of other symbols. The required symbols may involve quantity specifiers, indicating things such as optionality or repetition count. Recursive requirements are also supported.

## Descend Viewer

Descend Viewer may be used to visualize a syntax tree produced by the Descent transpiler. Visualizations are produced through a local website that displays the syntax tree with color coding.

## Scripts

Various scripts within the `scripts` directory may be run to use the project.

| Script | Description |
| --- | --- |
| run | Prints the output for `examples/test.dt` |
| view | Watch the file at `examples/test.dt` and display at `localhost:25540` |

## Addons

Contains extensions for different editors to help with Descent `.dt` files.