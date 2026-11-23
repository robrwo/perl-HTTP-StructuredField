#!perl

use strict;
use warnings;

use Test::More;

BEGIN { use_ok 'HTTP::libsfparse' }

ok defined $HTTP::libsfparse::VERSION, 'HTTP::libsfparse has a version';

like $HTTP::libsfparse::LIBSFPARSE_COMMIT, qr/^[0-9a-f]{40}\z/,
    'the bundled libsfparse commit is recorded';

for my $name (qw( parse_item parse_list parse_dictionary )) {
    ok( HTTP::libsfparse->can($name), "HTTP::libsfparse::$name is defined" );
    ok( !main->can($name),         "$name is not exported by default" );
}

# The type constants come from libsfparse's own enum, so the test says only
# that they exist, are distinct, and are what the parser puts in a value.

{
    my @types = qw(
        SFPARSE_TYPE_BOOLEAN SFPARSE_TYPE_INTEGER SFPARSE_TYPE_DECIMAL
        SFPARSE_TYPE_STRING  SFPARSE_TYPE_TOKEN   SFPARSE_TYPE_BYTESEQ
        SFPARSE_TYPE_INNER_LIST SFPARSE_TYPE_DATE SFPARSE_TYPE_DISPSTRING
    );

    is_deeply [ sort @HTTP::libsfparse::TYPES ], [ sort @types ],
        'the type constants are the ones libsfparse defines';

    my @values = map {
        my $can = HTTP::libsfparse->can($_);
        ok( $can, "HTTP::libsfparse::$_ is defined" );
        ok( !main->can($_), "$_ is not exported by default" );
        $can ? $can->() : undef;
    } @types;

    my %seen;
    $seen{ defined $_ ? $_ : 'undef' }++ for @values;

    is scalar keys %seen, scalar @types, 'and they are all distinct';

    is HTTP::libsfparse::parse_item('42')->[0], HTTP::libsfparse::SFPARSE_TYPE_INTEGER,
        'a parsed value reports one of them';
}

# The position constants have to name the slots the parser actually fills,
# which is the one thing a reader of the layout cannot check for themselves.

{
    my @index = qw(
        SFP_TYPE SFP_VALUE SFP_PARAMS SFP_KEY SFP_ITEM
    );

    is_deeply [ sort @HTTP::libsfparse::INDEX ], [ sort @index ],
        'the position constants are the documented ones';

    for my $name (@index) {
        ok( HTTP::libsfparse->can($name), "HTTP::libsfparse::$name is defined" );
        ok( !main->can($name),         "$name is not exported by default" );
    }

    my %at = map { $_ => HTTP::libsfparse->can($_)->() } @index;
    my $item = HTTP::libsfparse::parse_item('1.5;p=2');

    is $item->[ $at{SFP_TYPE} ], HTTP::libsfparse::SFPARSE_TYPE_DECIMAL,
        'SFP_TYPE is where the type is';
    is $item->[ $at{SFP_VALUE} ], 1.5, 'SFP_VALUE is where the value is';
    is $item->[ $at{SFP_PARAMS} ][0][ $at{SFP_KEY} ], 'p',
        'SFP_PARAMS and SFP_KEY reach a parameter key';
    is $item->[ $at{SFP_PARAMS} ][0][ $at{SFP_ITEM} ][ $at{SFP_VALUE} ], 2,
        'and SFP_ITEM its value';
}

{
    package My::Importer;

    HTTP::libsfparse->import(':all');

    ::ok( My::Importer->can('parse_dictionary'),
        ':all exports the functions' );
}

done_testing;
