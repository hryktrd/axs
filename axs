#!/bin/sh
#
#          A simple 'aws' command 'axs' written in POSIX sh 
#               axs(access) to aws(amazon web services)
# 
# Original author: BRAVEMAN LONGBRIDGE, 2016
# powerd by POSIX原理主義 
########################################################################



########################################################################
# Initialization
########################################################################

# === Initialize shell enviroment ======================================
set -u                                                                 
umask 0022                                                             
unset IFS                                                              
export LC_ALL='C'                                                      
export PATH="$(command -p getconf PATH)${PATH:+:}:${PATH:-}"

# === comfirm existance of required command ============================
# --- 1. (OpenSSL                                                      
if   command -v openssl >/dev/null; then                               
  CMD_OSSL='openssl'                                                   
else                                                                   
  error_exit 1 'OpenSSL command is not found.'                         
fi                                                                     
# --- 2.（wget or curl                                                 
if   command -v curl    >/dev/null; then                               
  CMD_CURL='curl'                                                      
elif command -v wget    >/dev/null; then                               
  CMD_WGET='wget'                                                      
else                                                                   
  error_exit 1 'No HTTP-GET/POST command found.'                       
fi                                                                     

# === Usage printing function ==========================================
print_usage_and_exit() {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} [options] [config_textfile]
	Version : 2017-02-25 00:20:55 JST
	          (POSIX Bourne Shell/POSIX commands)
	USAGE
  exit 1
}


########################################################################
# Basic User Information
########################################################################

# === AWS Access Key ID from Credential File ===========================
AWS_ACCESS_KEYID="$(cat ~/.aws/credentials                             | 
                    grep key_id                                        | 
                    awk 'NR==1{print $3}'                              )"

# === AWS Secret AccessKey from Credential File ========================
AWS_SECRET_ACCESSKEY="$(cat ~/.aws/credentials                         | 
                        grep secret                                    | 
                        awk 'NR==1{print $3}'                          )"

# === AWS default Region from Config File ==============================
AWS_REGION="$(cat ~/.aws/config                                        |
             grep region                                               |
             awk '{print $3}'                                          )"


########################################################################
# Parse Arguments
########################################################################

# === Print the usage when "--help" is put =============================
case "$# ${1:-}" in
  '1 -h'|'1 --help'|'1 --version') print_usage_and_exit;;
esac

# === Select Services with getopts =====================================
# --- 1. Initialize
SERVICE=''
API_PARAMS=''
PAYLOAD='' 
ENDPOINT=''
ACTION=''
# --- 2. get opts
while getopts eslcrit: OPT
do
  case $OPT in
    e)  SERVICE=ec2
        ENDPOINT="${SERVICE}.${AWS_REGION}.amazonaws.com"
        ;;
    i)  SERVICE=iam
        ENDPOINT="${SERVICE}.amazonaws.com"
        ;;
    s)  SERVICE=s3
        ENDPOINT="${SERVICE}-${AWS_REGION}.amazonaws.com"
        ;;
    l)  SERVICE=elb
        ENDPOINT="${SERVICE}.${AWS_REGION}.amazonaws.com"
        ;;
    c)  SERVICE=acm
        ENDPOINT="${SERVICE}.${AWS_REGION}.amazonaws.com"
        ;;
    r)  SERVICE=route53
        ENDPOINT="${SERVICE}.${AWS_REGION}.amazonaws.com"
        ;;
    t)  TYPE="$OPTARG"
        TYPE=$(printf "%s" "$TYPE" | tr '[A-Z]' '[a-z]')
        ;;
    \?) echo error 1>&2
        exit 1
        ;;
   esac
done
shift $((OPTIND - 1))

# === Get the File =====================================================
if [ -n "${1:-}" ]; then                                               
  FILE=$(cat $1)                                                       
else                                                                   
  FILE=$(while read line; do                                           
           echo "$line"                                                
           [ -z "$line" ] && break                                     
         done)                                                         
fi                                                                     


########################################################################
# RESTful API PARAMS
########################################################################

# === Time Stamp =======================================================
TIMESTAMP="$(date '+%Y%m%d%H%M%S' | utconv)"                           #
MESSAGEDATE_A="$(echo $TIMESTAMP                                       |
                 TZ=UTC+0 utconv -r                                    |
                 cut -c 1-8                                            )"
MESSAGEDATE_B="$(echo $TIMESTAMP                                       |
                 TZ=UTC+0 utconv -r                                    |
                 cut -c 9-14                                           )"
MESSAGE_TIME="${MESSAGEDATE_A}T${MESSAGEDATE_B}Z"                      #
TM_HDR="X-Amz-Date: ${MESSAGE_TIME}"                                   #

# === Method & URI & Header from $FILE =================================
#                                                                      #
# --- 1. Method(AWS RESTful API)                                       #
METHOD=$(cat <<___________METHOD                                       |
           $FILE
___________METHOD
         head -n 1                                                     |
         awk '{print $1}'                                              )
#                                                                      #
# --- 2.URI(AWS ROA)                                                   # 
URI=$(cat <<________URI                                                |
        $FILE
________URI
      head -n 1                                                        |
      awk '{print $2}'                                                 )
#                                                                      #
# --- 3.Get Additional Header                                          #
AD_HDR=$(cat <<___________ADDITONALHEADER                              |
           $FILE
___________ADDITONALHEADER
         grep '^H'                                                     |
         sed 's/^ *//'                                                 |
         awk '{print $2, $3}'                                          )

# === Query or XML-or-JSON Payload from $FILE ==========================
case "${TYPE:-}" in                                                    #
#                                                                      #
# --- 1.Query                                                          #
  query)  API_PARAMS=$(cat <<_________________________APIPARAMS        |
                         $FILE
_________________________APIPARAMS
                       grep -v '^H'                                    |
                       tail -n +2                                      |
                       sed 's/^ *//'                                   )
          CT_HDR="Content-Type: application/x-www-form-urlencoded"     #
          ;;                                                           #
#                                                                      #
# --- 2.JSON                                                           #
  json)   PAYLOAD=$(cat <<______________________REQUEST_PAYLOAD        |
                      $FILE
______________________REQUEST_PAYLOAD
                    grep -v '^H'                                       |
                    tail -n +2                                         |
                    sed 's/^ *//'                                      |
                    makrj.sh                                           )
          CT_HDR="Content-Type: application/x-amz-json-1.1"            #
          ;;                                                           #
#                                                                      #
# --- 3.XML                                                            #
  xml)    PAYLOAD=$(cat <<______________________REQUEST_PAYLOAD        |
                      $FILE
______________________REQUEST_PAYLOAD
                    grep -v '^H'                                       |
                    tail -n +2                                         |
                    sed 's/^ *//'                                      |
                    makrx.sh                                           )
          CT_HDR="Content-Type: "                                      #
          ;;                                                           #
#                                                                      #
# --- 4.error1                                                         #
  '')     case "${METHOD:-}" in                                        #
            GET | DELETE) :;                                           #
                          ;;                                           #
            PUT | POST)   echo specify format 1>&2                     #
                          exit 1                                       #
                          ;;                                           #
          esac                                                         #
          ;;                                                           #
#                                                                      #
# --- 5.error2                                                         #
  *)      echo invalid format 1>&2                                     #
          exit 1;                                                      #
          ;;                                                           #
#                                                                      #
# === Finish Format setting ============================================ 
esac                                                                   #

########################################################################
#main
########################################################################
#                                                                      #
# === CANONICAL URI ====================================================
CANONICAL_URI=$(printf "%s" "$URI"                                     | 
                urlencode -r                                           |
                sed 's/%2[F]/\//g'                                     )
#                                                                      #
# === QUERY STRINGS ====================================================
# --- 1.API Parameter Encodeing                                        #
APIP_ENC=$(printf '%s\n' "${API_PARAMS}"                               |
           tr ' ' '='                                                  |
           grep -v '^$'                                                |
           sort                                                        |
           urlencode -r                                                |
           sed 's/%1[Ee]/%0A/g'                                        | 
           sed 's/%3[Dd]/=/'                                           )
# --- 2.query strings                                                  #
QUERY_STRINGS=$(printf '%s' "${APIP_ENC}"                              |
                tr '\n' '&'                                            |
                sed 's/&$//'                                           )
#                                                                      #
# === REQUEST PAYLOAD ==================================================
REQUEST_PAYLOAD_HASH=$(printf "%s" "$PAYLOAD"                          | 
                      "$CMD_OSSL" dgst -sha256 | self 2                )
RH_HDR="x-amz-content-sha256: $REQUEST_PAYLOAD_HASH"                   #
#                                                                      #
# === CANONICAL HEADERS ================================================
# --- 1.Headers List                                                   #
HEADERS=$(cat <<____________HEADERS                                    |
            ${CT_HDR:-}
            ${TM_HDR:-}
            ${RH_HDR:-}
            ${AD_HDR:-}
____________HEADERS
          sed 's/^ *//'                                                )
# --- 2.Canonical Headers List                                         #
CANONICAL_HEADERS=$(cat <<______________________CANONICALHEADERS       |
                      Host:${ENDPOINT:-}
                      ${HEADERS:-}
______________________CANONICALHEADERS
                    sed 's/^ *//'                                      |
                    grep -v '^$'                                       |
                    awk -F: -v 'OFS=:' '{print tolower($1),$2}'        |
                    sed 's/\([^;]\) /\1/'                              |
                    sed 's/   *//'                                     |
                    grep -v '^$'                                       |
                    sort                                               )
#                                                                      #
# === SINGNED HEADERS ==================================================
SIGNED_HEADERS=$(printf "%s" "$CANONICAL_HEADERS"                      |
                 cut -d: -f1                                           |
                 sed 's/.*/&;/'                                        |
                 tr -d '\n'                                            |
                 sed 's/;$//'                                          )
#                                                                      #
# === CANONICAL REQUEST ================================================
CANONICAL_REQUEST=$(cat <<______________________CANONICALREQUEST       |
                      ${METHOD}
                      ${CANONICAL_URI}
                      ${QUERY_STRINGS}
                      ${CANONICAL_HEADERS}

                      ${SIGNED_HEADERS}
                      ${REQUEST_PAYLOAD_HASH}
______________________CANONICALREQUEST
                    sed 's/^ *//'                                      )
#                                                                      #
# === Hash CANONICAL REQUEST ===========================================
CANONICAL_REQUEST_HASH=$(printf %s "$CANONICAL_REQUEST"                |
                         "$CMD_OSSL" dgst -sha256 | self 2             )
#                                                                      #
# === CREDENTIAL SCOPE =================================================
CREDENTIAL_SCOPE=$(printf '%s/%s/%s/aws4_request'                      \
                          "${MESSAGEDATE_A}"                           \
                          "${AWS_REGION}"                              \
                          "${SERVICE}"                                 )
#                                                                      #
# === STRING TO SIGN ===================================================
STRING_TO_SIGN=$(cat <<___________________STRINGTOSIGN                 |
                   AWS4-HMAC-SHA256
                   ${MESSAGE_TIME}
                   ${CREDENTIAL_SCOPE}
                   ${CANONICAL_REQUEST_HASH}
___________________STRINGTOSIGN
                sed 's/^ *//'                                          )
#                                                                      #
# === AWS Version 4 Signature 4Sign Step ===============================
# --- 0.Sign Step 0                                                    #
SIGNSTEP0=$(printf "$MESSAGEDATE_A"                                    | 
            "$CMD_OSSL" sha256                                         \
            -hmac "AWS4${AWS_SECRET_ACCESSKEY}"   -hex                 |
            self 2                                                     )
# --- 1.Sign Step 1                                                    #
SIGNSTEP1=$(printf "$AWS_REGION"                                       | 
            "$CMD_OSSL" sha256                                         \
            -mac HMAC -macopt hexkey:"$SIGNSTEP0" -hex                 | 
            self 2                                                     )
# --- 2.Sign Step 2                                                    #
SIGNSTEP2=$(printf "$SERVICE"                                          | 
            "$CMD_OSSL" sha256                                         \
            -mac HMAC -macopt hexkey:"$SIGNSTEP1" -hex                 | 
            self 2                                                     )
# --- 3.Sign Step 3                                                    #
SIGNSTEP3=$(printf "aws4_request"                                      | 
            "$CMD_OSSL" sha256                                         \
            -mac HMAC -macopt hexkey:"$SIGNSTEP2" -hex                 | 
            self 2                                                     )
# --- 4.Final. Signature                                               #
SIGNATURE=$(printf "%s" "$STRING_TO_SIGN"                              | 
            "$CMD_OSSL" sha256                                         \
            -mac HMAC -macopt hexkey:"$SIGNSTEP3" -hex                 | 
            self 2                                                     )
#                                                                      #
# === REQUEST URL ======================================================
# ---1. Request URl                                                    #
REQUEST_URL="${ENDPOINT}${URI}?${QUERY_STRINGS:-}"                     #
# ---2. Erase Extra Query If It Is                                     #
[ -z "${QUERY_STRINGS}" ] && REQUEST_URL=${REQUEST_URL%'?'}            #
#                                                                      #
# === REQUEST ===========================================================
APIRES=$(printf 'Credential=%s/%s, SignedHeaders=%s, Signature=%s'     \
                "${AWS_ACCESS_KEYID}"                                  \
                "${CREDENTIAL_SCOPE}"                                  \
                "${SIGNED_HEADERS}"                                    \
                "${SIGNATURE}"                                         |
         sed 's/^/Authorization: AWS4-HMAC-SHA256 /'                   |
         grep ^                                                        |
         while read -r OA_HDR; do                                      #
           if   [ -n "${CMD_WGET:-}" ]; then                           #
             HEADERS=$(printf "%s\n" "$HEADERS"                      | #
                       sed 's/.*/--header="&" /'                     | #
                       tr -d '\n'                                    ) #
             REQUEST=$(cat<<-_________________REQUEST                | #
                "$CMD_WGET" -q -O - --method="$METHOD"
                         --header="$OA_HDR"
                         $HEADERS
                         --body-data="$PAYLOAD"
                         "https://${REQUEST_URL}"
_________________REQUEST
                 tr '\n' ' '                                         ) #
             eval $REQUEST                                           | #
             cat                                                       #
           elif [ -n "${CMD_CURL:-}" ]; then                           #
             HEADERS=$(printf "%s\n" "$HEADERS"                      | #
                       sed 's/.*/-H "&" /'                           | #
                       tr -d '\n'                                    ) #
             REQUEST=$(cat<<-_________________REQUEST                | #
		"$CMD_CURL" -s -X "$METHOD"
		         -H "$OA_HDR"
		         $HEADERS
		         -d "$PAYLOAD"
			 "https://${REQUEST_URL}"                      
_________________REQUEST
                 tr '\n' ' '                                         ) #
             eval $REQUEST                                             #
           fi                                                          #
         done                                                          |
         base64                                                        )
#process responce　　　　　　　　　　　　　　　　　　　　　　　　　　  #
printf "%s" "$APIRES"                                                  |
base64  -d                                                             # 
echo;                                                                  #
