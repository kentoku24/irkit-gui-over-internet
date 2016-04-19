#!/bin/bash

ps aux | grep "unicorn master" | grep -v "grep" | head -n 1 | awk -F" " '{print $2}' | xargs -i kill {}
