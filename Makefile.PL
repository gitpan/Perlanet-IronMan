
use strict;
use warnings;

 BEGIN { require 5.8.0; } 

use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'IronMan specific instance of Perlanet',
  'AUTHOR' => 'Enlightened Perl Organisation',
  'BUILD_REQUIRES' => {
    'Test::More' => '0'
  },
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.31'
  },
  'DISTNAME' => 'Perlanet-IronMan',
  'EXE_FILES' => [
    'bin/ironman-collector.pl',
    'bin/ironman-collector-cron-wrapper.sh',
    'bin/delete-spam.pl'
  ],
  'LICENSE' => 'perl',
  'NAME' => 'Perlanet::IronMan',
  'PREREQ_PM' => {
    'Carp' => '0',
    'Data::Dumper' => '0',
    'FindBin' => '0',
    'Getopt::Long' => '0',
    'HTML::Truncate' => '0',
    'IronMan::Schema' => '0',
    'Moose' => '0',
    'Perlanet' => '0',
    'Perlanet::Entry' => '0',
    'Perlanet::Feed' => '0',
    'Perlanet::Trait::Scrubber' => '0',
    'Perlanet::Trait::Tidy' => '0',
    'Pod::Usage' => '0',
    'Try::Tiny' => '0',
    'XML::Feed' => '0'
  },
  'VERSION' => '0.02_01',
  'test' => {
    'TESTS' => 't/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



