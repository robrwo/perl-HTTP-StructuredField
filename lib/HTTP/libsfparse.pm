package HTTP::libsfparse;

use strict;
use warnings;

use Exporter   5.57 qw( import );
use XSLoader   ();

our $VERSION = '0.002';

# The type constants are defined in XS, from libsfparse's own enum.
our @TYPES = qw(
    SFPARSE_TYPE_BOOLEAN
    SFPARSE_TYPE_INTEGER
    SFPARSE_TYPE_DECIMAL
    SFPARSE_TYPE_STRING
    SFPARSE_TYPE_TOKEN
    SFPARSE_TYPE_BYTESEQ
    SFPARSE_TYPE_INNER_LIST
    SFPARSE_TYPE_DATE
    SFPARSE_TYPE_DISPSTRING
);

# The positions within a parsed item, and within a key/value pair. Also
# defined in XS, from the same place the structures are built.
our @INDEX = qw(
    SFP_TYPE
    SFP_VALUE
    SFP_PARAMS
    SFP_KEY
    SFP_ITEM
);

our @EXPORT_OK
    = ( qw( parse_item parse_list parse_dictionary ), @TYPES, @INDEX );
our %EXPORT_TAGS = (
    all   => [@EXPORT_OK],
    types => [@TYPES],
    index => [@INDEX],
);

# The commit of ngtcp2/sfparse bundled in src/
our $LIBSFPARSE_COMMIT = 'b9673f9c5d010955c9ce310856c22f8d1505383f';

XSLoader::load( __PACKAGE__, $VERSION );

1;

__END__

=encoding UTF-8

=head1 NAME

HTTP::libsfparse - parse RFC 9651 HTTP Structured Field Values using libsfparse

=head1 SYNOPSIS

    use HTTP::libsfparse qw(
        parse_item parse_list parse_dictionary :types :index
    );

    # Every item is [ $type, $value, $params ], and the positions have
    # names, so none of this is counted out by hand.

    # Single item
    my $item = parse_item('text/html;q=0.8');
    $item->[SFP_TYPE] == SFPARSE_TYPE_TOKEN;     # true
    $item->[SFP_VALUE];                          # 'text/html'
    $item->[SFP_PARAMS][0][SFP_KEY];             # 'q'
    $item->[SFP_PARAMS][0][SFP_ITEM][SFP_VALUE]; # 0.8

    # Dictionary: RFC 9218 priority. A dictionary is a list of pairs.
    my $pri = parse_dictionary('u=5, i');
    $pri->[0][SFP_KEY];                          # 'u'
    $pri->[0][SFP_ITEM][SFP_VALUE];              # 5
    $pri->[1][SFP_ITEM][SFP_TYPE] == SFPARSE_TYPE_BOOLEAN;   # true

    # Pairs are easy to index when you do not mind losing duplicate keys
    my %pri = map { $_->[SFP_KEY] => $_->[SFP_ITEM] } @$pri;
    $pri{u}[SFP_VALUE];                          # 5

    # List, with an inner list and parameters
    my $list = parse_list('(1 2 3;b="foo"), bar, baz;f=:aGVsbG8=:');
    my $inner = $list->[0][SFP_VALUE];

    $list->[0][SFP_TYPE] == SFPARSE_TYPE_INNER_LIST;         # true
    $inner->[1][SFP_VALUE];                                  # 2
    $inner->[2][SFP_PARAMS][0][SFP_ITEM][SFP_VALUE];         # 'foo'
    $list->[2][SFP_PARAMS][0][SFP_ITEM][SFP_VALUE];          # 'hello'

    # Malformed input throws
    my $ok = eval { parse_list('a, b, "unterminated'); 1 };

=head1 DESCRIPTION

This module is an XS binding to
L<libsfparse|https://github.com/ngtcp2/sfparse>, the C parser for HTTP
Structured Field Values (L<RFC 9651|https://www.rfc-editor.org/rfc/rfc9651>,
which obsoletes RFC 8941) written for the ngtcp2 and nghttp3 QUIC/HTTP3
stacks.

Structured Field Values are the typed syntax used by newer HTTP header and
trailer fields, for example C<Priority> (RFC 9218), C<Accept-CH>,
C<Cache-Status> and C<Signature-Input>. Parsing them by hand with regular
expressions tends to go wrong in exactly the places that matter, so this
module delegates the whole grammar to a well fuzzed C implementation.

The interface is three functions. Each one takes a field value, parses it in
a single call, and returns plain Perl data structures; there is no parser
object to keep track of and no state that outlives a call.

A copy of libsfparse is bundled with this distribution, so nothing needs to be
installed separately. The bundled upstream commit is available as
C<$HTTP::libsfparse::LIBSFPARSE_COMMIT>.

=head1 VALUE REPRESENTATION

Every parsed item is an array reference of three elements:

    [ $type, $value, $params ]

      0   SFP_TYPE     one of the type constants below
      1   SFP_VALUE    the value itself
      2   SFP_PARAMS   an array reference of [ $key, $item ] pairs

Every item has all three elements whatever its type, so indexing into one
never has to check the type first.

The names in that second column are constants for the positions, described
under L</Indexing by name> below.

The type is always reported, because the Structured Fields types do not map
onto distinct Perl types: a token and a string are both Perl strings, and
losing the difference would make a value impossible to serialise again
correctly.

=head2 Types

C<$type> is one of the following constants, which are libsfparse's own
C<sfparse_type> enumerators and carry its values. Import them individually or
as C<:types>. Do not write the numbers out: they come from the C enum, which
is free to renumber itself when the bundled library is updated.

=over 4

=item C<SFPARSE_TYPE_BOOLEAN>

C<$value> is C<1> or C<0>.

=item C<SFPARSE_TYPE_INTEGER>

C<$value> is the integer. RFC 9651 limits these to 15 digits, so they are
always exact, including on a Perl built with 32 bit integers.

=item C<SFPARSE_TYPE_DECIMAL>

C<$value> is the number as a Perl floating point number. RFC 9651 allows at
most twelve digits before the decimal point and three after it, so every legal
decimal multiplied by a thousand is a whole number below C<2**53>: the
conversion is exact, and C<1.001> compares equal to the literal C<1.001>.

=item C<SFPARSE_TYPE_STRING>

C<$value> is the string with its C<\\> escapes removed. RFC 9651 strings only
hold printable ASCII.

=item C<SFPARSE_TYPE_TOKEN>

C<$value> is the token, for example C<text/html> or C<gzip>.

=item C<SFPARSE_TYPE_BYTESEQ>

C<$value> is the decoded byte string, not the Base64 text.

=item C<SFPARSE_TYPE_DATE>

C<$value> is the number of seconds since the Unix epoch, and may be negative.

=item C<SFPARSE_TYPE_DISPSTRING>

C<$value> is the percent-decoded display string, as a character string with
Perl's UTF-8 flag set. libsfparse has already validated the UTF-8.

=item C<SFPARSE_TYPE_INNER_LIST>

C<$value> is an array reference of items, each in this same form, each with
its own parameters. The inner list's own parameters are in C<$params> of the
inner list itself.

=back

=head2 Indexing by name

Reading a value as C<< $item->[1] >> is terse but says nothing about what is
being read, and the chains get long once parameters and inner lists are
involved. The positions are therefore available as constants, which import
individually or as C<:index>:

    $item->[SFP_VALUE]      # rather than $item->[1]

A dictionary member and a parameter are each a C<[ $key, $item ]> pair, whose
two positions are C<SFP_KEY> and C<SFP_ITEM>:

    $dict->[0][SFP_KEY]              # the first member's key
    $dict->[0][SFP_ITEM][SFP_VALUE]  # and its value

C<SFP_KEY> and C<SFP_TYPE> are both 0, and C<SFP_ITEM> and C<SFP_VALUE> are
both 1: a pair and an item are different shapes that happen to share those
two positions. Use whichever pair of names says what is being indexed, and a
chain reads as what it walks:

    # the parameter b of the third member of the first inner list
    $list->[0][SFP_VALUE][2][SFP_PARAMS][0][SFP_ITEM][SFP_VALUE]

These are defined in the same place in the C source as the code that builds
the structures, so they cannot fall out of step with the layout.

=head2 Parameters

C<$params> is always present on items returned by the functions in this
module, and is an empty array reference when the item has no parameters. It
holds one C<[ $key, $item ]> pair per parameter, in field order, and each
C<$item> is itself in the form above (its own C<$params> is undef, since
parameters cannot nest).

A parameter with no explicit value is boolean true, as the RFC requires.

Keys are reported as they appear and are not deduplicated, which is what lets
a caller reject a field value that repeats one. RFC 9651 says the last
occurrence of a repeated key wins; collapsing them that way is one line:

    my %params = map { $_->[0] => $_->[1] } @$params;

=head1 FUNCTIONS

Nothing is exported by default. Import the functions you want, the type
constants as C<:types>, the position constants as C<:index>, or everything as
C<:all>.

Each function takes the field value as a byte string and takes no options.

=head2 parse_item

    my $item = parse_item($string);

Parses a field value consisting of a single item and returns one item.
Trailing content after the item is a parse error, as is an empty field value.

=head2 parse_list

    my $list = parse_list($string);

Parses a List and returns an array reference of items. An empty field value
yields an empty array reference, which is what RFC 9651 calls an empty list.

=head2 parse_dictionary

    my $dict = parse_dictionary($string);

Parses a Dictionary and returns an array reference of C<[ $key, $item ]>
pairs in field order. An empty field value yields an empty array reference.

As with parameters, keys are not deduplicated, so a field value that repeats
one reports it twice; see L</Parameters> for why, and for the one-liner that
collapses them the way RFC 9651 says to.

=head1 ERRORS

Malformed input is reported by C<die>, with a message naming the byte offset
the parser had reached:

    HTTP::libsfparse: parse error at offset 17 at yourscript.pl line 42.

Field values arrive from the network, so malformed ones are ordinary rather
than exceptional: wrap the call in C<eval> (or C<Try::Tiny>, or C<try>) and
treat a failure as "this field is invalid, ignore it or reject the message",
which is what RFC 9651 section 3 requires anyway.

Note that the offset is where parsing stopped, which is not always exactly
where a human would say the mistake is. Do not parse the message to recover
the offset programmatically; it is for logs and humans.

=head1 BYTES, NOT CHARACTERS

HTTP field values are byte strings, and that is what these functions expect.
A character string is accepted as long as it contains nothing above U+00FF
(so it can be interpreted as bytes unambiguously); anything wider is a fatal
error rather than a silent misparse of Perl's internal UTF-8. If you have
decoded text, encode it first.

Display strings (C<%"...">) are the one place where RFC 9651 carries real
Unicode, and this module hands those back decoded, with the UTF-8 flag set.

=head1 WHAT IS DELIBERATELY NOT EXPOSED

libsfparse also provides C<sfparse_unescape>, C<sfparse_base64decode> and
C<sfparse_pctdecode>. Those functions assume their input has already been
validated by the parser and that the output buffer is large enough; handed
arbitrary Perl strings they would read and write out of bounds. They are used
internally on parser-produced values only, and are not exported.

=head1 THREADS

The functions in this module need no special care. Each call allocates its own
parser and its own copy of the input, frees both before returning, and shares
nothing with any other call, so they are re-entrant and safe to use from
several threads at once.

=head1 CONFORMANCE

The distribution bundles the HTTP Working Group's
L<structured-field-tests|https://github.com/httpwg/structured-field-tests>
conformance suite and runs it as F<t/13-httpwg-suite.t>: 1607 cases, 873 of
them field values that must be rejected.

All of them pass. One passes by exemption rather than agreement: libsfparse
rejects a byte sequence carrying extra Base64 padding, which the suite marks
C<can_fail>, so either behaviour conforms.

=head1 SEE ALSO

L<RFC 9651|https://www.rfc-editor.org/rfc/rfc9651>, Structured Field Values
for HTTP.

L<RFC 9218|https://www.rfc-editor.org/rfc/rfc9218>, Extensible Prioritization
Scheme for HTTP, whose C<Priority> field is a dictionary.

L<libsfparse|https://github.com/ngtcp2/sfparse> and its
L<documentation|https://nghttp2.org/sfparse/>.

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

The bundled copy of libsfparse in F<src/> is Copyright (c) 2023 sfparse
contributors and others, and is distributed under the MIT license; see
F<src/LICENSE.sfparse>. It is included unmodified.

=cut
