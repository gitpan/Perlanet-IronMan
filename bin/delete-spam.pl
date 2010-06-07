#!/usr/bin/perl

use strict;
use warnings;

=head1 SYNOPSIS

 perl delete-spam.pl --db_path=/home/graeme/workspace/Ironman/ironman.db

This script removes spammy content from the posts database and thus the feed.

=cut

use Data::Dumper;

use IronMan::Schema;

my ( $db_path );
GetOptions(
    'db_path=s'   => \$db_path,
) or die pod2usage;

unless($db_path) {
   die pod2usage;
}

my $schema = IronMan::Schema->connect("dbi:SQLite:$db_path");

my $banned = {};

$banned->{domains}->{feeds.launchpad.net} = 1;
$banned->{domains}->{feetloversblog.com} = 1;
$banned->{domains}->{themarketarticles.com} = 1;
$banned->{domains}->{femdomface.com} = 1;
$banned->{domains}->{shemalecumfest.com} = 1;
$banned->{domains}->{dementia.org} = 1;
$banned->{domains}->{dementia.org} = 1;
$banned->{domains}->{digitalffs.com} = 1;
$banned->{domains}->{goutmatter.com} = 1;
$banned->{domains}->{paintreatmentblog.com} = 1;

#$banned->{domains}->{} = 1;
#$banned->{domains}->{} = 1;
#$banned->{domains}->{} = 1;
#$banned->{domains}->{} = 1;
#$banned->{domains}->{} = 1;
#$banned->{domains}->{} = 1;
#$banned->{domains}->{} = 1;
#$banned->{domains}->{} = 1;
#$banned->{domains}->{} = 1;


$banned->{names}->{xanax} = 1;
$banned->{names}->{penis} = 1;
$banned->{names}->{femdom} = 1;
$banned->{names}->{shemale} = 1;
$banned->{names}->{levitra} = 1;
$banned->{names}->{cialis} = 1;

#$banned->{names}->{} = 1;
#$banned->{names}->{} = 1;
#$banned->{names}->{} = 1;
#$banned->{names}->{} = 1;
#$banned->{names}->{} = 1;
#$banned->{names}->{} = 1;



#Grab the feeds with no links.
my @feeds = $schema->resultset('Feed')->search({ link => undef })->all;

