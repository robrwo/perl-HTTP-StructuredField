#!perl

use Test2::V0;

use HTTP::StructuredField;

use Digest::MD5 qw( md5 );
use MIME::Base64 qw( encode_base64 );

subtest "token" => sub {

    ok my $item = HTTP::StructuredField->parse_item('text/html;q=0.8');

    ok $item->is_token;
    is $item->value, 'text/html';

    ok $item->has_params;
    my $params = $item->params;
    ok my $q = $params->get("q");

    ok $q->is_decimal;
    is $q->type_name, "decimal";
    is $q->value, "0.8";

};

subtest "byteseq" => sub {

    my $bytes = md5( time );
    my $b64   = encode_base64($bytes, "");

    ok my $item = HTTP::StructuredField->parse_item(":${b64}:");

    ok !$item->has_params;
    ok $item->is_byteseq;
    is $item->value, $bytes;

};

subtest "inner list" => sub {

    ok my $item = HTTP::StructuredField->parse_item('("a" %"b" c;d="e")');

    ok $item->is_inner_list;

    my $list = $item->value;

    ok $list->[0]->is_string;
    ok $list->[1]->is_dispstring;
    ok $list->[2]->is_token;

    is $list->[0]->value, 'a';
    is $list->[1]->value, 'b';
    is $list->[2]->value, 'c';

    ok !$list->[0]->has_params;
    ok !$list->[1]->has_params;
    ok $list->[2]->has_params;

    my $params = $list->[2]->params;
    is [ $params->keys ], [qw( d )];

    ok $params->get("d")->is_string;
    is $params->get("d")->value, "e";

};


subtest "dict" => sub {

    ok my $dict = HTTP::StructuredField->parse_dictionary('u=5, i');

    ok my $u = $dict->get("u");
    ok $u->is_integer;
    is $u->type_name, "integer";
    is $u->value, 5;

    ok my $i = $dict->get("i");
    ok $i->is_boolean;
    ok !!$i->value;

};

subtest "list" => sub {

    ok my $list = HTTP::StructuredField->parse_list('this/that,"other",%"a%00f1o"');

    ok $list->[0]->is_token;
    ok $list->[1]->is_string;
    ok $list->[2]->is_dispstring;

    ok $list->[0]->value, 'this/that';
    ok $list->[1]->value, '"other"';
    ok $list->[2]->value, '"a\0f1o"';

};

done_testing;
