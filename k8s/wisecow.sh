#!/usr/bin/env bash

SRVPORT=4499
RSPFILE=response

rm -f $RSPFILE
mkfifo $RSPFILE

get_api() {
    read line
    echo $line
}

handleRequest() {
    # Process the request
    get_api
    mod=$(fortune)

    cat <<EOF > $RSPFILE
HTTP/1.1 200

<pre>$(cowsay "$mod")</pre>
EOF
}

prerequisites() {
    # Check if fortune and cowsay exist
    command -v fortune >/dev/null 2>&1 &&
    command -v cowsay >/dev/null 2>&1 || 
        { 
            echo "Install prerequisites."
            exit 1
        }
}

main() {
    prerequisites
    echo "Wisdom served on port=$SRVPORT..."

    while true; do
        # Ubuntu netcat-openbsd: use -l -p
        cat $RSPFILE | nc -l -p $SRVPORT | handleRequest
        sleep 0.01
    done
}

main

