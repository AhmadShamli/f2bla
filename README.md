# f2bla
Analyze fail2ban log and output into readable format

You may copy or download the analyze.sh to your local copy, and make it executable.
and run it by calling the script in terminal.

You also can run this script using cron.
Add below cron to crontab and it will run everyday at 0211. Or change it for how many times you want.

>11 2	* * *	root    /root/analyze.sh


By hostname require logresolve, which can be installed by apt-get install apache2-utils

This script has been created thanks to http://www.the-art-of-web.com/system/fail2ban-log/
