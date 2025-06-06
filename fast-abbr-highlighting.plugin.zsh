## Description:
##   Parse regular abbreviation and return highlight rules.
## Arguments:
##   $1 → buffer - the buffer to parse, normally should be `LBUFFER`
## Returns:
##   $?    - non-zero if failed
##   reply - array of highlight rules
_fah_parse_regular_abbr() {
    # Set some standard options to emulate a clean zsh environment.
    # Reference: https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html#std-options
    emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
    setopt extendedglob warncreateglobal typesetsilent noshortloops

    # Declare some standard variables to prevent leakage into the global scope.
    # Do not localize `reply` to return highlight rules.
    # Localize `Reply` to return some non-class values ​​more readable.
    # Reference: https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html#std-variables
    # Reference: https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html#std-param-naming
    typeset -ga reply
    local MATCH REPLY
    local -i MBEGIN MEND
    local -a match mbegin mend
    local -A Reply

    # @DUPE _fah_parse_regular_abbr, _fah_parse_global_abbr
    # If `fast-abbr-highlighting` is not loaded, return.
    (( ${#FAST_ABBR_HIGHLIGHT[VERSION]} )) || return

    # Assign positional parameter to a descriptive local variable for readability.
    local -r buffer=$1

    # If buffer is nothing, return.
    (( ${#${(z)buffer}} )) || return

    ## Description:
    ##   Unset private functions whose names begin with "_fah_pra_".
    ## Arguments:
    ##   None.
    ## Returns:
    ##   $? - same as previous
    _fah_pra_cleanup() {
        local -ri ret=$?
        unfunction -m "_fah_pra_*"
        return $ret
    }

    ## Description:
    ##   Convert a snippet into a highlight rule.
    ## Arguments:
    ##   $1 → snippet - the snippet to convert
    ##   $2 → type    - the highlight type
    ##   $3 → offset  - the start offset
    ## Returns:
    ##   $?            - non-zero if `Reply` is not an associative array
    ##   Reply[rule]   - the highlight rule
    ##   Reply[offset] - the end offset
    _fah_pra_convert() {
        local -r snippet=$1
        local -r type=$2
        local -i offset=$3

        # If `Reply` is not defined as an associative array, return.
        [[ ${${(t)Reply}[1,11]} == association ]] || return

        Reply=(
            rule "$offset $((offset += ${#snippet})) ${FAST_HIGHLIGHT_STYLES[${FAST_THEME_NAME}$type]}"
            offset "$offset"
        )
        return 0
    }

    ## Description:
    ##   Verify if the buffer is a regular abbreviation with or without prefixes,
    ##   and generate a highlight rule for prefixes if matched.
    ## Arguments:
    ##   $1 → buffer - the buffer to preprocess
    ##   $2 → offset - the start offset
    ## Returns:
    ##   $?            - non-zero if failed to verify or generate
    ##   Reply[rule]   - the highlight rule for matched prefixes
    ##   Reply[offset] - the end offset of matched prefixes
    _fah_pra_preprocess() {
        local buffer=$1
        local -i offset=$2

        local prefix snippet matches
        local -a prefixes
        local -i length threshold index

        # Build a list of scalar and glob prefixes,
        # and set threshold to distinguish between them.
        prefixes=(
            $ABBR_REGULAR_ABBREVIATION_SCALAR_PREFIXES
            $ABBR_REGULAR_ABBREVIATION_GLOB_PREFIXES
        )
        length=${#prefixes}
        threshold=${#ABBR_REGULAR_ABBREVIATION_SCALAR_PREFIXES}

        # Loop until the buffer matches a regular abbreviation.
        index=1
        until ((
            ${+ABBR_REGULAR_SESSION_ABBREVIATIONS[${(qqq)buffer}]}
            || ${+ABBR_REGULAR_USER_ABBREVIATIONS[${(qqq)buffer}]}
        )) {
            prefix=${prefixes[$index]}
            # If the buffer matches a prefix, extract the snippet.
            # The matching method depends on the prefix type.
            if (( index++ <= $threshold )) {
                snippet=${(M)buffer#$prefix}
            } else {
                snippet=${(M)buffer#$~prefix}
            }
            if (( ! ${#snippet} )) {
                # If no snippet found and all prefixes have been tried, fail.
                (( $index > $length )) && return 1
                continue
            }
            # If snippet found, append it to matches,
            # and trim the buffer to the remaining part.
            matches+=$snippet
            buffer=${buffer:${#snippet}}
            index=1
        }
        (( ! ${#matches} )) && return 0

        # If matches found, convert into a highlight rule.
        _fah_pra_convert $matches precommand $offset
    }

    ## Description:
    ##   Process a regular abbreviation and generate highlight rules for each component.
    ## Arguments:
    ##   $1 → buffer - the buffer to process
    ##   $2 → offset - the starting offset in the buffer
    ## Returns:
    ##   $?    - zero
    ##   reply - array of highlight rules
    _fah_pra_process() {
        local  buffer=$1
        local -i offset=$2

        local type
        local -a words
        local -a types
        local -i index

        # Convert to alias as fallback.
        _fah_pra_convert ${buffer:$offset} alias $offset
        reply=($Reply[rule])

        # Split into words for component analysis.
        words=(${(z)${buffer:$offset}})
        index=1

        # Check if the word is a precommand.
        if [[ ${words[$index]} == "sudo" ]] {
            types+=(precommand)
            let index++
        }

        # Check if the word is a command or function.
        # Special, if there is no subsequent word, convert to alias.
        # If it is not the case above, return.
        if (( ! ${#words:$index} )) {
            types+=(alias)
            let index++
        } elif (( ${+functions[${words[$index]}]} )) {
            types+=(function)
            let index++
        } elif (( ${+commands[${words[$index]}]} )) {
            types+=(command)
            let index++
        } else {
            return 0
        }

        # Check if the word is a subcommand with an optional argument.
        [[ ${FAST_ABBR_HIGHLIGHT[SUBCMD_MAX_LENGTH]} =~ '^[1-9][0-9]*$' ]] \
            || FAST_ABBR_HIGHLIGHT[SUBCMD_MAX_LENGTH]=7
        if [[ ${words[$index]} =~ '^[A-Za-z]{1,'${FAST_ABBR_HIGHLIGHT[SUBCMD_MAX_LENGTH]}'}$' ]] {
            types+=(subcommand)
            let index++
            [[ ${FAST_ABBR_HIGHLIGHT[ARGUMENT_MAX_LENGTH]} =~ '^[1-9][0-9]*$' ]] \
                || FAST_ABBR_HIGHLIGHT[ARGUMENT_MAX_LENGTH]=7
            if [[ ${words[$index]} =~ '^[A-Za-z]{1,'${FAST_ABBR_HIGHLIGHT[ARGUMENT_MAX_LENGTH]}'}$' ]] {
                types+=(alias)
                let index++
            }
        }

        # Check if the word is a option.
        if [[ ${words[$index]} =~ '^\-[A-Za-z]+$' ]] {
            types+=(single-hyphen-option)
            let index++
        } elif [[ ${words[$index]} =~ '^\-\-[A-Za-z]+$' ]] {
            types+=(double-hyphen-option)
            let index++
        }

        # If there are subsequent words, return.
        (( ${#words[$index]} )) && return 0

        # Convert each component into a highlight rule.
        reply=()
        index=1
        for type ($types) {
            offset+=${${buffer:$offset}[(i)${(q)words[$index]}]}-1
            _fah_pra_convert ${words[$((index++))]} $type $offset
            reply+=(${Reply[rule]})
            offset=${Reply[offset]}
        }
        return 0
    }

    # Unset private functions when return.
    trap '_fah_pra_cleanup' EXIT

    local -a rules=()
    local -i offset=0

    # See description of `_fah_pra_preprocess`.
    _fah_pra_preprocess $buffer $offset || return
    if (( ${#Reply[rule]} )) {
        rules+=(${Reply[rule]})
        offset=${Reply[offset]}
    }

    # See description of `_fah_pra_process`.
    _fah_pra_process $buffer $offset
    rules+=($reply)
    reply=($rules)
    return 0
}

## Description:
##   Parse global abbreviation and return highlight rule for that part.
## Arguments:
##   $1 → buffer - the buffer to parse, normally should be `LBUFFER`
## Returns:
##   $?    - non-zero if failed
##   reply - array of highlight rule
## Note:
##   Currently, `zsh-abbr` does not support leading and/or trailing whitespace for global abbreviations,
##   and is unsure whether it will should support them.
##   However, `fast-abbr-highlighting` does, so there may be subtle differences in behavior.
##   These differences will be eliminated once the ideal behavior is determined.
##   Detail: https://github.com/olets/zsh-abbr/issues/169 https://github.com/olets/zsh-abbr/pull/171
_fah_parse_global_abbr() {
    # Set some standard options to emulate a clean zsh environment.
    # Reference: https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html#std-options
    emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
    setopt extendedglob warncreateglobal typesetsilent noshortloops

    # Declare some standard variables to prevent leakage into the global scope.
    # Do not localize `reply` to return highlight rule.
    # Reference: https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html#std-variables
    typeset -ga reply
    local MATCH REPLY
    local -i MBEGIN MEND
    local -a match mbegin mend

    # @DUPE _fah_parse_regular_abbr, _fah_parse_global_abbr
    # If `fast-abbr-highlighting` is not loaded, return.
    (( ${#FAST_ABBR_HIGHLIGHT[VERSION]} )) || return

    # Assign positional parameter to a descriptive local variable for readability.
    local -r buffer=$1

    # If buffer is nothing, return.
    (( ${#${(z)buffer}} )) || return

    local snippet
    local -i index
    local -a words

    # Split into words and keep the number of spaces.
    words=("${(@s: :)buffer}")

    # Loop until the snippet matches a global abbreviation.
    snippet=$buffer
    index=1
    until ((
        ${+ABBR_GLOBAL_SESSION_ABBREVIATIONS[${(qqq)snippet}]}
        || ${+ABBR_GLOBAL_USER_ABBREVIATIONS[${(qqq)snippet}]}
    )) {
        (( index++ < ${#words} )) || return
        # Join the words from current index to end together using space.
        snippet=${(j: :)words[$index,-1]}
    }

    # Convert snippet into a highlight rule.
    reply=("$((${#buffer} - ${#snippet})) ${#buffer} ${FAST_HIGHLIGHT_STYLES[${FAST_THEME_NAME}global-alias]}")
    return 0
}

() {
    # Set some standard options to emulate a clean zsh environment.
    # Reference: https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html#std-options
    emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
    setopt extendedglob warncreateglobal typesetsilent noshortloops

    # Declare some standard variables to prevent leakage into the global scope.
    # Reference: https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html#std-variables
    local MATCH REPLY
    local -i MBEGIN MEND
    local -a match reply mbegin mend

    # Check if the `zsh-abbr` and `fast-syntax-highlighting` is loaded.
    (( ${+ABBR_SOURCE_PATH} && ${+FAST_HIGHLIGHT} )) || return 1

    # Initialize version tracking and default settings.
    [[ ${(t)FAST_ABBR_HIGHLIGHT} != association ]] && typeset -gA FAST_ABBR_HIGHLIGHT
    FAST_ABBR_HIGHLIGHT[VERSION]=0.1.0
    : ${FAST_ABBR_HIGHLIGHT[SUBCMD_MAX_LENGTH]:=7}
    : ${FAST_ABBR_HIGHLIGHT[ARGUMENT_MAX_LE121NGTH]:=7}

    # Avoid duplicate wrapping.
    (( ${+functions[_orig_zsh_highlight]} )) && return 0

    # Backup original highlight function
    functions -c _zsh_highlight _orig_zsh_highlight

    # Wrap highlight function to customize abbreviation processing.
    _zsh_highlight() {
        # @DUPE https://github.com/zdharma-continuum/fast-syntax-highlighting/blob/cf318e06a9b7c9f2219d78f41b46fa6e06011fd9/fast-syntax-highlighting.plugin.zsh#L68-L89
        # Do not highlight in some specific cases.
        local -r ret=$?
        if [[ $WIDGET == zle-isearch-update ]] && ! (( ${+ISEARCHMATCH_ACTIVE} )) {
            region_highlight=()
            return $ret
        }
        (( ${#ZSH_HIGHLIGHT_MAXLENGTH} )) && (( ${#BUFFER} > $ZSH_HIGHLIGHT_MAXLENGTH )) && return $ret
        (( $PENDING > 0 )) && return $ret

        # Set some standard options to emulate a clean zsh environment.
        # Reference: https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html#std-options
        emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
        setopt extendedglob warncreateglobal typesetsilent noshortloops

        # Declare some standard variables to prevent leakage into the global scope.
        # Reference: https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html#std-variables
        local MATCH REPLY
        local -i MBEGIN MEND
        local -a match reply mbegin mend

        # Process regular abbreviation if `LBUFFER` changed.
        if [[ $LBUFFER != ${FAST_ABBR_HIGHLIGHT[PRIOR_LBUFFER]} ]] {
            # See description of `_fah_parse_regular_abbr`.
            _fah_parse_regular_abbr $LBUFFER && {
                region_highlight=($reply)
                FAST_ABBR_HIGHLIGHT[PRIOR_LBUFFER]=$LBUFFER
                # If matched, return.
                return 0
            }
            # If not matched, reset `_ZSH_HIGHLIGHT_PRIOR_BUFFER`
            # to ensure the original highlight function will be triggered.
            local _ZSH_HIGHLIGHT_PRIOR_BUFFER
        }

        # Fallback to original highlight function.
        _orig_zsh_highlight "$@"

        # Process global abbreviation after original highlight function.
        if [[ $LBUFFER != ${FAST_ABBR_HIGHLIGHT[PRIOR_LBUFFER]} ]] {
            # See description of `_fah_parse_global_abbr`.
            _fah_parse_global_abbr $LBUFFER && region_highlight+=($reply)
            FAST_ABBR_HIGHLIGHT[PRIOR_LBUFFER]=$LBUFFER
        }
        return 0
    }
    return 0
} "$@"
