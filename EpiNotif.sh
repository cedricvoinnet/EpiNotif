#!/bin/bash

NAME="EpiNotif"
LOGIN=""
PASS=""
DATE=`date +%d/%m/%Y`
HOME=${HOME}/.EpiNotif
[[ -d "$HOME" ]] || mkdir "$HOME"
ENC_SAVE=$(echo "$HOME/.enc")
DEC_SAVE=$(echo "$HOME/.dec")

usage(){
  echo "Usage:
  $NAME [OPTION] - By default, connect to your Epitech intranet.

  -e, --erase     Erase saved credentials. You will need to retype your
                  credentials at next launch.
  -h, --help      Display this help.
  -t, --today     Connect to your Epitech intranet and display activities for
                  today. Only not past activities will be displayed."
}

verif(){
  error=false
  hash jq 2>/dev/null || { error=true; echo -e >&2 "This script need jq but it's not installed.\n\t\tYou must install jq package first."; }
  hash curl 2>/dev/null || { error=true; echo -e >&2 "This script need curl but it's not installed.\n\t\tYou must install curl package first."; }
  hash notify-send 2>/dev/null || { error=true; echo -e >&2 "This script need notify-send but it's not installed.\n\t\tYou must install notify-osd package first."; }
  [[ $error == true ]] && echo -e "Abort." && exit 1
}

alert(){
  notify-send "$NAME" "$1" -t 2000
}

get_credentials(){
  if [[ ! -f "$ENC_SAVE" ]]; then
    echo -n "Login: "
    read login
    LOGIN=$login
    echo -n "Unix Password: "
    stty -echo
    read pass
    stty echo
    echo ""
    PASS=$pass
    echo "$LOGIN:$PASS" > "$DEC_SAVE"
    openssl aes-256-cbc -a -salt -in $DEC_SAVE -out $ENC_SAVE -pass "pass:`whoami`"
    rm $DEC_SAVE
  else
    openssl aes-256-cbc -d -a -in $ENC_SAVE -out $DEC_SAVE -pass "pass:`whoami`"
    LOGIN=$(cat "$DEC_SAVE" | cut -d ':' -f 1)
    PASS=$(cat "$DEC_SAVE" | cut -d ':' -f 2)
    rm $DEC_SAVE
  fi
}

get_today_activity(){
  get_credentials
  curl_ret=$(curl -d "login=$LOGIN&password=$PASS&remind=false" https://intra.epitech.eu/?format=json 2>/dev/null)
  [[ $? == 6 ]] && { echo -e "No internet connection"; exit 1; }
  curl_ret=$(echo $curl_ret | jq ".board.activites" 2>/dev/null)
  [[ "$curl_ret" == "[]" ]] && { alert "Nothing to show" ; exit 1; }
  ret=$(echo $curl_ret | jq ".[]" 2>/dev/null)
  [[ $ret ]] || { alert "Wrong credentials"; exit 1; }
  ret=$(echo $ret | jq ".title, .timeline_start, .date_inscription")
  ret=$(echo "$ret" | tr "\n" "^")

  IFS='^'
  tab=($ret)
  unset IFS

  TMP=`mktemp`
  i=0
  while [[ $i -lt ${#tab[@]} ]]; do
    title=$(echo ${tab[$i]} | sed 's/\"//g')
    date=$(echo ${tab[$(($i+1))]} | cut -d ',' -f 1 | sed 's/\"//g')
    hour=$(echo ${tab[$(($i+1))]} | cut -d ',' -f 2 | sed 's/[\"\ ]//g')
    register=$(echo ${tab[$(($i+2))]} | sed 's/\"//g')
    if [[ "$date" == "$DATE" ]] && [[ "$register" == false ]]; then
      if [[ "$hour" > `date +%H:%M` ]] || [[ "$hour" == `date +%H:%M` ]];then
        echo "$hour : $title" >> "$TMP"
      fi
    fi
    i=$(($i+3))
  done

  value=$(sort "$TMP" 2>/dev/null)
  if [[ "$value" != "" ]]; then
    alert "$value"
  else
    alert "Nothing to show"
  fi
  rm "$TMP"
}

verif
if [[ $# -gt 1 ]];then
  usage
elif [[ $# -eq 0 ]];then
  get_today_activity
else
  case $1 in
    --today|-t)
      get_today_activity
      ;;
    --help|-h)
      usage
      ;;
    --erase|-e)
      [[ -f $ENC_SAVE ]] && rm $ENC_SAVE
      ;;
    *)
      usage && exit 1
      ;;
  esac
fi
exit 0
