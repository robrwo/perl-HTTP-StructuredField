# HTTP::libsfparse

Perl XS bindings for [libsfparse](https://github.com/ngtcp2/sfparse), the C
parser for HTTP Structured Field Values ([RFC
9651](https://www.rfc-editor.org/rfc/rfc9651), which obsoletes RFC 8941)
written for the ngtcp2 and nghttp3 QUIC/HTTP3 stacks.

Structured Field Values are the typed syntax used by newer HTTP fields such as
`Priority`, `Accept-CH`, `Cache-Status` and `Signature-Input`.

```perl
use HTTP::libsfparse qw( parse_dictionary :types :index );

# Every item is [ $type, $value, $params ],
# and a dictionary is a list of [ $key, $item ] pairs in field order.

my $pri = parse_dictionary('u=5, i');

$pri->[0][SFP_KEY];                                    # 'u'
$pri->[0][SFP_ITEM][SFP_VALUE];                        # 5
$pri->[0][SFP_ITEM][SFP_TYPE] == SFPARSE_TYPE_INTEGER; # true
$pri->[1][SFP_ITEM][SFP_TYPE] == SFPARSE_TYPE_BOOLEAN; # true

# Pairs collapse into a hash when duplicate keys do not matter
my %pri = map { $_->[SFP_KEY] => $_->[SFP_ITEM] } @$pri;
$pri{u}[SFP_VALUE];                                    # 5
```

The types are libsfparse's own `sfparse_type` enumerators, re-exported with
its values, so a value's type never has to be compared as a string. The
positions within an item and within a pair have names too (`:index`), so a
chain of subscripts reads as what it walks rather than as a row of numbers.

See the module documentation for the full interface:

    perldoc HTTP::libsfparse

## Installing

    perl Makefile.PL
    make
    make test
    make install

libsfparse is bundled in `src/`, so there is no system library to install. It
is two C files with no dependencies beyond the C standard library.

## Notes on the binding

libsfparse is a pull parser: it allocates nothing and never copies its input,
and its state machine fixes which of its entry points may follow which. The
binding keeps all of that inside a single function call. Each of the three
functions takes its own copy of the field value, initialises a parser of its
own, walks it from start to finish in the order the state machine expects, and
frees both before returning. So there is no parser object to misuse, no call
order for a caller to get wrong, and no state shared between calls.

That matters because calling those entry points out of order does not return
an error: libsfparse calls `abort()`, which would take the interpreter down
rather than raise something Perl can catch. Keeping each parser inside one
function call is what makes those branches unreachable, and it is the reason
the library can be vendored unmodified.

`sfparse_unescape`, `sfparse_base64decode` and `sfparse_pctdecode` are
deliberately not exposed: they assume pre-validated input and a
large-enough output buffer, so handed arbitrary Perl strings they would read
and write out of bounds. They are used internally on parser output only.

## Conformance

`t/13-httpwg-suite.t` runs the HTTP Working Group's
[structured-field-tests](https://github.com/httpwg/structured-field-tests)
conformance suite, vendored in `t/structured-field-tests/`: 1607 cases, of
which 873 are required to be rejected. Each case is compared as a whole
structure, with duplicate keys and parameters resolved the way RFC 9651 says
to.

One case passes by exemption rather than agreement: libsfparse rejects a byte
sequence with extra Base64 padding, which the suite marks `can_fail`, so
either behaviour conforms.

## License

This distribution is free software and may be redistributed and modified under
the same terms as Perl itself.

The bundled copy of libsfparse in `src/` is included unmodified under the MIT
license; see `src/LICENSE.sfparse`.

The conformance suite in `t/structured-field-tests/` is Copyright (c) 2018-
IETF Trust and the persons identified as authors of the code, and is included
under the 3-clause BSD license; see `t/structured-field-tests/LICENSE.md`.
