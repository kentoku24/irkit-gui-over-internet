#!/bin/sh
#bundle exec unicorn -p 4444 -c ./unicorn.rb -D
echo "ps aux | grep unicorn master"
ps aux | grep "unicorn master"
cd /home/ec2-user/irkit-gui/
bundle exec unicorn -p 80 -c ./unicorn.rb -D
