#!/bin/bash

# ==========================================
# Koha SIP2 Interactive Tester (Raw Socket)
# ==========================================

# 0. Enforce root privileges for config reading
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[1;31mPlease run as root or with sudo to access koha-list and read SIPconfig.xml\033[0m"
  exit 1
fi

echo -e "\033[1;34mFetching Koha instances...\033[0m"
mapfile -t instances < <(koha-list)

if [ ${#instances[@]} -eq 0 ]; then
    echo "No Koha instances found."
    exit 1
fi

# 1. Instance Selection Menu
echo -e "\n\033[1mSelect a Koha Instance:\033[0m"
select INSTANCE in "${instances[@]}"; do
    if [ -n "$INSTANCE" ]; then
        break
    else
        echo "Invalid selection."
    fi
done

SIP_CONF="/etc/koha/sites/$INSTANCE/SIPconfig.xml"

if [ ! -f "$SIP_CONF" ]; then
    echo -e "\033[1;31mError: $SIP_CONF does not exist.\033[0m"
    exit 1
fi

# 2. Parse SIPconfig.xml 
echo -e "\n\033[1;34mParsing $SIP_CONF...\033[0m"

# Extract the port associated specifically with transport="RAW"
PORT=$(grep -i 'transport="RAW"' "$SIP_CONF" | grep -oP 'port="\K[^"]+' | grep -oP '\d{4,5}' | head -n 1)

# Extract Login Credentials
LOGIN_ID=$(grep -i '<login ' "$SIP_CONF" | grep -oP 'id="\K[^"]+')
PASSWORD=$(grep -i '<login ' "$SIP_CONF" | grep -oP 'password="\K[^"]+')
INSTITUTION=$(grep -i '<login ' "$SIP_CONF" | grep -oP 'institution="\K[^"]+')

if [ -z "$PORT" ]; then
    echo -e "\033[1;31mCould not find a RAW transport port in $SIP_CONF.\033[0m"
    exit 1
fi

echo -e "Target Port: \033[1;33m$PORT\033[0m"
echo -e "Institution: \033[1;33m$INSTITUTION\033[0m | User: \033[1;33m$LOGIN_ID\033[0m"

# ==========================================
# SIP2 Core Functions
# ==========================================

SEQUENCE=0

# Calculates the SIP2 4-character hex 2's complement checksum
calc_checksum() {
    local msg="$1"
    local sum=0
    for (( i=0; i<${#msg}; i++ )); do
        printf -v val "%d" "'${msg:$i:1}"
        sum=$((sum + val))
    done
    local chksum=$(( (-sum) & 0xFFFF ))
    printf "%04X" "$chksum"
}

# Appends sequence, calculates checksum, sends it, and reads response
send_sip() {
    local raw_msg="$1"
    local msg_with_seq="${raw_msg}|AY${SEQUENCE}AZ"
    local chk=$(calc_checksum "$msg_with_seq")
    
    # Strict Carriage Return terminator (No \n)
    local final_msg="${msg_with_seq}${chk}\r"
    
    echo -e "\033[1;36m[->] Sending:\033[0m  ${msg_with_seq}${chk}"
    echo -ne "$final_msg" >&3
    
    # Read response with a 3-second timeout, explicitly stopping at \r
    read -d $'\r' -t 3 -r response <&3
    if [ -z "$response" ]; then
        echo -e "\033[1;31m[!] No response from server (Timeout).\033[0m"
    else
        echo -e "\033[1;32m[<-] Received:\033[0m $response"
    fi
    
    ((SEQUENCE++))
}

# ==========================================
# Execution & Testing Phase
# ==========================================

echo -e "\n\033[1;34mConnecting to 127.0.0.1:$PORT...\033[0m"
# Open bash pseudo-device for TCP connection on file descriptor 3
exec 3<>/dev/tcp/127.0.0.1/$PORT || { echo -e "\033[1;31mConnection failed. Is the worker pool up?\033[0m"; exit 1; }

echo -e "\n--- \033[1mSending Login (93)\033[0m ---"
send_sip "9300CN${LOGIN_ID}|CO${PASSWORD}|CP${INSTITUTION}"

echo -e "\n--- \033[1mSending ACS Status (99)\033[0m ---"
send_sip "9900302.00"

echo -e "\n--- \033[1mPatron Information Request (63)\033[0m ---"
read -p "Enter Patron Cardnumber (or press Enter to skip): " CARDNUMBER

if [ -n "$CARDNUMBER" ]; then
    # Format SIP2 Timestamp: YYYYMMDD    HHMMSS (4 spaces between Date and Time)
    TS=$(date +"%Y%m%d    %H%M%S")
    # Message 63 Summary field requires exactly 10 spaces
    SUMMARY="          "
    
    MSG_63="63000${TS}${SUMMARY}AO${INSTITUTION}|AA${CARDNUMBER}"
    
    echo ""
    send_sip "$MSG_63"
else
    echo "Skipping Patron Info Request."
fi

# Close the socket cleanly
exec 3<&-
exec 3>&-
echo -e "\n\033[1;34mConnection closed.\033[0m"
