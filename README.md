<div align="center">

# bramble

A command-line todo and notes manager in plain Ruby. Everything lives in one tab-separated text file you can read, grep and keep in git. No gems beyond the standard library.

![License](https://img.shields.io/badge/LICENSE-MIT-blue?style=for-the-badge)  ![Language](https://img.shields.io/badge/RUBY-CC342D?style=for-the-badge&logo=ruby&logoColor=white)  ![Tests](https://img.shields.io/badge/TESTS-81-brightgreen?style=for-the-badge)

Refer to [LICENSE](LICENSE) for the legal bits.

</div>

## What's in it

- **Todos and notes** in the same list. Todos can be finished, notes just sit there.
- **Quick-add words** inside the text itself:
  - `#tag` adds a tag (lowercased, repeats ignored).
  - `@date` sets a due date: `today`, `tomorrow`, `mon` to `sun` (the next one, never today), `+3d`, `+2w`, or `2026-12-01`. Impossible dates such as `2026-02-30` are refused.
  - `!high`, `!normal` or `!low` sets the priority.
  - Anything else is the text. Email addresses and lone `#` or `!` stay as text.
- **Commands**: `add`, `note`, `list` (with `--all`, `--tag`, `--todos`, `--notes`, `--overdue`), `show`, `done`, `undo`, `edit`, `rm`, `search`, `tags`, `stats`, `clear-done`.
- **Sorting** puts overdue todos first, then by due date, then priority, with notes and finished items at the bottom.
- **A plain file store** with an exclusive lock for writers, a shared lock for readers, and writes that go to a temp file and are renamed into place, so a crash can't leave half a file. A corrupt line is reported with its line number instead of being silently dropped.
- Exit codes: 0 for success, 1 when an id doesn't exist, 2 for usage errors or a corrupt file.

```
$ bramble add renew passport '#admin' @+3d '!high'
added todo 1
$ bramble note wifi code is on the fridge
added note 2
```

## 🏗️ Architecture

```
 exe/bramble ──▶ CLI.run(argv)
                  │ parses --file, picks a command, maps errors to exit codes
                  ├─▶ QuickAdd   "buy milk #home @fri !high" ─▶ text, tags, due, priority
                  ├─▶ Store      lock ─▶ read lines ─▶ [Item] ─▶ yield ─▶ temp file ─▶ rename
                  │               └ line: id  kind  priority  created  due  done  tags  text
                  └─▶ Formatter  sort, rows, detail, tag counts, stats
 Item (Struct)   kind, text, tags, priority, due, created, done_on
 errors.rb       UsageError, NotFound, CorruptStore
```

- `CLI` takes its output streams, environment and clock as arguments, which is what makes it testable end to end without touching the real terminal or date.
- `QuickAdd` is a pure function of its input and a "today" date.
- `Store` is the only thing that touches the file. Every change goes through `transaction`, which holds the lock for the read, the change and the write.
- Text is escaped in the file (`\t`, `\n`, `\r` and `\\`), so every item is exactly one line.

## 🚀 Quick start

```
ruby exe/bramble add buy milk '#home'
ruby exe/bramble list
rake test
```

The list goes in `~/.bramble/items.txt` by default. Point it somewhere else with `--file PATH` or the `BRAMBLE_FILE` environment variable.

A short session (the store is a plain file, so this is the whole database):

```
$ bramble list
4 [ ]   2026-11-01 file taxes #admin (overdue)
1 [ ] ! 2026-11-22 renew passport #admin
3 (n)              wifi code is on the fridge

$ cat items.txt
1	t	high	2026-11-19	2026-11-22	-	admin	renew passport
2	t	normal	2026-11-19	-	2026-11-19	home	buy milk
3	n	normal	2026-11-19	-	-	-	wifi code is on the fridge
4	t	normal	2026-11-19	2026-11-01	-	admin	file taxes

$ bramble stats
open:    2
done:    1
overdue: 1
notes:   1
```

I ran the tests in Docker on `ruby:3.3`.

## 🧪 Testing

81 tests (273 assertions), all passing with Minitest and Ruby warnings switched on:

- Item (7): defaults, tag normalisation, validation, done, open and overdue rules, priority ranks.
- QuickAdd (15): tags, priorities, relative, ISO and weekday dates, errors, mixed input, and text that merely looks like markup.
- Store (19): ids, round trips of every field, awkward text with tabs, newlines and backslashes, the exact file format, update and delete, a failed update not writing, comments and blank lines, each kind of corruption with line numbers, directory creation, no leftover temp files.
- Formatter (11): layout and alignment, overdue flags, sort order, detail, tag counts, stats.
- CLI (29): every command end to end against a temporary file with a fixed date, filters, multiple ids, the `--file` option, exit codes and error messages.
