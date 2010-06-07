package Perlanet::IronMan;
# ABSTRACT: IronMan specific instance of Perlanet

use 5.8.0;
use strict;
use warnings;

use Moose;
use IronMan::Schema;
use HTML::Truncate;
use Perlanet::Feed;
use Data::Dumper;
use Try::Tiny;
use Carp;

extends 'Perlanet';
with qw(
    Perlanet::Trait::Scrubber
    Perlanet::Trait::Tidy
   );

use Perlanet::Entry;

our $VERSION = '0.01_01';

=head1 NAME

Perlanet::IronMan

This module extends Perlanet for the specific requirements of the Enlightened
Perl Organisation IronMan project.

=head1 SYNOPSIS

=head1 DESCRIPTION

This module uses an IronMan::Schema database to define feeds, collect the feeds
and then store them back into the IronMan::Schema database.

=cut

# This is some kind of Moose magic that I don't understand....  I think this
# means tha schema attribute of this object is built using the _build_schema
# method when the schema attribute is first used

has 'schema' => (
    is => 'rw',
    lazy_build => 1,
);

has 'dsn'     => ( isa => 'Str', is => 'ro' );
has 'db_user' => ( isa => 'Str', is => 'ro' );
has 'db_pass' => ( isa => 'Str', is => 'ro' );

has 'truncator' => (
    is         => 'rw',
    lazy_build => 1
);

around '_build_scrubber' => sub {
  my $self = shift;

  my %scrub_rules = (
      img => {
          src => qr{^http://},    # only URL with http://
          alt => 1,               # alt attributes allowed
          '*' => 0,               # deny all others
        },
      style  => 0,
      script => 0,
  );

  # Definitions for HTML::Scrub
  my %scrub_def = (
      '*'    => 1,                        # default rule, allow all attributes
      'href' => qr{^(?!(?:java)?script)}i,
      'src'  => qr{^(?!(?:java)?script)}i,
      'cite'     => '(?i-xsm:^(?!(?:java)?script))',
      'language' => 0,
      'name'        => 1,                 # could be sneaky, but hey ;)
      'onblur'      => 0,
      'onchange'    => 0,
        'onclick'     => 0,
        'ondblclick'  => 0,
        'onerror'     => 0,
        'onfocus'     => 0,
        'onkeydown'   => 0,
        'onkeypress'  => 0,
        'onkeyup'     => 0,
        'onload'      => 0,
        'onmousedown' => 0,
        'onmousemove' => 0,
        'onmouseout'  => 0,
        'onmouseover' => 0,
        'onmouseup'   => 0,
        'onreset'     => 0,
        'onselect'    => 0,
        'onsubmit'    => 0,
        'onunload'    => 0,
        'src'         => 0,
        'type'        => 0,
        'style'       => 0,
  );

  my $scrub = HTML::Scrubber->new;
  $scrub->rules(%scrub_rules);
  $scrub->default(1, \%scrub_def);

  return $scrub;
};

=head2 select_entries

The select entries function takes an array of Perlanet::Feed objects and
filters it to remove duplicates.  The non-duplicated feed entries are then
returned to the caller as an array of Perlanet::Entry objects.

    my $perlanet_entries = select_entries( @{ $perlanet_feeds });

=cut

override 'select_entries' => sub {
    my ($self, @feeds) = @_;

    # Perlanet::Feed objects to return
    my @feed_entries;

    # Iterate over the feeds working on them.
    for my $feed (@feeds) {

        # Fetch the XML::Feed:Entry objects from the Perlanet::Feed object
        my @entries = $feed->_xml_feed->entries;

        # Iterate over the XML::Feed::Entry objects
        foreach my $xml_entry (@entries) {

            # Problem with XML::Feed's conversion of RSS to Atom
            if ($xml_entry->issued && ! $xml_entry->modified) {
              $xml_entry->modified($xml_entry->issued);
            }

            # Always set category to something
            unless(defined($xml_entry->category)) {
                $xml_entry->category('');
            }

            #print(Dumper($xml_entry->tags));
            #print(Dumper($xml_entry->category));

            # Filter on keywords.  This fails for HTML encoded languages.
            # See http://onperl.ru/onperl/atom.xml for examples
            # specifically http://onperl.ru/onperl/2010/02/post.html
            # FIXME
            unless($self->_filter_entry_on_keywords($xml_entry)) {
                #print("Skipping due to no keyword match for '" . $xml_entry->link . "'\n");
                next;
            }

            # De-duplicate
            unless($self->_filter_entry_for_duplicate($xml_entry)) {
                #print("Skipping due to duplicate match for '" . $xml_entry->link . "'\n");
                next;
            }

            # Create a Perlanet::Entry object from the XML data retrieved
            my $entry = Perlanet::Entry->new(
                            _entry => $xml_entry,
                            feed   => $feed
            );

            push @feed_entries, $entry;
        }
   }

    return @feed_entries;
};

=head2 render

Given a Perlanet::Entry object, store the entry as a post in the
Schema::IronMan database

=cut

override 'render' => sub {
    my $self = shift;
    my $post = shift;

    my $posts = $post->entries;

    #print(Dumper($posts));
    #exit;

    foreach my $post (@{$posts}) {

        # Set the summary text to the summary or body if not supplied
        # This should probably be in config rather than hard coded.
        my $summary = $post->_entry->summary->body || $post->_entry->content->body;


        my $truncated = eval { $self->truncator->truncate($summary) };
        if ($@) {
            warn "Truncate failed: $@";
            $truncated = $summary;
        }

        $summary = $truncated;

        #print(Dumper($post));
        #exit;

        # Can't store a post if we can't work out the URL to link to it.
        unless(defined($post->_entry->link)) {
            print("ERROR.  Can't deal with lack of URL returned from XML::Feed::Entry for feed '" . $post->feed->url . "'\n");
            next;
        }

        # Get the entry tags
        my @tags = $post->_entry->category;

        try {
            # Do that whole insert thing...
            $self->schema->resultset('Post')->create( {
                feed_id          => $post->feed->id,
                author           => $post->_entry->author || $post->feed->title,
                tags             => join(",", @tags),
                url              => $post->_entry->link,
                title            => $post->_entry->title,
                posted_on        => $post->_entry->issued || DateTime->now,
                summary          => $summary,
                summary_filtered => $self->clean_html($summary),
                body             => $post->_entry->content->body,
                body_filtered    => $self->clean_html($post->_entry->content->body),
            } );
        }

        catch {
            Carp::cluck("ERROR: $_\n");
            Carp::cluck("ERROR: Post is:\n" . Dumper($post) . "\n");
            Carp::cluck("ERROR: Link URL is '" . $post->_entry->link . "'\n");
        };

    #print(Dumper($post));

    }
};

=head2 _build_feeds

Feeds are built from the Schema::IronMan database overriding the internal
defaults of utilising feeds specified in either the configuration file or as
configuration options when creating the Perlanet object.

=cut

has '+feeds' => (
    lazy => 1,
    default => sub {
        my $self = shift;
        return [ map {
            Perlanet::Feed->new(
                id => $_->id,
                url => $_->url || $_->link,
                website => $_->link || $_->url,
                title => $_->title,
                author => $_->owner,
            );
        } $self->schema->resultset('Feed')->all ];
    }
);

=head2 _build_schema

Build and return a schema object the first time that the schema attribute of
this object is accessed.

=cut

sub _build_schema {
    my $self = shift;

    return IronMan::Schema->connect(
        $self->dsn,
        $self->db_user,
        $self->db_pass,
    );
}

=head2 _build_truncator

Construct a HTML::Truncator object for truncating posts

=cut

sub _build_truncator {
    my $self = shift;
    my $html_truncate = HTML::Truncate->new(repair=>1);
    $html_truncate->chars(250);
    $html_truncate->ellipsis(" [...]");

    return $html_truncate;
}

=head2 _filter_entry_for_duplicate

Test to see if the supplied XML::Feed::Entry passes the configured filters.

Return 1 for a good entry and 0 for a bad entry.

=cut

sub _filter_entry_for_duplicate {
    my $self = shift;
    my $xml_entry = shift;

    my $count = $self->schema->resultset('Post')->search(
        { url => $xml_entry->link }
    )->count;

    if($count > 0) {
        #print("Duplicate post found for url '" . $xml_entry->link . "'\n");
        return 0;
    }

    #print("Post at url '" . $xml_entry->link . "' is new\n");

    return 1;
}

=head2 _filter_entry_on_keywords

Test to see if the supplied XML::Feed::Entry passes the configured filters.

Return 1 for a good entry and 0 for a bad entry.

THIS FUNCTION IS BROKEN.  SEE THE NOTES AT IT'S CALL.

=cut

sub _filter_entry_on_keywords {
    my $self = shift;
    my $xml_entry = shift;

    # print("Called to keyword filter url '" . $xml_entry->link . "'\n");

    # If no filter is defined, then we pass.
    unless(defined($self->{cfg}->{filter}->{keywords})) {
        print("No filter defined so skipping this check.\n");
        return 1;
    }

    my $filters = $self->{cfg}->{filter}->{keywords};

    # Iterate through the defined filters checking them
    foreach my $filter (@ { $filters } ) {

        #print("Checking for filter '$filter'\n");

        # If tags have been defined, check them.
        if(defined($xml_entry->tags)) {
            if(grep(/$filter/i, $xml_entry->tags)) {
                return 1;
            }
        }

        # Check the title if defined
        if(defined($xml_entry->title)) {
            if(grep(/$filter/i, $xml_entry->title)) {
                return 1;
            }
        }

        # Check the body if defined
        if(defined($xml_entry->content->body)) {
            if($xml_entry->content->body =~ m/$filter/i) {
                return 1;
            }
        }
    }

    # We got to the end and we didn't get a match.  Fail.
    return 0;
}

# We'll do the cleaning ourselves, as we need the dirty and clean versions
around 'clean_entries' => sub {
    my $orig = shift;
    my $self = shift;
    return @_;
};

# We don't want to remove the style attribute completely, but a clear: both will
# screw our layout up...
around 'clean_html' => sub {
    my $orig = shift;
    my ($self, $html) = @_;
    $html = $self->$orig($html);

    $html =~ s/style="(.*?)clear:(.*?);/style="$1/;
    return $html;
};

=head1 AUTHOR

Oliver Charles (aCiD2) <oliver.g.charles@googlemail.com>
Matt Troutt (mst), <mst@shadowcat.co.uk>
Ian Norton (idn), <i.d.norton@gmail.com>

=head1 SEE ALSO

IronMan::Schema
Perlanet

=head1 COPYRIGHT AND LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

no Moose;
__PACKAGE__->meta->make_immutable;
1;
