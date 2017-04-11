#!/bin/sh
#
#   A simple 'aws' command 'axs' written in POSIX sh
#        axs(access) to aws(amazon web services)
#
# Original Author: BRAVEMAN LONGBRIDGE, 2016
# powered by POSIX原理主義
############################################################



############################################################
# Initialization
############################################################

# === Initialize Shell Environment =========================
set -u
umask 0022
unset IFS
export LC_ALL='C'
export PATH="$(command -p getconf PATH)${PATH:+:}:${PATH:-}"
export PATH="/usr/local/opt/openssl/bin:$PATH"

# === prepare ==============================================
LF=$(printf '\\\012_')
LF=${LF%_}

# === Define the functions =================================
error_exit() {
  ${2+:} false && echo "${0##*/}: $2" 1>&2
  exit $1
}
print_usage_and_exit() {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} [options] [config_textfile]
	Version : 2017-04-10 22:58:30 JST
	          (POSIX Bourne Shell/POSIX commands)
	USAGE
  exit 1
}

# === Comfirm Existance of Required Command ================
# --- 1. (OpenSSL
if   command -v openssl >/dev/null; then
  CMD_OSSL='openssl'
else
  error_exit 1 'OpenSSL command is not found.'
fi
# --- 2. ( wget or curl
if   command -v curl    >/dev/null; then
  CMD_CURL='curl'
  CRHEADERS='--include'
elif command -v wget    >/dev/null; then
  CMD_WGET='wget'
  CRHEADERS='--server-response'
else
  error_exit 1 'No HTTP-GET/POST commamd found.'
fi


############################################################
# Basic User Information
############################################################

# === AWS Access Key ID from Credential File ===============
AWS_ACCESS_KEYID="$(cat ~/.aws/credentials                 |
                    grep key_id                            |
                    awk 'NR==1{print $3}'                  )"

# === AWS Secret AccessKey from Credential File ============
AWS_SECRET_KEY="$(cat ~/.aws/credentials                   |
                  grep secret                              |
                  awk 'NR==1{print $3}'                    )"


############################################################
# Parse Arguments
############################################################

# === Print the usage when "--help" is put =================
case "$# ${1:-}" in
  '1 -h'|'1 --help'|'1 --version') print_usage_and_exit;;
esac

# === Select Services with getopts =========================
# --- 1. Initialize
SERVICE=''
ENDPOINT=''
UPFILE=''
# --- 2. get opts
while getopts f:q OPT
do
  case $OPT in
    f)  UPFILE="$OPTARG"
        ;;
    q)  CRHEADERS=''
        ;;
  esac
done
shift $((OPTIND - 1))

# === Get the File Path ====================================
FILE='-'
case "$#" in
  0) :
     ;;
  1) if [   -f "$1"  ] || 
        [   -c "$1"  ] || 
        [   -p "$1"  ] || 
        [ "_$1" = '_-' ]; then
       FILE=$1
     fi
     ;;
  *) print_usage_and_exit
     ;;
esac


############################################################
# RESTful API PARAMS
############################################################

#                                                          #
# === Time Stamp ===========================================
TIMESTAMP="$(date '+%Y%m%d%H%M%S' | utconv)"               #
MESSAGEDATE_A="$(echo $TIMESTAMP                           |
                 TZ=UTC+0 utconv -r                        |
                 cut -c 1-8                                )"
MESSAGEDATE_B="$(echo $TIMESTAMP                           |
                 TZ=UTC+0 utconv -r                        |
                 cut -c 9-14                               )"
MESSAGE_TIME="${MESSAGEDATE_A}T${MESSAGEDATE_B}Z"          #
TM_HDR="X-Amz-Date: ${MESSAGE_TIME}"                       #
#                                                          #
# === Method and URI =======================================
exec <<-CUTFILE
	$(cat "$FILE")
	CUTFILE
read -r METHOD URI                                         #
#                                                          #
# === Query and Headers ====================================
exec <<-CUTSTDOUT
	$(cat -)
	CUTSTDOUT
QUERYANDHEADERS=$(#--- Query Strings & Head ---------------#
  while read -r LINE; do                                   #
    [ -z "$LINE" ] && break                                #
    echo $LINE                                             |
    awk '                                                # #
    $1 !~ /:/ {printf("%s=%s\n", $1, $2)}                # #
    $1  ~ /:/ {printf("\n%s %s", $1, $2)}                ' #
  done                                                   | {
  while read -r QUERY; do                                  #
    echo $QUERY                                            #
    [ -z "$QUERY" ] && break                               #
  done                                                     |
  grep -v '^$'                                             |
  sort                                                     |
  urlencode -r                                             |
  sed 's/%1[Ee]/%0A/g'                                     |
  sed 's/%3[Dd]/=/g'                                       |
  tr '\n' '&'                                              |
  sed 's/&$/'"$LF"'/'                                      #
  cat -;                                                 } ) 
QUERY_STRINGS=$(cat <<-QUERYSTRINGS                        |
	    $QUERYANDHEADERS
	QUERYSTRINGS
          sed 's/^ *//'                                    |
	  sed -n '/: /!p'                                  )
HEADERS=$(cat <<-HEADERS                                   |
	    $QUERYANDHEADERS
	HEADERS
          sed 's/^ *//'                                    |
          sed -n '/: /p'                                   )
ENDPOINT=$(cat <<-ENDPOINT                                 |
	    $HEADERS
	ENDPOINT
	  sed 's/^ *//'                                    |
          grep '^Host: .*amazonaws\.com$'                  |
	  sed 's/^Host: //'                                )
SERVICE=$(cat <<-SERVICE                                   |
	    $ENDPOINT
	SERVICE
          sed 's/^ *//'                                    |
	  sed 's/\.amazonaws\.com//'                       |
	  sed 's/\(.*\)[-\.][^.]*-[^.]*-[^.]*$/\1/'        |
	  sed 's/.*\.//'                                   )
AWS_REGION=$(cat <<-AREGION                                |
	    $ENDPOINT
	AREGION
	  sed 's/^ *//'                                    |
	  sed 's/\.amazonaws\.com//'                       |
	  sed 's/.*[.-]\([^.]*-[^.]*-[^.]*\)/\1/'          |
          sed 's/^.*\..*$/us-east-1/'                      |
	  sed '/[^.]*-[^.]*-[^.]*/! s/^.*$/us-east-1/'     )
#                                                          #
# === Content-Length and Payload hash Header ===============
TMP_FILE=$(mktemp)
trap "exit 1"       HUP INT PIPE QUIT TERM
trap "rm $TMP_FILE" EXIT
PH_HDR=$(#-------------------------------------------------#
cat ${UPFILE:--} | tee $TMP_FILE                           \
                 | "$CMD_OSSL" dgst -sha256                \
                 | awk 'NF>1{print $2}NF<2{print $0}'      \
                 | sed 's/^/x-amz-content-sha256: /'       )
CL_HDR=$(ls -l   $TMP_FILE                                 \
                 | awk '{print $5}'                        \
                 | sed 's/^/Content-Length: /'             )
#                                                          #
# === Update Headers List ==================================
HEADERS=$(cat <<-HEADERS                                   |
	    ${HEADERS:-}
	    ${TM_HDR:-}
	    ${PH_HDR:-}
	    ${CL_HDR:-}
	HEADERS
          sed 's/^ *//'                                    )


############################################################
# Authorization Header
############################################################
#                                                          #
# === Canonical Headers ====================================
CANONICAL_HEADERS=$(cat <<-CANONICALHEADERS                |
	    ${HEADERS:-}
	CANONICALHEADERS
          sed 's/^ *//'                                    |
          grep -v '^$'                                     |
          awk -F: -v 'OFS=:' '{print tolower($1),$2}'      |
          sed 's/\([^;]\) /\1/'                            |
          sed 's/   *//'                                   |
          grep -v '^$'                                     |
          sort                                             )
#                                                          #
# === Singed Headers =======================================
SIGNED_HEADERS=$(#-----------------------------------------#
printf "%s" "$CANONICAL_HEADERS" | cut -d: -f1             \
                                 | sed 's/.*/&;/'          \
                                 | tr -d '\n'              \
                                 | sed 's/;$//'            )
#                                                          #
# === Canonical Request ====================================
CANONICAL_REQUEST=$(cat <<-CANONICALREQUEST                |
	    ${METHOD}
	    ${URI}
	    ${QUERY_STRINGS}
	    ${CANONICAL_HEADERS}

	    ${SIGNED_HEADERS}
	    ${PH_HDR#*: }
	CANONICALREQUEST
          sed 's/^ *//'                                    )
#                                                          #
# === Hash Canonical Request ===============================
CANONICAL_REQUEST_HASH=$(#---------------------------------#
printf "%s" "$CANONICAL_REQUEST" | "$CMD_OSSL" dgst -sha256\
                                 | awk 'NF>1{print $2}   # #
                                        NF<2{print $0}   ' )
#                                                          #
# === Credential Scope =====================================
CREDENTIAL_SCOPE=$(#---------------------------------------#
printf '%s/%s/%s/aws4_request'                             \
       "${MESSAGEDATE_A}"                                  \
       "${AWS_REGION}"                                     \
       "${SERVICE}"                                        )
#                                                          #
# === String to Sign =======================================
STRING_TO_SIGN=$(cat <<-STRINGTOSIGN                       |
	    AWS4-HMAC-SHA256
	    ${MESSAGE_TIME}
	    ${CREDENTIAL_SCOPE}
	    ${CANONICAL_REQUEST_HASH}
	STRINGTOSIGN
	  sed 's/^ *//'                                    )
#                                                          #
# === AWS Version 4 Signature 4 Sign Step ==================
SIGNSTEP0=$(#--- 1. step 0 --------------------------------#
printf "$MESSAGEDATE_A" | "$CMD_OSSL" sha256 -hmac         \
                          "AWS4${AWS_SECRET_KEY}"     -hex \
                        | awk '{print $2}'                 )
SIGNSTEP1=$(#--- 2. step 1 --------------------------------#
printf "$AWS_REGION"    | "$CMD_OSSL" sha256 -mac HMAC     \
                          -macopt hexkey:"$SIGNSTEP0" -hex \
                        | awk '{print $2}'                 )
SIGNSTEP2=$(#--- 3. step 2 --------------------------------#
printf "$SERVICE"       | "$CMD_OSSL" sha256 -mac HMAC     \
                          -macopt hexkey:"$SIGNSTEP1" -hex \
                        | awk '{print $2}'                 )
SIGNSTEP3=$(#--- 4. step 3 --------------------------------#
printf "aws4_request"   | "$CMD_OSSL" sha256 -mac HMAC     \
                          -macopt hexkey:"$SIGNSTEP2" -hex \
                        | awk '{print $2}'                 )
SIGNATURE=$(#--- 5. step 4 --------------------------------#
printf "$STRING_TO_SIGN"| "$CMD_OSSL" sha256 -mac HMAC     \
                          -macopt hexkey:"$SIGNSTEP3" -hex \
                        | awk '{print $2}'                 )
#                                                          #
# === Request URL ==========================================
REQUEST_URL="${ENDPOINT}${URI}?${QUERY_STRINGS:-}"
[ -z "${QUERY_STRINGS}" ] && REQUEST_URL=${REQUEST_URL%'?'}


############################################################
# Main
############################################################
#                                                          #
# === Making Request =======================================
printf 'Credential=%s/%s, SignedHeaders=%s, Signature=%s'  \
       "${AWS_ACCESS_KEYID}"                               \
       "${CREDENTIAL_SCOPE}"                               \
       "${SIGNED_HEADERS}"                                 \
       "${SIGNATURE}"                                      |
sed 's/^/Authorization: AWS4-HMAC-SHA256 /'                |
grep ^                                                     |
while read -r OA_HDR; do                                   #
  if   [ -n "${CMD_WGET:-}" ]; then                        #
    HEADERS=$(# --- add option string ---------------------#
    printf "%s\n" "$HEADERS" | sed 's/.*/--header="&" /'   \
                             | tr -d '\n'                  )
    REQUEST=$(cat <<-REQUEST                               |
	    "$CMD_WGET" -q -O - --method="$METHOD"
	                ${CRHEADERS:-}
	                --header="$OA_HDR"
	                          $HEADERS
	                --body-file="$TMP_FILE"
	                "https://${REQUEST_URL}" 2>&1
	REQUEST
	  sed 's/^ *//'                                    |
	  tr '\n' ' '                                      )
    eval $REQUEST                                        | #
    cat                                                    #
  elif [ -n "${CMD_CURL:-}" ]; then                        #
    HEADERS=$(# --- add option strings --------------------#
    printf "%s\n" "$HEADERS" | sed 's/.*/-H "&" /'         \
                             | tr -d '\n'                  )
    REQUEST=$(cat <<-REQUEST                               |
	    "$CMD_CURL" -s -X "$METHOD"
	                ${CRHEADERS:-}
	                -H "$OA_HDR"
	                    $HEADERS
	                --data-binary @$TMP_FILE
	                "https://${REQUEST_URL}"
	REQUEST
	  sed 's/^ *//'                                    |
	  tr '\n' ' '                                      )
    eval $REQUEST                                          #
  fi                                                       #
done                                                       #
echo                                                       #
