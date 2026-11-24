package HTTP::StructuredField;

use v5.20;
use warnings;

use HTTP::libsfparse qw( :index );
use Ref::Util qw( is_plain_arrayref );
use Sub::Util ();

use experimental qw( postderef signatures );

our $VERSION = 'v0.0.1';

# ABSTRACT: parse RFC 9421 HTTP Structured Fields

=head1 SYNOPSIS

    use HTTP::StructuredField;

    try {

        my $dict = HTTP::StructuredField->parse_dictionary( $msg->header("signature-input") );
        for my $key ( keys $dist->%* ) {

            my $input = $dict->{$key};
            $input->is_list or die "list expected";

            my @items = $input->value->@*;

      }


    }
    catch ($error) {
      ...
    }

=head1 DESCRIPTION

This is an object-oriented wrapper around L<HTTP::libsfparse>, for correctly parsing
L<RFC 9421|https://www.rfc-editor.org/info/rfc9421/> HTTP Structured Fields.

=cut

=method parse_item

This parses a string as an C<HTTP::StructuredField> item.

=cut

sub parse_item($class, $str) {
    my $self = HTTP::libsfparse::parse_item($str);
    bless $self, $class;
}

=method parse_dictionary

This parses a string as a dictionary.
The result is a hash reference where the values are C<HTTP::StructuredField> items.

=cut

sub parse_dictionary( $class, $str) {
    my $list = HTTP::libsfparse::parse_dictionary($str);
    my %dict = map { $_->[SFP_KEY] => bless $_->[SFP_ITEM], $class; } $list->@*;
    return \%dict;
}

=method parse_list

This parses a string as a list.
The result is a list reference where the elements are C<HTTP::StructuredField> items.

=cut

sub parse_list($class, $str) {
    my $list = HTTP::libsfparse::parse_list($str);
    return [ map { bless $_, $class } $list->@* ];
}

=method value

This returns the value of the item.

=cut

sub value($self) {
    if ( $self->is_list ) {
        my $class = ref($self);
        return [ map { bless $_, $class } $self->[SFP_VALUE]->@* ];
    }
    else {
        return $self->[SFP_VALUE];
    }
}

=method params

This returns a hash reference of the item's parameters.
The values are C<HTTP::StructuredField> items.

=cut

sub params($self) {
    my $class = ref($self);
    my $list = $self->[SFP_PARAMS];
    my %dict = map { $_->[SFP_KEY] => bless $_->[SFP_ITEM], $class; } $list->@*;
    return \%dict;
}

=method has_params

This returns true if the item has L</params>.

=cut

sub has_params($self) {
    return ( $self->[SFP_PARAMS]->@* ) > 0;
}

=method type_name

The returns the name of the type as a short string.

=method type

This returns the numeric type id, which will correspond to one of the constants from L<HTTP::libsfparse>.

Generally you'll want to check the L</type_name> or use a predicate such as L</is_boolean>.

=method is_boolean

Returns true if the value is a boolean.

=method is_byteseq

Returns true if the value is a byte sequence.

=method is_decimal

Returns true if the value is a decimal number.

=method is_dispstring

Returns true if the value is a Unicode string, a.k.a. a display string.

Note that the value will be surrounded by double quotes, unless it is an element of an inner list or parameter value.

=method is_integer

=method is_list

Returns true if the value is an inner list.
The value will be an array reference to a list of unblessed items.

=method is_string

Returns true if the value is a 7-bit ASCII string.

Note that the value will be surrounded by double quotes, unless it is an element of an inner list or parameter value.

=method is_token

=cut

sub type($self) {
    return $self->[SFP_TYPE];
}

{

    my %names;

    for my $name (@HTTP::libsfparse::TYPES) {

        no strict 'refs';

        my $fn   = "HTTP::libsfparse::${name}";
        my $code = $fn->();

        my ($suffix) = $name =~ /_([A-Z]+)\z/a;
        my $method = "is_" . lc($suffix);

        *$method = Sub::Util::set_subname __PACKAGE__ . "::$method" => sub($self) { $self->type == $code };

        $names{$code} = lc($suffix);

    }

    sub type_name($self) {
        return $names{ $self->type };

    }

}

1;
