#!/bin/bash

# Fail2Ban Log Analyzer
# This script reads fail2ban logs and writes a readable HTML report.
# It is based on http://www.the-art-of-web.com/system/fail2ban-log/
#
# Cron example (runs daily at 02:11):
# 11 2 * * * root /root/analyze.sh
#
# https://github.com/AhmadShamli/f2bla/

###Config###
LOGFILE=${LOGFILE:-'/var/log/fail2ban/fail2ban.log'}
OUTPUTLOCATION=${OUTPUTLOCATION:-'/var/www/'}

WEBDOMAIN=${WEBDOMAIN:-'https://www.example.com/'}
FILENAME=${FILENAME:-'fail2ban.html'}
SIMPLEFILENAME=${SIMPLEFILENAME:-'fail2ban_short.html'}
OUTPUTFILE="${OUTPUTLOCATION%/}/$FILENAME"
SIMPLEOUTPUTFILE="${OUTPUTLOCATION%/}/$SIMPLEFILENAME"

WHOISSERVER=${WHOISSERVER:-'http://whois.ens.my/'}

DATETODAY=$(date +"%d-%m-%Y %T")

COUNTBYIP=${COUNTBYIP:-true}
RESOLVESUBNET=${RESOLVESUBNET:-true}
RESOLVEHOST=${RESOLVEHOST:-false}

SIMPLE=${SIMPLE:-true}

SENDEMAIL=${SENDEMAIL:-true}
if [ "${1:-}" = 'noemail' ]; then
	SENDEMAIL=false
fi
FROMEMAIL=${FROMEMAIL:-'vpc@sd1mavpc.com'}
TOEMAIL=${TOEMAIL:-'email@example.com'}
###/Config###

if [ ! -r "$LOGFILE" ]; then
	printf 'Error: unable to read log file: %s\n' "$LOGFILE" >&2
	exit 1
fi

mkdir -p "$OUTPUTLOCATION"

append_to_report() {
	printf '%s\n' "$1" >>"$OUTPUTFILE"
}

append_to_simple_report() {
	printf '%s\n' "$1" >>"$SIMPLEOUTPUTFILE"
}

append_to_reports() {
	append_to_report "$1"
	append_to_simple_report "$1"
}

is_empty() {
	[ -z "$1" ]
}

ban_count_for_log_date() {
	local log_date=$1
	grep -F "Ban " "$LOGFILE" | grep -F "$log_date" | wc -l
}

ban_count_for_all_logs_date_prefix() {
	local date_prefix=$1
	zgrep -h "Ban " "$LOGFILE"* | grep -F "$date_prefix" | wc -l
}

ip_table_cells() {
	local rows=$1
	local limit=${2:-0}
	local columns=${3:-5}
	local i=0
	local c=0
	local line ip ip_count ip_type html=''

	while IFS= read -r line; do
		[ -n "$line" ] || continue
		if [ "$i" -eq 0 ]; then
			html="$html <tr>"
		fi

		ip=$(printf '%s\n' "$line" | awk '{print $2}')
		ip_count=$(printf '%s\n' "$line" | awk '{print $1}')
		ip_type=$(printf '%s\n' "$line" | awk '{print $3}')
		html="$html <td>$ip_count&nbsp;<a href=\"$WHOISSERVER$ip\" target=\"_blank\">$ip</a>&nbsp;$ip_type</td>"

		if [ "$i" -eq $((columns - 1)) ]; then
			html="$html </tr>"
			i=0
		else
			i=$((i + 1))
		fi

		c=$((c + 1))
		if [ "$limit" -gt 0 ] && [ "$c" -ge "$limit" ]; then
			break
		fi
	done <<<"$rows"

	if [ "$i" -ne 0 ]; then
		html="$html </tr>"
	fi

	printf '%s' "$html"
}

summary_table_cells() {
	local rows=$1
	local limit=${2:-0}
	local columns=${3:-5}
	local i=0
	local c=0
	local line html=''

	while IFS= read -r line; do
		[ -n "$line" ] || continue
		if [ "$i" -eq 0 ]; then
			html="$html <tr>"
		fi

		html="$html <td>$line</td>"

		if [ "$i" -eq $((columns - 1)) ]; then
			html="$html </tr>"
			i=0
		else
			i=$((i + 1))
		fi

		c=$((c + 1))
		if [ "$limit" -gt 0 ] && [ "$c" -ge "$limit" ]; then
			break
		fi
	done <<<"$rows"

	if [ "$i" -ne 0 ]; then
		html="$html </tr>"
	fi

	printf '%s' "$html"
}

###HEAD###
read -r -d '' PAGEHEAD <<END
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

printf '%s\n' "$PAGEHEAD" >"$OUTPUTFILE"
printf '%s\n' "$PAGEHEAD" >"$SIMPLEOUTPUTFILE"
###/HEAD###

###BODY###
echo "Generating : Banned Summary"
BANNEDSUMMARY="<div id=\"row\"><h2>Banned Count Summary</h2><table border='1'>"
BANNEDSUMMARY="$BANNEDSUMMARY <tr><td colspan=1 style='min-width:200px'></td><td align='center' style='min-width:100px'>Count</td></tr>"

BANNED=$(fail2ban-client status ssh | grep 'Total banned' | awk '{print $4}')
BANNEDSUMMARY="$BANNEDSUMMARY <tr><td colspan=1 align='center'>Current<br /><small>Total IP currently Banned</small></td><td align='center'>$BANNED</td></tr>"

TODAY=$(date +%Y-%m-%d)
BANNED=$(ban_count_for_log_date "$TODAY")
BANNEDSUMMARY="$BANNEDSUMMARY <tr><td colspan=1 align='center'>Today<br /><small>as of $DATETODAY</small></td><td align='center'>$BANNED</td></tr>"

YESTERDAY=$(date -d 'yesterday' +%Y-%m-%d)
BANNED=$(ban_count_for_log_date "$YESTERDAY")
BANNEDSUMMARY="$BANNEDSUMMARY <tr><td colspan=1 align='center'>Yesterday<br /><small>$YESTERDAY</small></td><td align='center'>$BANNED</td></tr>"

LAST2DAY=$(date --date="2 days ago" +"%Y-%m-%d")
BANNED=$(ban_count_for_log_date "$LAST2DAY")
BANNEDSUMMARY="$BANNEDSUMMARY <tr><td colspan=1 align='center'>Last 2 days<br /><small>$LAST2DAY</small></td><td align='center'>$BANNED</td></tr>"

THISMONTH=$(date +%Y-%m)
BANNED=$(ban_count_for_all_logs_date_prefix "$THISMONTH")
BANNEDSUMMARY="$BANNEDSUMMARY <tr><td colspan=1 align='center'>This Month<br /><small>$THISMONTH</small></td><td align='center'>$BANNED</td></tr>"

LASTMONTH=$(date -d 'last month' +%Y-%m)
BANNED=$(ban_count_for_all_logs_date_prefix "$LASTMONTH")
BANNEDSUMMARY="$BANNEDSUMMARY <tr><td colspan=1 align='center'>Last Month<br /><small>$LASTMONTH</small></td><td align='center'>$BANNED</td></tr>"

THISYEAR=$(date +%Y-)
BANNED=$(ban_count_for_all_logs_date_prefix "$THISYEAR")
BANNEDSUMMARY="$BANNEDSUMMARY <tr><td colspan=1 align='center'>This Year<br /><small>$THISYEAR</small></td><td align='center'>$BANNED</td></tr>"

LASTYEAR=$(date -d 'last year' +%Y-)
BANNED=$(ban_count_for_all_logs_date_prefix "$LASTYEAR")
BANNEDSUMMARY="$BANNEDSUMMARY <tr><td colspan=1 align='center'>Last year<br /><small>$LASTYEAR</small></td><td align='center'>$BANNED</td></tr>"

BANNEDSUMMARY="$BANNEDSUMMARY </table></div>"
append_to_reports "$BANNEDSUMMARY"
#############

echo "Generating : Todays' Banned IP"
BANNEDTODAY="<div id=\"row\"><h2>Todays' Banned IP <small>< As of today $DATETODAY ></small></h2><table>"
TEMPVAR=$(grep -F "Ban " "$LOGFILE" | grep -F "$TODAY" | awk '{print $NF,$6}' | sort | uniq -c | sort -n)
if is_empty "$TEMPVAR"; then
	BANNEDTODAY="$BANNEDTODAY <tr><td>No IP banned for this date.</td></tr>"
else
	BANNEDTODAY="$BANNEDTODAY$(ip_table_cells "$TEMPVAR")"
fi
BANNEDTODAY="$BANNEDTODAY </table></div>"
append_to_reports "$BANNEDTODAY"
#############

echo "Generating : Yesterday' Banned IP"
BANNEDYESTERDAY="<div id=\"row\"><h2>Yesterdays' Banned IP <small>< yesterday $YESTERDAY ></small></h2><table>"
TEMPVAR=$(grep -F "Ban " "$LOGFILE" | grep -F "$YESTERDAY" | awk '{print $NF,$6}' | sort | uniq -c | sort -n)
if is_empty "$TEMPVAR"; then
	BANNEDYESTERDAY="$BANNEDYESTERDAY <tr><td>No IP banned for this date.</td></tr>"
else
	BANNEDYESTERDAY="$BANNEDYESTERDAY$(ip_table_cells "$TEMPVAR")"
fi
BANNEDYESTERDAY="$BANNEDYESTERDAY </table></div>"
append_to_reports "$BANNEDYESTERDAY"
#############

echo "Generating : Top 100 Date"
BANNEDBYDATE='<div id="row"><h2>Top 100 Date <small>with highest banned count</small></h2><table>'
TEMPVAR=$(zgrep -h "Ban " "$LOGFILE"* | awk '{print $1}' | sort | uniq -c | sort -rn)
if is_empty "$TEMPVAR"; then
	BANNEDBYDATE="$BANNEDBYDATE <tr><td>No IP banned yet.</td></tr>"
else
	BANNEDBYDATE="$BANNEDBYDATE$(summary_table_cells "$TEMPVAR" 100)"
fi
BANNEDBYDATE="$BANNEDBYDATE </table></div>"
append_to_report "$BANNEDBYDATE"
#############

if [ "$COUNTBYIP" = true ]; then
	echo "Generating : Top 100 IP"
	BANNEDBYIP='<div id="row"><h2>Top 100 IP <small>with highest banned count</small></h2><table>'
	TEMPVAR=$(zgrep -h "Ban " "$LOGFILE"* | awk '{print $NF,$6}' | sort | uniq -c | sort -rn)
	if is_empty "$TEMPVAR"; then
		BANNEDBYIP="$BANNEDBYIP <tr><td>No IP banned yet.</td></tr>"
	else
		BANNEDBYIP="$BANNEDBYIP$(ip_table_cells "$TEMPVAR" 100)"
	fi
	BANNEDBYIP="$BANNEDBYIP </table></div>"
	append_to_report "$BANNEDBYIP"
fi
#############

if [ "$RESOLVESUBNET" = true ]; then
	echo "Generating : Top 100 Subnet"
	BANNEDBYSUBNET='<div id="row"><h2>Top 100 Subnet <small>being banned</small></h2><table>'
	TEMPVAR=$(zgrep -h "Ban " "$LOGFILE"* | awk '{print $NF}' | awk -F. '{print $1"."$2"."}' | sort | uniq -c | sort -rn)
	if is_empty "$TEMPVAR"; then
		BANNEDBYSUBNET="$BANNEDBYSUBNET <tr><td>No IP banned yet.</td></tr>"
	else
		I=0
		C=0
		while IFS= read -r line; do
			[ -n "$line" ] || continue
			if [ "$I" -eq 0 ]; then
				BANNEDBYSUBNET="$BANNEDBYSUBNET <tr>"
			fi
			IP=$(printf '%s\n' "$line" | awk '{print $2}')
			IPCOUNT=$(printf '%s\n' "$line" | awk '{print $1}')
			BANNEDBYSUBNET="$BANNEDBYSUBNET <td>$IPCOUNT&nbsp;<a href=\"$WHOISSERVER${IP}0.0\" target=\"_blank\">$IP</a></td>"
			if [ "$I" -eq 4 ]; then
				BANNEDBYSUBNET="$BANNEDBYSUBNET </tr>"
				I=0
			else
				I=$((I + 1))
			fi
			C=$((C + 1))
			if [ "$C" -ge 100 ]; then
				break
			fi
		done <<<"$TEMPVAR"
		if [ "$I" -ne 0 ]; then
			BANNEDBYSUBNET="$BANNEDBYSUBNET </tr>"
		fi
	fi
	BANNEDBYSUBNET="$BANNEDBYSUBNET </table></div>"
	append_to_report "$BANNEDBYSUBNET"
fi
#############

if [ "$RESOLVEHOST" = true ]; then
	echo "Generating : Top 100 HostName"
	BANNEDHOSTNAME='<div id="row"><h2>Top 100 HostName</h2><table>'
	TEMPVAR=$(zgrep -h "Ban " "$LOGFILE"* | awk '{print $NF}' | sort | logresolve | sort | uniq -c | sort -rn)
	if is_empty "$TEMPVAR"; then
		BANNEDHOSTNAME="$BANNEDHOSTNAME <tr><td>No IP banned yet.</td></tr>"
	else
		BANNEDHOSTNAME="$BANNEDHOSTNAME$(summary_table_cells "$TEMPVAR" 100 2)"
	fi
	BANNEDHOSTNAME="$BANNEDHOSTNAME </table></div>"
	append_to_report "$BANNEDHOSTNAME"
fi
###/BODY###


###Footer###
read -r -d '' FOOTER <<END
</div>
<br />
<div id="footer" align=center>
Copyright &copy; <a href="https://github.com/AhmadShamli/f2bla" target="_blank" title="F2bla" >AhmadShamli </a>
</div>
</body>
</html>
END
append_to_reports "$FOOTER"
###/Footer###

###Email###
if [ "$SENDEMAIL" = true ]; then
	echo "Sending Email"
	mutt -e 'set content_type="text/html"' -e "send-hook . \"my_hdr From: ${FROMEMAIL} <${FROMEMAIL}>\"" "$TOEMAIL" -s "Fail2Ban Log Analyzed" <"$SIMPLEOUTPUTFILE"
fi
###/Email###
echo "All Done"
