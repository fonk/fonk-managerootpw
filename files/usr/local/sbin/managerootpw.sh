#!/bin/bash

# some defaults
HOME='/var/lib/managerootpw'
PWLENGTH=20
SALTLENGTH=8
RETAIN=5


# initialize variables
export SCRIPT_PID=$$
MODE=""
HOST=""
DEBUG=""

usage() {
  echo "Usage: $0 ( -g [-c]| -s [-l pwlength] [-a saltlength] [-r retain] ) [-b path] [-h hostname] [-d]
    Options:
      Get-Mode:
      -g  set get-mode
      -c  return crypted password, otherwise return plaintext

      Generate-Mode:
      -s  set generate-mode
      -l  length of password to generate
      -a  length of salt to use
      -r  number of passwords and salts to retain

      Options for both modes:
      -h  Host to get or generate password for, if not set, use all hosts
      -b  base working folder
      -d  debug mode
  "
  exit 1;

}

while getopts ":gcsl:a:r:b:h:d" o; do
    case "${o}" in
        s)
            # set mode to "generate", but only if not already set
            [ -z "$MODE" ] || ( echo "You can only set one mode!"; usage )
            MODE="generate"
            ;;
        g)
            # set mode to "get", but only if not already set
            [ -z "$MODE" ] || ( echo "You can only set one mode!"; usage )
            MODE="get"
            ;;
        c)
            CRYPTED="yes"
            ;;
        h)
            HOST=${OPTARG}
            ;;
        l)
            [ "$MODE" = "generate" ] || ( echo "${o} is only valid in generate mode"; usage )
            PWLENGTH=${OPTARG}
            ;;
        a)
            [ "$MODE" = "generate" ] || ( echo "${o} is only valid in generate mode"; usage )
            SALTLENGTH=${OPTARG}
            ;;
        r)
            [ "$MODE" = "generate" ] || ( echo "${o} is only valid in generate mode"; usage )
            RETAIN=${OPTARG}
            ;;
        b)
            HOME=${OPTARG}
            ;;
        d)
            DEBUG="yes"
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# is a mode set?
[ -n "${MODE}" ] || usage



function generate_and_write_pw {

  local FILENAME="$1"; shift
  local PWLEN="$1"; shift
  local SALTLEN="$1"; shift

  # generate password and salt and write it to file on success
  local PW=$(cat /dev/urandom | tr -cd [:graph:] | head -c $PWLEN)
  local SALT=$(cat /dev/urandom | tr -cd [:alnum:] | head -c $SALTLEN)
  if [ -z "$PW" -o -z $SALT ]; then
    echo "Error in password generation for host $HOST! Aborting."
    kill -s TERM $SCRIPT_PID
  else
    echo "${PW}	${SALT}" >> $FILENAME || ( echo "Error: Permission denied on ${FILENAME}! Aborting."; kill -s TERM $SCRIPT_PID )
  fi

  # retain history of last $RETAIN passwords
  tail -n $RETAIN $FILENAME > ${FILENAME}.cut || ( echo "Error: Problem retaining history on ${FILENAME}.cut! Aborting."; kill -s TERM $SCRIPT_PID )
  mv ${FILENAME}.cut $FILENAME || ( echo "Error: Problem retaining history on ${FILENAME}! Aborting."; kill -s TERM $SCRIPT_PID )

  # set restrictive permissions
  chmod 0600 $FILENAME

}

function get_pw {

  local FILENAME="$1"; shift
  local CRYPTED="$1"; shift
  [ -z "$DEBUG" ] || echo "Debug: Getting PW from $FILENAME (Crypted: $CRYPTED)"

  # get the password
  PW=$(tail -n 1 $FILENAME 2> /dev/null | cut -f1 )
  SALT=$(tail -n 1 $FILENAME 2> /dev/null | cut -f2 )
  if [ -z "$PW" -o -z "$SALT" ]; then
    # No Password or Salt found - generate a new one with default parameters
    [ -z "$DEBUG" ] || echo "Debug: No Password found - generating one with default parameters"
    generate_and_write_pw $FILENAME $PWLENGTH $SALTLENGTH
    PW=$(tail -n 1 $FILENAME | cut -f1)
    SALT=$(tail -n 1 $FILENAME | cut -f2)
  fi
  
  if [ -z "$CRYPTED" ]; then
    echo $PW
  else
    echo $PW | mkpasswd -s -S $SALT -m sha-512 || ( echo "Error: Failed to generate Password! Aborting."; kill -s TERM $SCRIPT_PID )
  fi


}

case "${MODE}" in
  generate)
    if [ -z "$HOST" ]; then
      # loop through all hosts
      for HOST in $(ls ${HOME}); do
        generate_and_write_pw "${HOME}/${HOST}" $PWLENGTH $SALTLENGTH
      done
    else
      generate_and_write_pw "${HOME}/${HOST}" $PWLENGTH $SALTLENGTH
    fi
    ;;

  get)
    if [ -z "$HOST" ]; then
      # loop through all hosts
      for HOST in $(ls ${HOME}); do
        echo -n "${HOST}: "
        get_pw "${HOME}/${HOST}" $CRYPTED
      done
    else
      get_pw "${HOME}/${HOST}" $CRYPTED
    fi
  ;;
esac
