#!/bin/bash
source ./functions/interpreter/vyatta-common

declare -a op_allowed
declare -a toplevel

op_allowed=( $(cat ./etc/shell/level/users/allowed-op.in) )
toplevel=( $(ls ./templates/) )

vyatta_unpriv_gen_allowed () {
  local -a allowed_cmds=()
  rm -f ./etc/shell/level/users/allowed-op
  for cmd in "${op_allowed[@]}"; do
    if is_elem_of ${cmd} toplevel; then
      for pos in $(seq 1 ${#cmd}); do
         case ${cmd:0:$pos} in
            for|do|done|if|fi|case|while|tr )
              continue ;;
            *) ;;
          esac
      if ! is_elem_of ${cmd:0:$pos} allowed_cmds; then
        allowed_cmds+=( ${cmd:0:$pos} )
        echo ${cmd:0:$pos} >> ./etc/shell/level/users/allowed-op
      fi
      done
    else
      echo ${cmd} >> ./etc/shell/level/users/allowed-op
    fi
  done
}

vyatta_unpriv_gen_allowed
