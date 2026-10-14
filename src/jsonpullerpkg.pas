{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Lazarus package entry unit (plan story S15).
@br
The package compiler writes this unit. The unit name differs from JsonPuller
so the package source does not replace the public unit.
}
unit jsonpullerpkg;

{$warn 5023 off : no warning about unused units}
interface

uses
  JsonPuller, JsonPuller.Options, JsonPuller.Errors, JsonPuller.Events,
  JsonPuller.Input, JsonPuller.Scanner.Core, JsonPuller.Scanner.Comment,
  JsonPuller.Scanner.Literal, JsonPuller.Scanner, JsonPuller.Parser,
  JsonPuller.JSON;

implementation

end.
