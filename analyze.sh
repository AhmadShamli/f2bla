#!/bin/bash

#Fail2Ban Log Analyzer
#This script will read,analyze and output to a file for better readable format
#This script is based from  http://www.the-art-of-web.com/system/fail2ban-log/
#
#you can run this script automatically by cron
#for everyday at 0211 will execute this script located at inside root(you can change this location)
#==> 11 2	* * *	root    /root/analyze.sh  <==
#
# https://github.com/AhmadShamli/f2bla/
#

###Config###
LOGFILE='/var/log/fail2ban/fail2ban.log'
OUTPUTLOCATION='/var/www/'

WEBDOMAIN='https://www.example.com/'
FILENAME='fail2ban.html'
SIMPLEFILENAME='fail2ban_short.html'
OUTPUTFILE=$OUTPUTLOCATION$FILENAME
SIMPLEOUTPUTFILE=$OUTPUTLOCATION$SIMPLEFILENAME

WHOISSERVER='http://whois.ens.my/'

DATETODAY=$( date +"%d-%m-%Y %T" )
DATETODAYDMY=$( date +%d-%m-%Y )

COUNTBYIP=true
RESOLVESUBNET=true
RESOLVEHOST=false

SIMPLE=true

SENDEMAIL=true
if [ "$1" = 'noemail' ]
then
	SENDEMAIL=false
fi
FROMEMAIL='vpc@sd1mavpc.com'
TOEMAIL='email@example.com'

###/Config###

###HEAD###
read -d '' PAGEHEAD <<END
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
<p>Update: $DATETODAY </p>
<p>Full Report: <a href='$WEBDOMAIN$FILENAME' >Click HERE</a></p>
</div>
END

echo $PAGEHEAD > $OUTPUTFILE
echo $PAGEHEAD > $SIMPLEOUTPUTFILE
###/HEAD###

###BODY###
echo "Generating : Banned Summary"
BANNEDSUMMARY="<div id=\"row\"><h2>Banned Count Summary</h2><table border='1'>"
BANNEDSUMMARY="$BANNEDSUMMARY <tr><td colspan=1 style='min-width:200px'></td><td align='center' style='min-width:100px'>Count</td></tr>"

BANNED=$( fail2ban-client status ssh | grep 'Total banned' | awk '{print $4}' ) 
BANNEDSUMMARY="$BANNEDSUMMARY <tr><td colspan=1 align='center'>Current<br /><small>Total IP currently Banned</small></td><td align='center'>$BANNED</td></tr>"

TODAY=$( date +%Y-%m-%d )
BANNED=$( grep "Ban " $LOGFILE | grep $TODAY | wc -l ) 
BANNEDSUMMARY="$BANNEDSUMMARY <tr><td colspan=1 align='center'>Today<br /><small>as of $DATETODAY</small></td><td align='center'>$BANNED</td></tr>"

YESTERDAY=$( date -d 'yesterday' +%Y-%m-%d )
BANNED=$( grep "Ban " $LOGFILE | grep $YESTERDAY | wc -l ) 
BANNEDSUMMARY="$BANNEDSUMMARY <tr><td colspan=1 align='center'>Yesterday<br /><small>$YESTERDAY</small></td><td align='center'>$BANNED</td></tr>"

LAST2DAY=$( date --date="2 days ago" +"%Y-%m-%d" )
BANNED=$( grep "Ban " $LOGFILE | grep $LAST2DAY | wc -l ) 
BANNEDSUMMARY="$BANNEDSUMMARY <tr><td colspan=1 align='center'>Last 2 days<br /><small>$LAST2DAY</small></td><td align='center'>$BANNED</td></tr>"

THISMONTH=$( date +%Y-%m )
BANNED=$( zgrep -h "Ban " $LOGFILE* | grep $THISMONTH | wc -l )
BANNEDSUMMARY="$BANNEDSUMMARY <tr><td colspan=1 align='center'>This Month<br /><small>$THISMONTH</small></td><td align='center'>$BANNED</td></tr>"

LASTMONTH=$( date -d 'last month' +%Y-%m )
BANNED=$( zgrep -h "Ban " $LOGFILE* | grep $LASTMONTH | wc -l )
BANNEDSUMMARY="$BANNEDSUMMARY <tr><td colspan=1 align='center'>Last Month<br /><small>$LASTMONTH</small></td><td align='center'>$BANNED</td></tr>"

THISYEAR=$( date +%Y- )
BANNED=$( zgrep -h "Ban " $LOGFILE* | grep $THISYEAR | wc -l )
BANNEDSUMMARY="$BANNEDSUMMARY <tr><td colspan=1 align='center'>This Year<br /><small>$THISYEAR</small></td><td align='center'>$BANNED</td></tr>"

LASTYEAR=$( date -d 'last year' +%Y- )
BANNED=$( zgrep -h "Ban " $LOGFILE* | grep $LASTYEAR | wc -l )
BANNEDSUMMARY="$BANNEDSUMMARY <tr><td colspan=1 align='center'>Last year<br /><small>$LASTYEAR</small></td><td align='center'>$BANNED</td></tr>"

BANNEDSUMMARY="$BANNEDSUMMARY </table></div>"
{
   printf "%s\n" "$BANNEDSUMMARY"
} >>"$OUTPUTFILE" 
{
   printf "%s\n" "$BANNEDSUMMARY"
} >>"$SIMPLEOUTPUTFILE" 
#############

echo "Generating : Todays' Banned IP"
BANNEDTODAY="<div id=\"row\"><h2>Todays' Banned IP <small>< As of today $DATETODAY ></small></h2><table>"
TEMPVAR=$( grep "Ban " $LOGFILE | grep $TODAY | awk -F[\ \:] '{print $10,$8}' | sort | uniq -c | sort -n )
if [ -z TEMPVAR ]
then
	BANNEDTODAY="$BANNEDTODAY <tr><td>No IP banned for this date.</td></tr>"
else
	I=0
	while IFS= read -r line
	do
		if [ $I -eq 0 ]
		then
			BANNEDTODAY="$BANNEDTODAY <tr>"
		fi
		IP=$( printf '%s\n' "$line" | awk '{print $2}' )
		IPCOUNT=$( printf '%s\n' "$line" | awk '{print $1}' )
		IPTYPE=$( printf '%s\n' "$line" | awk '{print $3}' )
		BANNEDTODAY="$BANNEDTODAY <td>$IPCOUNT &nbsp;<a href=\"$WHOISSERVER$IP\" target=\"_blank\">$IP</a>&nbsp;$IPTYPE<td>"
		if [ $I -eq 4 ]
		then
			BANNEDTODAY="$BANNEDTODAY </tr>"
			I=0
		elif [ $I -lt 4 ]
		then
			I=$(( I + 1 ))
		fi
	done < <(echo "$TEMPVAR")
fi
BANNEDTODAY="$BANNEDTODAY </table></div>"
{
   printf "%s\n" "$BANNEDTODAY"
} >>"$OUTPUTFILE" 
{
   printf "%s\n" "$BANNEDTODAY"
} >>"$SIMPLEOUTPUTFILE" 
#############

echo "Generating : Yesterday' Banned IP"
BANNEDYESTERDAY="<div id=\"row\"><h2>Yesterdays' Banned IP <small>< yesterday $YESTERDAY ></small></h2><table>"
TEMPVAR=$( grep "Ban " $LOGFILE | grep $YESTERDAY | awk -F[\ \:] '{print $10,$8}' | sort | uniq -c | sort -n )
if [ -z TEMPVAR ]
then
	BANNEDYESTERDAY="$BANNEDYESTERDAY <tr><td>No IP banned for this date.</td></tr>"
else
	I=0
	while IFS= read -r line
	do
		if [ $I -eq 0 ]
		then
			BANNEDYESTERDAY="$BANNEDYESTERDAY <tr>"
		fi
		IP=$( printf '%s\n' "$line" | awk '{print $2}' )
		IPCOUNT=$( printf '%s\n' "$line" | awk '{print $1}' )
		IPTYPE=$( printf '%s\n' "$line" | awk '{print $3}' )
		BANNEDYESTERDAY="$BANNEDYESTERDAY <td>$IPCOUNT &nbsp;<a href=\"$WHOISSERVER$IP\" target=\"_blank\">$IP</a>&nbsp;$IPTYPE<td>"
		if [ $I -eq 4 ]
		then
			BANNEDYESTERDAY="$BANNEDYESTERDAY </tr>"
			I=0
		elif [ $I -lt 4 ]
		then
			I=$(( I + 1 ))
		fi
	done < <(echo "$TEMPVAR")
fi
BANNEDYESTERDAY="$BANNEDYESTERDAY </table></div>"
{
   printf "%s\n" "$BANNEDYESTERDAY"
} >>"$OUTPUTFILE" 
{
   printf "%s\n" "$BANNEDYESTERDAY"
} >>"$SIMPLEOUTPUTFILE" 
#############

echo "Generating : Top 100 Date"
BANNEDBYDATE='<div id="row"><h2>Top 100 Date <small>with highest banned count</small></h2><table>'
TEMPVAR=$( zgrep -h "Ban " $LOGFILE* | awk '{print $5,$1}' | sort | uniq -c | sort -rn )
if [ -z TEMPVAR ]
then
	BANNEDBYDATE="$BANNEDBYDATE <tr><td>No IP banned yet.</td></tr>"
else
	I=0
	C=0
	while IFS= read -r line
	do
		if [ $I -eq 0 ]
		then
			BANNEDBYDATE="$BANNEDBYDATE <tr>"
		fi
		BANNEDBYDATE="$BANNEDBYDATE <td>"$line"</a><td>"
		if [ $I -eq 4 ]
		then
			BANNEDBYDATE="$BANNEDBYDATE</tr>"
			I=0
		elif [ $I -lt 4 ]
		then
			I=$(( I + 1 ))
		fi
		C=$(( C + 1 ))
		if [ "$C" -ge 100 ]
		then
			break
		fi
	done < <(echo "$TEMPVAR")
fi
BANNEDBYDATE="$BANNEDBYDATE </table></div>"
{
   printf "%s\n" "$BANNEDBYDATE"
} >>"$OUTPUTFILE" 
#############

if [ "$COUNTBYIP" = true ]
	then
		echo "Generating : Top 100 IP"
		BANNEDBYIP='<div id="row"><h2>Top 100 IP <small>with highest banned count</small></h2><table>'
		TEMPVAR=$( zgrep -h "Ban " $LOGFILE* | awk -F[\ \:] '{print $10,$8}' | sort | uniq -c | sort -rn ) 
		if [ -z TEMPVAR ]
		then
			BANNEDBYIP="$BANNEDBYIP <tr><td>No IP banned yet.</td></tr>"
		else
			I=0
			C=0
			while IFS= read -r line
			do
				if [ $I -eq 0 ]
				then
					BANNEDBYIP="$BANNEDBYIP <tr>"
				fi
				IP=$( printf '%s\n' "$line" | awk '{print $2}' )
				IPCOUNT=$( printf '%s\n' "$line" | awk '{print $1}' )
				IPTYPE=$( printf '%s\n' "$line" | awk '{print $3}' )
				BANNEDBYIP="$BANNEDBYIP <td>$IPCOUNT&nbsp;<a href=\"$WHOISSERVER$IP\" target=\"_blank\">$IP</a>&nbsp;$IPTYPE<td>"
				if [ $I -eq 4 ]
				then
					BANNEDBYIP="$BANNEDBYIP </tr>"
					I=0
				elif [ $I -lt 4 ]
				then
					I=$(( I + 1 ))
				fi
				C=$(( C + 1 ))
				if [ "$C" -ge 100 ]
				then
					break
				fi
			done < <(echo "$TEMPVAR")
		fi
		BANNEDBYIP="$BANNEDBYIP </table></div>"
		{
		   printf "%s\n" "$BANNEDBYIP"
		} >>"$OUTPUTFILE" 
fi
#############

if [ "$RESOLVESUBNET" = true ]
	then
		echo "Generating : Top 100 Subnet"
		BANNEDBYSUBNET='<div id="row"><h2>Top 100 Subnet <small>being banned</small></h2><table>'
		TEMPVAR=$( zgrep -h "Ban " $LOGFILE* | awk '{print $NF}' | awk -F\. '{print $1"."$2"."}' | sort | uniq -c  | sort -rn )
		if [ -z TEMPVAR ]
		then
			BANNEDBYSUBNET="$BANNEDBYSUBNET <tr><td>No IP banned yet.</td></tr>"
		else
			I=0
			C=0
			while IFS= read -r line
			do
				if [ $I -eq 0 ]
				then
					BANNEDBYSUBNET="$BANNEDBYSUBNET <tr>"
				fi
				IP=$( printf '%s\n' "$line" | awk '{print $2}' )
				IPCOUNT=$( printf '%s\n' "$line" | awk '{print $1}' )
				BANNEDBYSUBNET="$BANNEDBYSUBNET <td>$IPCOUNT&nbsp;<a href=\"$WHOISSERVER$IP""0.0\" target=\"_blank\">$IP</a><td>"
				if [ $I -eq 4 ]
				then
					BANNEDBYSUBNET="$BANNEDBYSUBNET</tr>"
					I=0
				elif [ $I -lt 4 ]
				then
					I=$(( I + 1 ))
				fi
				C=$(( C + 1 ))
				if [ "$C" -ge 100 ]
				then
					break
				fi
			done < <(echo "$TEMPVAR")
		fi
		BANNEDBYSUBNET="$BANNEDBYSUBNET </table></div>"
		{
		   printf "%s\n" "$BANNEDBYSUBNET"
		} >>"$OUTPUTFILE" 
fi
#############

if [ "$RESOLVEHOST" = true ]
	then
		echo "Generating : Top 100 HostName"
		BANNEDHOSTNAME='<div id="row"><h2>Top 100 HostName</h2><table>'
		TEMPVAR=$( zgrep -h "Ban " $LOGFILE* | awk '{print $NF}' | sort | logresolve | sort | uniq -c | sort -rn )
		if [ -z TEMPVAR ]
		then
			BANNEDHOSTNAME="$BANNEDHOSTNAME <tr><td>No IP banned yet.</td></tr>"
		else
			I=0
			C=0
			while IFS= read -r line
			do
				if [ $I -eq 0 ]
				then
					BANNEDHOSTNAME="$BANNEDHOSTNAME <tr>"
				fi
				BANNEDHOSTNAME="$BANNEDHOSTNAME <td>"$line"<td>"
				if [ $I -eq 1 ]
				then
					BANNEDHOSTNAME="$BANNEDHOSTNAME</tr>"
					I=0
				elif [ $I -lt 1 ]
				then
					I=$(( I + 1 ))
				fi
				C=$(( C + 1 ))
				if [ "$C" -ge 100 ]
				then
					break
				fi
			done < <(echo "$TEMPVAR")
		fi
		BANNEDHOSTNAME="$BANNEDHOSTNAME </table></div>"
		{
		   printf "%s\n" "$BANNEDHOSTNAME"
		} >>"$OUTPUTFILE" 
fi
###/BODY###


###Footer###
read -d '' FOOTER <<END
</div>
<br />
<div id="footer" align=center>
Copyright &copy; <a href="https://github.com/AhmadShamli/f2bla" target="_blank" title="F2bla" >AhmadShamli </a>
</div>
</body>
</html>
END
{
   printf "%s\n" "$FOOTER"
} >>"$OUTPUTFILE" 
{
   printf "%s\n" "$FOOTER"
} >>"$SIMPLEOUTPUTFILE" 
###/Footer###

###Email###
if [ "$SENDEMAIL" = true ]
then
	echo "Sending Email"
	mutt -e 'set content_type="text/html"' -e "send-hook . \"my_hdr From: ${FROMEMAIL} <${FROMEMAIL}>\"" ${TOEMAIL} -s "Fail2Ban Log Analyzed" <  ${SIMPLEOUTPUTFILE}
fi
###/Email###
echo "All Done"
