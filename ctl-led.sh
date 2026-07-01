#!/bin/bash

com="/usr/bin/shortcuts"

led_on() {
    echo "Detected display waking up at $latest_time"
    echo "${com} run TurnOnLED" | bash
}

led_off() {
    echo "Detected display sleep at $latest_time"
    echo "${com} run TurnOffLED" | bash
}

trap led_off SIGTERM SIGINT

last_time=""
while true; do
    latest_entry=$(pmset -g log | grep "Display is turned" | tail -1)
    latest_time=$(echo "$latest_entry" | awk '{print $1, $2}')

    if [[ "$latest_time" != "$last_time" && "$latest_time" != "" ]]; then
        sw=$(echo ${latest_entry} | grep "turned on")
        if [ "$sw" != "" ]; then
            led_on
        else
            led_off
        fi
        last_time="$latest_time"
    fi

    sleep 5
done
