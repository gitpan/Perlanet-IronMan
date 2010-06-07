#!/bin/sh

eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)

# This is the cron wrapper for collecting the IronMan blogging feeds

# Date YYYYMMDD-H
DATE=`date +%Y%m%d-%H%M`

BASE=/var/www/ironboy.enlightenedperl.org

# ironman-collector script
SCRIPT=$BASE/ironman/Perlanet-IronMan/bin/ironman-collector.pl

# Logfile
LOG=$BASE/collector-logs/$DATE

$SCRIPT > $LOG 2>&1
