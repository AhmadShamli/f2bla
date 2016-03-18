#!/bin/bash

#Fail2Ban Log Analyzer
#This script will read,analyze and output to a file for better readable format
#This script is based from  http://www.the-art-of-web.com/system/fail2ban-log/
#
#you can run this script automatically by cron
#for everyday at 0211 will execute this script located at inside root(you can change this location)
#==> 11 2	* * *	root    /root/analyze.sh  <==
#

###Config###
OUTPUTLOCATION='/var/www/'
FILENAME='fail2ban.html'
WHOISSERVER='http://whois.ens.my/'
OUTPUTFILE=$OUTPUTLOCATION$FILENAME
LOG=true
DATETODAY=$( date )
DATETODAYDMY=$( date +%d-%m-%Y )
RESOLVEHOST=false

SENDEMAIL=true
FROMEMAIL='vpc@sd1mavpc.com'
TOEMAIL='shamli.sahidi@vads.com'

###/Config###

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
grep "Ban " /var/log/fail2ban.log | grep `date +%Y-%m-%d` | awk -F[\ \:] '{print $10,$8}' | sort | uniq -c | sort -n > TEMPVAR
if [ ! -s TEMPVAR ]
then
	echo  "<tr><td>No IP banned for this date.</td></tr>" >> $OUTPUTFILE
else
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
fi
echo '</table></div>' >> $OUTPUTFILE
echo '<div id="row"><h2>Banned Count Group by Date and section</h2><table>' >> $OUTPUTFILE
zgrep -h "Ban " /var/log/fail2ban.log* | awk '{print $5,$1}' | sort | uniq -c | sort -n > TEMPVAR
if [ ! -s TEMPVAR ]
then
	echo  "<tr><td>No IP banned yet.</td></tr>" >> $OUTPUTFILE
else
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
fi
echo '</table></div>' >> $OUTPUTFILE
echo '<div id="row"><h2>Banned Count by IP</h2><table>' >> $OUTPUTFILE
zgrep -h "Ban " /var/log/fail2ban.log* | awk -F[\ \:] '{print $10,$8}' | sort | uniq -c | sort -n > TEMPVAR
if [ ! -s TEMPVAR ]
then
	echo  "<tr><td>No IP banned yet.</td></tr>" >> $OUTPUTFILE
else
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
fi
echo '</table></div>' >> $OUTPUTFILE
echo '<div id="row"><h2>Banned Count by Subnet</h2><table>' >> $OUTPUTFILE
zgrep -h "Ban " /var/log/fail2ban.log* | awk '{print $NF}' | awk -F\. '{print $1"."$2"."}' | sort | uniq -c  | sort -n | tail > TEMPVAR
if [ ! -s TEMPVAR ]
then
	echo  "<tr><td>No IP banned yet.</td></tr>" >> $OUTPUTFILE
else
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
fi
echo '</table></div>' >> $OUTPUTFILE
if [ "$RESOLVEHOST" = true ]
	then
	echo '<div id="row"><h2>Banned Count with Hostname</h2><table>' >> $OUTPUTFILE
	zgrep -h "Ban " /var/log/fail2ban.log* | awk '{print $NF}' | sort | logresolve | sort | uniq -c | sort -n > TEMPVAR
	if [ ! -s TEMPVAR ]
	then
		echo  "<tr><td>No IP banned yet.</td></tr>" >> $OUTPUTFILE
	else
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
	fi
	echo '</table></div>' >> $OUTPUTFILE
fi
###/BODY###


###Footer###
cat >> $OUTPUTFILE<<END
</div>
</body>
</html>
END
###/Footer###

###Email###
if [ "$SENDEMAIL" = true ]
then
	echo "Sending Email"
	mutt -e 'set content_type="text/html"' -e "send-hook . \"my_hdr From: ${FROMEMAIL} <${FROMEMAIL}>\"" ${TOEMAIL} -s "Fail2Ban Log Analyzed" <  ${OUTPUTFILE}
fi
###/Email###
