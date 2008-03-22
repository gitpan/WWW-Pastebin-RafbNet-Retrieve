#!/usr/bin/env perl

use strict;
use warnings;

use lib '../lib';
use WWW::Pastebin::RafbNet::Retrieve;

die "Usage: perl retrieve.pl <paste_ID_or_URI>\n"
    unless @ARGV;

my $Paste = shift;

my $paster = WWW::Pastebin::RafbNet::Retrieve->new;

my $results_ref = $paster->retrieve( $Paste )
    or die $paster->error;
use Data::Dumper;
$Data::Dumper::Useqq=1;
print Dumper $results_ref;
printf "Paste content is:\n%s\nPasted by %s highlighted in %s\n"
            . "Description: %s\n",
        @$results_ref{ qw(content name lang desc) };
