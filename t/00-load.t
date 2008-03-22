#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 21;

my $ID = 'g6iGAp31';

my $PASTE_DUMP = {
          "lang" => "Perl",
          "desc" => "perl magic \"error\"",
          "content" => "sub _set_error {\r\n    my ( \$self, \$error, \$is_net) = \@_;\r\n    if ( defined \$is_net ) {\r\n        \$self->error( 'Network error: ' . \$error->status_line );\r\n    }\r\n    else {\r\n        \$self->error( \$error );\r\n    }\r\n    return;\r\n}",
          "name" => "Zoffix"
};

BEGIN {
    use_ok('Carp');
    use_ok('URI');
    use_ok('HTML::TokeParser::Simple');
    use_ok('HTML::Entities');
    use_ok('WWW::Pastebin::Base::Retrieve');
    use_ok('WWW::Pastebin::RafbNet::Retrieve');
}

diag( "Testing WWW::Pastebin::RafbNet::Retrieve $WWW::Pastebin::RafbNet::Retrieve::VERSION, Perl $], $^X" );

use WWW::Pastebin::RafbNet::Retrieve;
my $paster = WWW::Pastebin::RafbNet::Retrieve->new( timeout => 10 );
isa_ok($paster, 'WWW::Pastebin::RafbNet::Retrieve');
can_ok($paster, qw(
    new
    retrieve
    error
    results
    id
    uri
    ua
    content
    _parse
    _set_error
    _get_content
    )
);

SKIP: {
    my $ret = $paster->retrieve($ID)
        or do {diag "Got error on ->retrieve($ID): " . $paster->error;
        skip "Got error", 13;};

    SKIP: {
        my $ret2 = $paster->retrieve("http://rafb.net/p/$ID.html")
            or do{diag "Got error on ->retrieve('http://rafb.net/p/$ID.html'): " . $paster->error; skip "Got error", 1;};
        is_deeply(
            $ret,
            $ret2,
            'calls with ID and URI must return the same'
        );
    }

    is_deeply(
        $ret,
        $PASTE_DUMP,
        q|dump from Dumper must match ->retrieve()'s response|,
    );

    for ( qw(lang content name desc) ) {
        ok( exists $ret->{$_}, "$_ key must exist in the return" );
    }

    is_deeply(
        $ret,
        $paster->results,
        '->results() must now return whatever ->retrieve() returned',
    );

    is(
        $paster->id,
        $ID,
        'paste ID must match the return from ->id()',
    );

    isa_ok( $paster->uri, 'URI::http', '->uri() method' );

    is(
        $paster->uri,
        "http://rafb.net/p/$ID.html",
        'uri() must contain a URI to the paste',
    );

    isa_ok( $paster->ua, 'LWP::UserAgent', '->ua() method' );

    is( "$paster", $ret->{content}, 'overloads');
    is( $paster->content, $ret->{content}, 'content()');
} # SKIP{}





