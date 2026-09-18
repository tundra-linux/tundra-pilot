# Tundra zsh configuration.
#
# On Tundra this is /etc/zsh/zshrc.d/tundra.zsh, which Alpine's own /etc/zsh/zshrc sources.
# Nothing replaces or edits the zsh package's own files, which is the property that makes this
# survive a base rebase.
#
# Fedora has no such drop-in directory: its zsh is built with --enable-etcdir=/etc, so
# /etc/zshrc is the only system file and it is RPM-owned. The pilot installs this same file to
# /etc/zshrc.d/tundra.zsh and appends one guarded sourcing loop to /etc/zshrc. That append is
# the single deliberate modification to a package-owned file in this repo and does not exist
# on Tundra.
#
# Written against zsh's own modules. No Starship, no Powerlevel10k, no Oh My Zsh: a prompt is
# not worth a binary dependency or a framework's update surface.

# Interactive shells only. A non-interactive zsh running a script gets none of this.
[[ -o interactive ]] || return

# --- history ---------------------------------------------------------------------------
# Shared across sessions, deduplicated, and written as commands are run rather than at exit,
# so a crashed terminal does not take the day's history with it.
HISTFILE=${HISTFILE:-$HOME/.zsh_history}
HISTSIZE=10000
SAVEHIST=10000
setopt share_history inc_append_history hist_ignore_dups hist_ignore_space
setopt extended_history hist_reduce_blanks

# --- navigation ------------------------------------------------------------------------
setopt auto_cd auto_pushd pushd_ignore_dups
setopt no_beep

# --- completion ------------------------------------------------------------------------
# compinit rebuilds its dump when the fpath changes. -d puts the dump under the user's cache
# rather than beside the histfile, so a read-only home directory fails visibly instead of
# silently recompiling on every prompt.
autoload -Uz compinit
() {
	local dump=${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump
	mkdir -p "${dump:h}"
	compinit -d "$dump"
}

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors ''
zstyle ':completion:*:descriptions' format '%F{cyan}%d%f'

# --- prompt ----------------------------------------------------------------------------
# vcs_info is zsh's own git integration. It runs per prompt, so it is configured to report
# only what is cheap: branch name and whether the tree is dirty. check-for-changes costs a
# status call and is worth it; check-for-staged-changes is not.
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:git:*' unstagedstr '*'
zstyle ':vcs_info:git:*' stagedstr '+'
zstyle ':vcs_info:git:*' formats       ' %F{yellow}%b%f%F{red}%u%c%f'
zstyle ':vcs_info:git:*' actionformats ' %F{yellow}%b%f %F{red}%a%f'

autoload -Uz add-zsh-hook
add-zsh-hook precmd vcs_info

setopt prompt_subst
# user@host, working directory, git state, then the sigil. Red sigil for root, because the
# one thing a prompt must never be ambiguous about is whether this shell can delete the OS.
if [[ $EUID -eq 0 ]]; then
	PROMPT='%F{red}%n@%m%f %F{blue}%~%f${vcs_info_msg_0_} %F{red}#%f '
else
	PROMPT='%F{green}%n@%m%f %F{blue}%~%f${vcs_info_msg_0_} %F{green}>%f '
fi

# --- keys ------------------------------------------------------------------------------
# Emacs bindings, then the handful of keys a terminal does not bind for free. Looked up from
# terminfo rather than hardcoded, because the escape sequences differ per terminal.
bindkey -e
() {
	local -A keys=(
		Home    "${terminfo[khome]}"
		End     "${terminfo[kend]}"
		Delete  "${terminfo[kdch1]}"
		Up      "${terminfo[kcuu1]}"
		Down    "${terminfo[kcud1]}"
	)
	[[ -n ${keys[Home]}   ]] && bindkey "${keys[Home]}"   beginning-of-line
	[[ -n ${keys[End]}    ]] && bindkey "${keys[End]}"    end-of-line
	[[ -n ${keys[Delete]} ]] && bindkey "${keys[Delete]}" delete-char
	# Up and down search history against what is already typed, which is the single biggest
	# ergonomic win over a bare arrow key.
	autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
	zle -N up-line-or-beginning-search
	zle -N down-line-or-beginning-search
	[[ -n ${keys[Up]}   ]] && bindkey "${keys[Up]}"   up-line-or-beginning-search
	[[ -n ${keys[Down]} ]] && bindkey "${keys[Down]}" down-line-or-beginning-search
}

# --- aliases ---------------------------------------------------------------------------
# Colour by default, and a short list of transition aliases absorbing muscle-memory misses
# from Windows. This is a courtesy, not a compatibility layer: keep the list short and never
# shadow a real command.
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -lh'
alias la='ls -lha'

alias cls='clear'
alias ipconfig='ip -color a'
