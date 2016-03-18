#!/bin/bash

#Fail2Ban Log Analyzer
#This script will read,analyze and output to a file for better readable format
#This script is based from  http://www.the-art-of-web.com/system/fail2ban-log/
#
#
#
#

OUTPUTLOCATION='/var/www/1ma/'
FILENAME='fail2ban.html'
WHOISSERVER='http://whois.ens.my/'
OUTPUTFILE=$OUTPUTLOCATION$FILENAME
LOG=TRUE
DATETODAY=$( date )
DATETODAYDMY=$( date +%d-%m-%Y )

###HEAD###
cat > $OUTPUTFILE <<END
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Fail2Ban Log Analyzer</title>
</head>
<body>
<div id="body">
<div id="title">
<h1>Fail2ban Log Analyzer</h1>
<p>Last Update: $DATETODAY </p>
</div>
END
###/HEAD###

###BODY###
echo "<div id=\"row\"><h2>Banned Count by IP < today $DATETODAYDMY ></h2><table>" >> $OUTPUTFILE
#grep "Ban " /var/log/fail2ban.log | grep `date +%Y-%m-%d` | awk '{print $NF}' | sort | uniq -c | sort -n > TEMPVAR
grep "Ban " /var/log/fail2ban.log | grep `date +%Y-%m-%d` | awk -F[\ \:] '{print $10,$8}' | sort | uniq -c | sort -n > TEMPVAR
I=0
##cat TEMPVAR | while IFS= read -r line
if [ ! -s TEMPVAR ]
then
	echo  "<tr><td>No IP banned for this date.</td></tr>" >> $OUTPUTFILE
else
	cat TEMPVAR | while read line
	do
		if [ $I -eq 0 ]
		then
			echo "<tr>" >> $OUTPUTFILE
		fi
		IP=$( printf '%s\n' "$line" | awk '{print $2}' )
		IPCOUNT=$( printf '%s\n' "$line" | awk '{print $1}' )
		IPTYPE=$( printf '%s\n' "$line" | awk '{print $3}' )
		echo "<td>"$IPCOUNT"&nbsp;<a href=\"$WHOISSERVER$IP\" target=\"_blank\">"$IP"</a>&nbsp;"$IPTYPE"<td>" >> $OUTPUTFILE
		if [ $I -eq 5 ]
		then
			echo  "</tr>" >> $OUTPUTFILE
			I=0
		elif [ $I -lt 5 ]
		then
			I=$(( I + 1 ))
		fi
	done
fi
echo '</table></div>' >> $OUTPUTFILE
echo '<div id="row"><h2>Banned Count Group by Date and section</h2><table>' >> $OUTPUTFILE
zgrep -h "Ban " /var/log/fail2ban.log* | awk '{print $5,$1}' | sort | uniq -c | sort -n > TEMPVAR
I=0
cat TEMPVAR | while IFS= read -r line
do
	if [ $I -eq 0 ]
	then
		echo "<tr>" >> $OUTPUTFILE
	fi
	echo "<td>"$line"</a><td>" >> $OUTPUTFILE
	if [ $I -eq 5 ]
	then
		echo  "</tr>" >> $OUTPUTFILE
		I=0
	elif [ $I -lt 5 ]
	then
		I=$(( I + 1 ))
	fi
done
echo '</table></div>' >> $OUTPUTFILE
echo '<div id="row"><h2>Banned Count by IP</h2><table>' >> $OUTPUTFILE
#zgrep -h "Ban " /var/log/fail2ban.log* | awk '{print $NF}' | sort | uniq -c | sort > TEMPVAR
zgrep -h "Ban " /var/log/fail2ban.log* | awk -F[\ \:] '{print $10,$8}' | sort | uniq -c | sort -n > TEMPVAR
I=0
cat TEMPVAR | while IFS= read -r line
do
	if [ $I -eq 0 ]
	then
		echo "<tr>" >> $OUTPUTFILE
	fi
	IP=$( printf '%s\n' "$line" | awk '{print $2}' )
	IPCOUNT=$( printf '%s\n' "$line" | awk '{print $1}' )
	IPTYPE=$( printf '%s\n' "$line" | awk '{print $3}' )
	echo "<td>"$IPCOUNT"&nbsp;<a href=\"$WHOISSERVER$IP\" target=\"_blank\">"$IP"</a>&nbsp;"$IPTYPE"<td>" >> $OUTPUTFILE
	if [ $I -eq 5 ]
	then
		echo  "</tr>" >> $OUTPUTFILE
		I=0
	elif [ $I -lt 5 ]
	then
		I=$(( I + 1 ))
	fi
done
echo '</table></div>' >> $OUTPUTFILE
echo '<div id="row"><h2>Banned Count by Subnet</h2><table>' >> $OUTPUTFILE
zgrep -h "Ban " /var/log/fail2ban.log* | awk '{print $NF}' | awk -F\. '{print $1"."$2"."}' | sort | uniq -c  | sort -n | tail > TEMPVAR
I=0
cat TEMPVAR | while IFS= read -r line
do
	if [ $I -eq 0 ]
	then
		echo "<tr>" >> $OUTPUTFILE
	fi
	echo "<td>"$line"<td>" >> $OUTPUTFILE
	if [ $I -eq 5 ]
	then
		echo  "</tr>" >> $OUTPUTFILE
		I=0
	elif [ $I -lt 5 ]
	then
		I=$(( I + 1 ))
	fi
done
echo '</table></div>' >> $OUTPUTFILE
echo '<div id="row"><h2>Banned Count with Hostname</h2><table>' >> $OUTPUTFILE
#awk '($(NF-1) = /Ban/){print $NF,"("$NF")"}' /var/log/fail2ban.log | sort | logresolve | uniq -c | sort -n > TEMPVAR
zgrep -h "Ban " /var/log/fail2ban.log* | awk '{print $NF}' | sort | logresolve | sort | uniq -c | sort -n > TEMPVAR
I=0
cat TEMPVAR | while IFS= read -r line
do
	if [ $I -eq 0 ]
	then
		echo "<tr>" >> $OUTPUTFILE
	fi
	echo "<td>"$line"<td>" >> $OUTPUTFILE
	if [ $I -eq 1 ]
	then
		echo  "</tr>" >> $OUTPUTFILE
		I=0
	elif [ $I -lt 1 ]
	then
		I=$(( I + 1 ))
	fi
done
echo '</table></div>' >> $OUTPUTFILE
###/BODY###


###Footer###
cat >> $OUTPUTFILE<<END
</div>
</body>
</html>
END
###/Footer###
