# fast-abbr-highlighting

A Zsh plugin for real-time highlighting of abbreviations defined by [zsh-abbr](https://github.com/olets/zsh-abbr), based on [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting).

## Behavior

Now, abbreviations follow these highlighting rules:

- **Regular Prefixes**

  Prefixes will be highlighted as `precommand`.

- **Regular Abbreviations**

  If it matches the pattern:

  ```
  [precommand] command/function [subcommand [argument]] [single/double-hyphen-option]
  ```

  Each part will be highlighted according to its rule (`argument` use the `default` rule).

  Otherwise, it will be entirely highlighted as `alias`.

  **Note:**
  - `precommand` currently only matches `sudo`.
  - `subcommand` and `argument` should match `[A-Za-z]+`, and have a length less their MAX_LENGTH (both default to 7, configurable).
  - If there are no tokens after `command` or `function`, it will be highlighted as `alias`.

- **Global Abbreviations**

  The global abbreviation will be highlighted as `global-alias`.

## Requirements

1. [zsh-abbr](https://github.com/olets/zsh-abbr)
2. [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting)

## Installation

Like any simple zsh plugin, normally no extra steps are required.

This guide only introduces the steps for manual installation. For installation for any framework or plugin manager, please refer to the respective documentation.

**Note:** Load this plugin **after** both `zsh-abbr` and `fast-syntax-highlighting`.

### Manual (Git Clone)

1. Clone this repository somewhere on your machine. This guide will assume `~/.zsh/fast-abbr-highlighting`:
   ```zsh
   git clone https://github.com/5A6F65/fast-abbr-highlighting ~/.zsh/fast-abbr-highlighting
   ```
2. Add the following to your `.zshrc`:
   ```zsh
   source ~/.zsh/fast-abbr-highlighting/fast-abbr-highlighting.plugin.zsh
   ```
3. Start a new terminal session.

## Configuration

```zsh
# Max subcommand length (default: 7)
FAST_ABBR_HIGHLIGHT[SUBCMD_MAX_LENGTH]=10

# Max argument length (default: 7)
FAST_ABBR_HIGHLIGHT[ARGUMENT_MAX_LENGTH]=12
```

## Contributing

This is only a preliminary solution based on my personal usage. There is plenty of room for further improvement, and I welcome anyone to continue improving my work.

For example, we could support highlighting brackets within abbreviations. The current implementation definitely supports parsing brackets, but I'm not sure what the related highlighting behavior should be because I don't use brackets in abbreviation.

If anyone has good ideas, welcome to improve.
