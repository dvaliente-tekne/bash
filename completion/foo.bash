# bash completion for `foo`
_foo()
{
  local cur prev
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  case "$prev" in
    -n)
      COMPREPLY=( $(compgen -W "world David Nahomi" -- "$cur") )
      return 0
      ;;
  esac
  COMPREPLY=( $(compgen -W "-n --dry-run --help --version" -- "$cur") )
}
complete -F _foo foo
