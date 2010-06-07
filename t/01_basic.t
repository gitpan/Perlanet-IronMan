use strict;
use warnings;

use Perlanet::IronMan;
use XML::Feed;
use IronMan::Schema;
use Test::More tests => 2;

my $dir = "t/var";

# Check the var directory exists for our testing.
unless(-d $dir) {
    mkdir($dir);
}

unlink("t/var/test.db");
my $schema = IronMan::Schema->connect("dbi:SQLite:t/var/test.db");
$schema->deploy();

## Initialise with something to test against:
$schema->resultset('Feed')->create({ id => 'fdave',
                                     url => 'file:t/data/dave.xml',
                                     link => 'http://blog.dave.org.uk/',
                                     owner => 'Dave',
                                     title => "Dave's Blog",
                                   });
$schema->resultset('Post')->create({ url => 'http://blog.dave.org.uk/2009/foo.html',
                                     feed_id => 'dave',
                                     title => 'Entry 1',
                                     posted_on => DateTime->now,
                                     body => 'blahblah',
                                     author => 'Dave',
                                     tags => 'perl'
                                   });

my $p = Perlanet::IronMan->new(
    dsn => 'dbi:SQLite:t/var/test.db',
    title => 'planet test',
    description => 'Testing stuff',
    url => 'http://google.com',
    self_link => 'http://google.com',
);


is($schema->resultset('Post')->count, 1);
$p->run;
is($schema->resultset('Post')->count, 2);

