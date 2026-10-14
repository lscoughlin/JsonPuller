# JsonPuller Dialect

## Purpose

This document describes the grammar that JsonPuller accepts. The baseline
is one JSON text as RFC 8259 defines it. The factory settings add the
forms that RFC 8259 rejects. Those forms are messy JSON.

The README file holds the flag signatures and the initial values. This
document explains each form, the tokens it produces, and the reason for
the initial value.

## The Baseline

A JSON text holds one value. Whitespace can surround that value. The value
is an object, an array, a string, a number, `true`, `false`, or `null`.

Whitespace is a space, a tab, a line feed, or a carriage return. The input
layer reports a line break as one line feed. Whitespace produces no token
and no event.

A string uses double quotes. The scanner decodes these escapes:

| Escape | Character |
|---|---|
| `\"` | Quotation mark |
| `\\` | Reverse solidus |
| `\/` | Solidus |
| `\b` | Backspace |
| `\f` | Form feed |
| `\n` | Line feed |
| `\r` | Carriage return |
| `\t` | Tab |
| `\uXXXX` | One UTF-16 code unit |

A `\u` escape names a UTF-16 code unit. Two escapes that form a surrogate
pair become one Unicode scalar value. An unpaired surrogate raises an error
at the escape. A string value is a sequence of scalar values, and an
unpaired surrogate is not a scalar value.

A character from U+0000 through U+001F inside a string raises an error.
The escaped forms above are the legal way to write those characters.

A number uses this form. The form is the RFC 8259 number.

```text
-? ( 0 | [1-9] [0-9]* ) ( . [0-9]+ )? ( [eE] [+-]? [0-9]+ )?
```

The event text of a number is that spelling. `Parse` maps the spelling to
an FCL number class. The mapping is recorded in `doc/architecture.md`.

The literals `true`, `false`, and `null` are lowercase. The spelling is
part of the grammar. `True` is a different word.

An object is `{`, then member lists, then `}`. A member is a string, a
colon, and a value. A comma separates members. An array is `[`, then
values, then `]`. A comma separates values. The empty object `{}` and the
empty array `[]` are values.

## Why the Initial Values Differ

The settings do not share one initial value. The reason is the effect
on a strict JSON text.

| Setting | Initial value | Effect on a strict text |
|---|---|---|
| `AllowComments` | true | A strict text has no comment, so the text still parses. A comment also parses. |
| `AllowUnquotedKeys` | false | An unquoted key is a different token. The flag stays false so the strict grammar stays in force. |
| `AllowTrailingCommas` | false | A trailing comma is a different member list. The flag stays false so the strict grammar stays in force. |
| `AllowSingleQuotes` | false | A single-quoted string is a second spelling. The flag stays false so the strict string grammar stays in force. |
| `AllowMissingValues` | false, `asNull` false | A consecutive comma is a missing element or member. The setting stays false so the strict comma grammar stays in force. |
| `AllowLeadingZeros` | false | A redundant zero before the integer digits is a second number spelling. The setting stays false so the strict number grammar stays in force. |
| `AllowLeadingDecimalPoint` | false | A number that starts with a decimal point is a second number spelling. The setting stays false so the strict number grammar stays in force. |

A text that RFC 8259 accepts still parses under the initial settings. A
text that is strict except for comments also parses. A text that uses an
unquoted key, a trailing comma, a single-quoted string, a missing value,
a leading zero, or a leading decimal point parses after the caller sets
the matching setting to true.

Comments are the usual addition in a configuration file. The comment flag
therefore starts true. The other settings change the string spelling or the
value grammar, so they start false.

## Comments

`AllowComments(true)` accepts two comment forms. The scanner treats a
comment as layout. A comment produces no token and no event.

| Form | Extent |
|---|---|
| Line comment | From `//` to the next line break. At the end of the text, the comment ends with the text. |
| Block comment | From `/*` to the next `*/`. The comment can contain line breaks. |

The line counter advances inside a block comment. The position of the next
token is the position after the comment.

A comment can stand anywhere whitespace can stand: before the value,
between tokens, and after the value. The characters `//` and `/*` inside a
string are characters of the string. The scanner is inside the string, so
it does not look for a comment there.

A block comment ends at the first `*/`. The pair `/* /* */` ends at the
first closer. The library does not nest block comments. An unclosed block
comment raises an error at the start of the comment. A solidus that is not
the start of `//` or `/*` raises an error at that solidus.

`AllowComments(false)` rejects both comment forms. The error names the line
and the column of the solidus. A strict reader uses this setting. The
initial value is true, so the caller sets the flag to false for that
reader.

A `#` comment is rejected in both flag states. The two accepted forms are
the line comment and the block comment.

## Unquoted Keys

`AllowUnquotedKeys(true)` accepts an object member name written without
quotes. The name is a string in the event stream and in the JSON object.
The flag changes the spelling of that name. The member value keeps its
own type.

The parser is in the name position after `{` or after a comma between
members. In that position the parser accepts these tokens as a `jetName`
event:

| Token | Name text | Example |
|---|---|---|
| String | The decoded string | `"host"` |
| Identifier | The identifier characters | `host` |
| Number | The source spelling | `1` |
| `true`, `false`, or `null` | That spelling | `true` |

An identifier starts with an ASCII letter, `_`, or `$`. It continues with
ASCII letters, digits, `_`, or `$`. Whitespace can separate the identifier
from the colon. The name `host` in `{host: "localhost"}` is the member name
`host`.

A Unicode letter is not an identifier character. A name that needs a
Unicode letter, a hyphen, or a space uses a JSON string. The identifier
rule stays small and testable. `my-key` fails because the hyphen ends the
identifier and the next character is not a colon.

A number in the name position uses the number grammar. The member name is
the spelling. `{1: "one"}` has the member name `1`. The spelling `-1` has
the member name `-1`. When leading zeros are accepted, `{007: "one"}` has
the member name `007`. When they are rejected, that number fails in the
scanner.

In the name position, `true`, `false`, and `null` are names when the flag
is true. `{true: false}` has the member name `true` and the boolean value
false. In the value position the same words stay literals. The position
selects the role. The event type shows the role: `jetName` for the name,
`jetFalse` for the value.

`AllowUnquotedKeys(false)` is the initial value. A quoted string is the
only name. An identifier raises a scanner error, because an identifier is
never a value and the scanner can reject it immediately. A number or a
literal in the name position raises a parser error, because that token is
legal in the value position and the scanner has no name context.

## Trailing Commas

`AllowTrailingCommas(true)` accepts one comma immediately before `}` or
`]`. The comma adds no member and no element. `{ "a": 1, }` is an object
with one member. `[1, 2, ]` is an array with two elements.

The scanner always emits the comma token. The trailing-comma rule is a
parser rule. After a comma, the strict states expect another name or
another value. With the flag set, the object-comma state also accepts `}`,
and the array-comma state also accepts `]`.

A comma that follows no member or no element stays an error in both flag
states:

| Text | Reason |
|---|---|
| `{,}` | The comma is the first token. It follows no member. |
| `[,1]` | The comma is the first token. It follows no element. |

A second comma, as in `[1,,2]`, is a missing value. That form is recorded
in the missing-values section.

`AllowTrailingCommas(false)` is the initial value. A comma immediately
before a closer raises an error at the comma. The text `[1,]` is that
form. The text `[1,,]` is a missing value after `1`, and the missing-values
section records it.

## Single Quotes

`AllowSingleQuotes(true)` accepts a string written with single quotes. A
double-quoted string stays legal in the same text. A member name, a member
value, and an array element can each use either quote style.

The opening quote selects the closer. A string that starts with `'` ends
at the next unescaped `'`. A string that starts with `"` ends at the next
unescaped `"`. The other quote is an ordinary character inside the string.
That is how the two styles mix. `'say "hi"'` is the string `say "hi"`.
`"it's"` is the string `it's`. The text `{"a": 'b', 'c': "d"}` is one
object. The member `a` holds `b`. The member `c` holds `d`.

The decoded text is the event text. A value uses `jetString`. A member
name uses `jetName`. `Parse` builds a `TJSONString`. The quote style is
syntax, so the event type stays the type of the role.

A single-quoted string uses the baseline escape table. It also accepts
`\'`, which decodes to one single quote. A double-quoted string accepts
`\'` as one single quote when this flag is true. Both styles then share
one escape table. `'it\'s'` and `"it\'s"` both decode to `it's`.

A string that reaches the end of the text before its closer raises an
error at the opening quote.

`AllowSingleQuotes(false)` is the initial value. A `'` outside a string
raises an error at that quote. A `'` inside a double-quoted string stays
a character of that string, so `"it's"` still decodes. In this flag state,
`\'` inside a double-quoted string raises an error, because that escape
is outside the baseline table. The flag starts false because a
single-quoted string is a second spelling. A strict text uses double
quotes, so it still parses.

## Missing Values

`AllowMissingValues` takes `value` and `asNull`. The caller passes
`value` on every call. An omitted `asNull` is false. The factory starts
with `value` false and `asNull` false, so a consecutive comma raises an
error at the second comma. `asNull` has an effect only when `value` is
true.

`AllowMissingValues(true)` accepts consecutive commas between array
elements and between object members. Whitespace and comments can stand
between those commas. The scanner removes that layout, so the parser sees
one comma after another.

The first comma is the separator. Each further comma is one missing value.
The missing value takes the place of an element or a member, so a real
element or member can follow it, and the collection can also end.

| Text | What the commas are |
|---|---|
| `[1,,2]` | The element `1`, one missing element, the element `2` |
| `[1,,,2]` | The element `1`, two missing elements, the element `2` |
| `[1,,]` | The element `1`, one missing element, then the end of the array |
| `[1,]` | A trailing comma. This form uses `AllowTrailingCommas`. |
| `{"a": 1,, "b": 2}` | The member `a`, one missing member, the member `b` |
| `{"a": 1,,}` | The member `a`, one missing member, then the end of the object |
| `{"a": 1,}` | A trailing comma. This form uses `AllowTrailingCommas`. |

A comma that follows no element or no member stays an error. `[,1]`,
`[,,]`, and `{,}` start with a comma. The comma is not between items.

`asNull` selects the JSON value of an array hole.

| `asNull` | Array hole | Result of `[1,,2]` |
|---|---|---|
| false | The hole is omitted. The event stream has no event for it. | `[1,2]` |
| true | The hole is null. The event is `jetNull` at the line and column of the extra comma. `Parse` builds a `TJSONNull`. | `[1,null,2]` |

Each extra comma is one hole. `[1,,,2]` with `asNull` true is
`[1,null,null,2]`. The same text with `asNull` false is `[1,2]`.

An object hole has no member name. A JSON member is a name and a value, so
the hole adds no member in either `asNull` state. `{"a": 1,, "b": 2}`
parses as `{"a":1,"b":2}`. The event stream has the name and the value of
`a`, then the name and the value of `b`. `asNull` inserts null for an
array element because an element needs no name.

## Leading Zeros

`AllowLeadingZeros(true)` accepts a number whose integer part starts with
a redundant zero. The baseline integer part is a single `0`, or a digit
from `1` to `9` followed by more digits. This setting also accepts two or
more digits that start with `0`.

| Text | Number |
|---|---|
| `007` | The integer 7 |
| `00` | The integer 0 |
| `-007` | The integer -7 |
| `03.14` | The float 3.14 |
| `007e2` | The float 700 |

The event text is the source spelling. `007` is the event text `007`.
`Parse` uses the numeric value. An integer spelling inside the Int64 range
becomes a `TJSONInt64Number`, so `007` becomes the integer 7. A fraction
or an exponent becomes a `TJSONFloatNumber`. The mapping is the same rule
as a baseline number, recorded in `doc/architecture.md`.

A single `0` is already a baseline number. `0`, `0.5`, and `0e1` parse
with the setting false. The exponent digits already use `[0-9]+`, so
`1e007` is a baseline number. The setting changes the integer part at the
start of the number.

`AllowLeadingZeros(false)` is the initial value. `007` and `01` raise an
error at the first character of the number. The setting starts false
because a redundant zero is a second spelling. A strict text uses the
baseline integer part, so it still parses.

A leading `+` stays an error. A decimal point with no digits stays an
error. `+007` and `007.` are those forms.

## Leading Decimal Point

`AllowLeadingDecimalPoint(true)` accepts a number that starts with a
decimal point. The digits after the point are the fraction. The integer
part is zero. An optional minus can stand before the point. An optional
exponent can follow the fraction.

| Text | Number |
|---|---|
| `.507` | The float 0.507 |
| `.5` | The float 0.5 |
| `-.507` | The float -0.507 |
| `.5e1` | The float 5 |

The event text is the source spelling. `.507` is the event text `.507`.
`Parse` builds a `TJSONFloatNumber`, because the spelling has a fraction.
The value of `.507` is 0.507.

`0.507` is a baseline number. It has an integer part. This setting is the
form with no integer digits before the point. `03.14` has integer digits
and a redundant zero, so it uses `AllowLeadingZeros`. The two settings are
independent.

A dot with no fraction digits stays an error in both states. `.`, `.e1`,
and `1.` have no fraction digits. A leading `+` stays an error, so `+.5`
raises an error.

`AllowLeadingDecimalPoint(false)` is the initial value. `.507` raises an
error at the decimal point. The setting starts false because a missing
integer part is a second spelling. A strict text writes `0.507`, so it
still parses.

When unquoted keys are also accepted, a number in the name position keeps
this spelling. `{.5: "half"}` has the member name `.5`.

## Flag Combinations

Each setting is independent. The factory copies every setting into the
puller together. A text can use every accepted form at once.

```json
{
  // endpoint
  host: "localhost",
  label: 'primary',
  ports: [80, 443,],
}
```

This text parses when unquoted keys, comments, trailing commas, and single
quotes are all accepted. The result is this JSON value:

```json
{"host":"localhost","label":"primary","ports":[80,443]}
```

The comment is absent from the value. The trailing commas are absent from
the value. The unquoted name `host` is the member name `host`. The
single-quoted value `primary` is the member value `primary`.

## Rejected Forms

These settings are the whole dialect. The library rejects the forms in
this table. Each form has a reason that is outside the settings.

| Form | Reason |
|---|---|
| `0x10` | A number follows the RFC 8259 form. Hexadecimal digits are outside that form. |
| `+1` | The number form has an optional minus and no plus. |
| `NaN`, `Infinity` | Those words are not JSON literals. |
| `True`, `False`, `Null` as values | The literal spelling is lowercase. In a value position these words are identifiers, and an identifier is not a value. |
| `# comment` | A comment is a line comment or a block comment. |
| A second value | One text holds one value. |
| An identifier in a value position | A value is an object, an array, a string, a number, or a literal. |

A rejected form raises an error that names the line and the column.
