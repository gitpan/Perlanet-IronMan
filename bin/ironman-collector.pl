#!/usr/bin/perl

use strict;
use warnings;

use XML::Feed;
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;
use Perlanet::IronMan;
use IronMan::Schema;

use FindBin '$Bin';
use lib "$Bin/../lib";

my ($cli_dsn, $cli_feed, $DEBUG);

GetOptions(
    'dsn=s'       => \$cli_dsn,
    'feed=s'      => \$cli_feed,
    'v'           => \$DEBUG,
) or die pod2usage;

# Perlanet configuration settings
my $cfg = {
    title       => "all.things.per.ly",
    description => "all.things.per.ly IronMan agregation",
    url         => "http://ironboy.enlightenedperl.org/",
    self_link   => "http://ironboy.enlightenedperl.org/",
    agent       => "Perlanet",
    author_name => "Perlanet",
    feed_format => "Atom",
    entries     => 10,
};

$cfg->{filter}->{keywords} = ["cpan", "ironman", "perl"];

# Database DSN
if(defined($cli_dsn)) {
    $cfg->{dsn} = $cli_dsn;
}

else {
    $cfg->{dsn} = "dbi:SQLite:/var/www/ironboy.enlightenedperl.org/ironman/subscriptions.db";
    #$cfg->{db}{dsn} = "dbi:SQLite:/var/www/ironboy.enlightenedperl.org/ironman/testsubscriptions.db";
}

# Get me a Perlanet::IronMan thingy using our config from above
my $p = Perlanet::IronMan->new( $cfg );

# Should be calling run here
$p->run;
exit;

# I'm taking run apart here
$p->update_opml;

# Get the list of feeds from the database
print("Fetching the Perlanet::Feed objects array\n");
my $feeds_obj = $p->feeds;

# Sample data:
#      bless( {
#               'website' => 'http://jjnapiorkowski.vox.com/library/posts/page/1/',
#               'entries' => [],
#               'url' => 'http://jjnapiorkowski.vox.com/library/posts/atom.xml',
#               'title' => 'John Napiorkowski',
#               'id' => 'D78C979A-6678-11DE-98DD-DC36AA5A0737',
#               'author' => ''
#             }, 'Perlanet::Feed' )

#if($DEBUG) { print(Dumper($feeds_obj)); }
#exit;

if($DEBUG) { print("Fetching the feed data\n"); }
#my @feeds_data = $p->fetch_feeds( @{ $feeds_obj } );

foreach my $feed_obj ( @{ $feeds_obj } ) {

    if(defined($cli_feed)) {
        unless($feed_obj->url eq $cli_feed) {
            next;
        }
    }

    if($DEBUG) { print("Feed object:\n"); print(Dumper($feed_obj)); }

    if($DEBUG) { print("Fetching posts from feed '" . $feed_obj->url . "'\n"); }
    my @feed_posts = $p->fetch_feeds( $feed_obj );

    #if($DEBUG) { print(Dumper(@feed_posts)); }

    if($DEBUG) { print("Filtering posts to remove duplicates\n"); }
    # Filter feed_posts for previously seen posts
    @feed_posts = $p->select_entries(@feed_posts);

    if($DEBUG) { print(Dumper(@feed_posts)); }

    if($DEBUG) { print("Building a post object\n"); }
    my $post = $p->build_feed(@feed_posts);
    if($DEBUG) { print(Dumper($post)); }

    if($DEBUG) { print("Rendering post object\n"); }
    $p->render($post);

}


#exit;

# Get the entries from the feeds data
#print("Building the entries array\n");
#my @entries = $p->select_entries( @feeds_data );

#print(Dumper(@entries));
#exit;

#my $feed = $p->build_feed(@entries);
#$p->render($feed)

