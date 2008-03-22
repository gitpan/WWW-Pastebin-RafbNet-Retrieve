package WWW::Pastebin::RafbNet::Retrieve;

use warnings;
use strict;

our $VERSION = '0.001';

use URI;
use HTML::TokeParser::Simple;
use HTML::Entities;
use base 'WWW::Pastebin::Base::Retrieve';

sub _make_uri_and_id {
    my ( $self, $in ) = @_;

    my ( $id ) = $in
    =~ m{ (?:http://)? (?:www\.)? rafb.net/p/ (\S+?) \.html}ix;

    $id = $in
        unless defined $id;

    return ( URI->new("http://rafb.net/p/$id.html"), $id );
}

sub _parse {
    my ( $self, $content ) = @_;
    return $self->_set_error( 'Nothing to parse (empty document retrieved)' )
        unless defined $content and length $content;

    my $parser = HTML::TokeParser::Simple->new( \$content );

    my %data;
    my %nav = (
        level       => 0,
        small       => 0,
        b           => 0,
        get_desc    => 0,
    );
    while ( my $t = $parser->get_token ) {
        if ( $t->is_start_tag('small') ) {
            if ( ++$nav{small} == 2 ) {
                $nav{get_desc} = 1;
            }
            $nav{level} = 1;
        }
        elsif ( $t->is_start_tag('b') ) {
            $nav{b}++;
            $nav{level} = 2;
        }
        elsif ( $nav{b} == 1 and $t->is_text ) {
            $data{lang} = $t->as_is;
            @nav{ qw(b level)} = (2, 3);
        }
        elsif ( $nav{b} == 3 and $t->is_text ) {
            $data{name} = $t->as_is;
            @nav{ qw(b level) } = (4, 4);
        }
        elsif ( $nav{get_desc} and $t->is_text ) {
            $data{desc} = substr $t->as_is, 13; # remove 'Description: ' text
            $nav{success} = 1;
            last;
        }
    }
    
    unless ( $nav{success} ) {
        return $self->_set_error(
            "Failed to parse paste.. \$nav{level} == $nav{level}"
        );
    }

    for ( values %data ) {
        decode_entities( $_ );
        s/\240/ /g; # replace any &nbsp; chars
    }

    $data{content} = $self->content( $self->_get_content )
        or return;

    return $self->results( \%data );
}

sub _get_content {
    my $self = shift;
    my $content_uri
    = URI->new( sprintf 'http://rafb.net/p/%s.txt', $self->id );

    my $content_response = $self->ua->get( $content_uri );
    if ( $content_response->is_success ) {
        return $content_response->content;
    }
    else {
        return $self->_set_error(
            'Failed to retrieve paste: ' . $content_response->status_line
        );
    }
}

1;
__END__

=head1 NAME

WWW::Pastebin::RafbNet::Retrieve - retrieve pastes from http://rafb.net/paste/ website

=head1 SYNOPSIS

    use strict;
    use warnings;

    use WWW::Pastebin::RafbNet::Retrieve;

    my $paster = WWW::Pastebin::RafbNet::Retrieve->new;

    my $results_ref = $paster->retrieve('http://rafb.net/p/84PcFH16.html')
        or die $paster->error;

    printf "Paste content is:\n%s\nPasted by %s highlighted in %s\n"
                . "Description: %s\n",
            @$results_ref{ qw(content name lang desc) };

=head1 DESCRIPTION

The module provides interface to retrieve pastes from
L<http://rafb.net/paste/> website via Perl.

=head1 CONSTRUCTOR

=head2 C<new>

    my $paster = WWW::Pastebin::RafbNet::Retrieve->new;

    my $paster = WWW::Pastebin::RafbNet::Retrieve->new(
        timeout => 10,
    );

    my $paster = WWW::Pastebin::RafbNet::Retrieve->new(
        ua => LWP::UserAgent->new(
            timeout => 10,
            agent   => 'PasterUA',
        ),
    );

Constructs and returns a brand new juicy WWW::Pastebin::RafbNet::Retrieve
object. Takes two arguments, both are I<optional>. Possible arguments are
as follows:

=head3 C<timeout>

    ->new( timeout => 10 );

B<Optional>. Specifies the C<timeout> argument of L<LWP::UserAgent>'s
constructor, which is used for retrieving. B<Defaults to:> C<30> seconds.

=head3 C<ua>

    ->new( ua => LWP::UserAgent->new( agent => 'Foos!' ) );

B<Optional>. If the C<timeout> argument is not enough for your needs
of mutilating the L<LWP::UserAgent> object used for retrieving, feel free
to specify the C<ua> argument which takes an L<LWP::UserAgent> object
as a value. B<Note:> the C<timeout> argument to the constructor will
not do anything if you specify the C<ua> argument as well. B<Defaults to:>
plain boring default L<LWP::UserAgent> object with C<timeout> argument
set to whatever C<WWW::Pastebin::RafbNet::Retrieve>'s C<timeout> argument is
set to as well as C<agent> argument is set to mimic Firefox.

=head1 METHODS

=head2 C<retrieve>

    my $results_ref = $paster->retrieve('http://rafb.net/p/84PcFH16.html')
        or die $paster->error;

    my $results_ref = $paster->retrieve('84PcFH16')
        or die $paster->error;

Instructs the object to retrieve a paste specified in the argument. Takes
one mandatory argument which can be either a full URI to the paste you
want to retrieve or just its ID.
On failure returns either C<undef> or an empty list depending on the context
and the reason for the error will be available via C<error()> method.
On success returns a hashref with the following keys/values:

    $VAR1 = {
        'lang' => 'Plain Text',
        'desc' => 'No description',
        'content' => 'blah blah teh paste',
        'name' => 'Anonymous Poster'
    };

=head3 content

    { 'content' => 'blah blah teh paste', }

The C<content> key will contain the textual content of the paste.

=head3 lang

    { 'lang' => 'Plain Text' }

The C<lang> key will contain the (computer) language of the paste.

=head3 desc

    { 'desc' => 'No description' }

The C<desc> key will contain the description of the paste.

=head3 name

    { 'name' => 'Anonymous Poster' }

The C<name> key will contain the name of the creature that posted the paste.

=head2 C<error>

    $paster->retrieve('84PcFH16')
        or die $paster->error;

On failure C<retrieve()> returns either C<undef> or an empty list depending
on the context and the reason for the error will be available via C<error()>
method. Takes no arguments, returns an error message explaining the failure.

=head2 C<id>

    my $paste_id = $paster->id;

Must be called after a successful call to C<retrieve()>. Takes no arguments,
returns a paste ID number of the last retrieved paste irrelevant of whether
an ID or a URI was given to C<retrieve()>

=head2 C<uri>

    my $paste_uri = $paster->uri;

Must be called after a successful call to C<retrieve()>. Takes no arguments,
returns a L<URI> object with the URI pointing to the last retrieved paste
irrelevant of whether an ID or a URI was given to C<retrieve()>

=head2 C<results>

    my $last_results_ref = $paster->results;

Must be called after a successful call to C<retrieve()>. Takes no arguments,
returns the exact same hashref the last call to C<retrieve()> returned.
See C<retrieve()> method for more information.

=head2 C<content>

    my $paste_content = $paster->content;

    print "Paste content is:\n$paster\n";

Must be called after a successful call to C<retrieve()>. Takes no arguments,
returns the actual content of the paste. B<Note:> this method is overloaded
for this module for interpolation. Thus you can simply interpolate the
object in a string to get the contents of the paste.

=head2 C<ua>

    my $old_LWP_UA_obj = $paster->ua;

    $paster->ua( LWP::UserAgent->new( timeout => 10, agent => 'foos' );

Returns a currently used L<LWP::UserAgent> object used for retrieving
pastes. Takes one optional argument which must be an L<LWP::UserAgent>
object, and the object you specify will be used in any subsequent calls
to C<retrieve()>.

=head1 SEE ALSO

L<LWP::UserAgent>, L<URI>

=head1 AUTHOR

Zoffix Znet, C<< <zoffix at cpan.org> >>
(L<http://zoffix.com>, L<http://haslayout.net>)

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-pastebin-rafbnet-retrieve at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Pastebin-RafbNet-Retrieve>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Pastebin::RafbNet::Retrieve

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Pastebin-RafbNet-Retrieve>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Pastebin-RafbNet-Retrieve>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Pastebin-RafbNet-Retrieve>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Pastebin-RafbNet-Retrieve>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 Zoffix Znet, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

