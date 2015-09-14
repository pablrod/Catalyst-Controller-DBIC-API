package Catalyst::Controller::DBIC::API::StaticArguments;

#ABSTRACT: Provides controller level configuration arguments
use Moose::Role;
use MooseX::Types::Moose(':all');
use namespace::autoclean;

requires 'check_column_relation';

=attribute_public create_requires create_allows update_requires update_allows

These attributes control requirements and limits to columns when creating or
updating objects.

Each provides a number of handles:

    "get_${var}_column" => 'get'
    "set_${var}_column" => 'set'
    "delete_${var}_column" => 'delete'
    "insert_${var}_column" => 'insert'
    "count_${var}_column" => 'count'
    "all_${var}_columns" => 'elements'

=cut

foreach my $var (
    qw( create_requires create_allows update_requires update_allows ))
{
    has $var => (
        is      => 'ro',
        isa     => ArrayRef [ Str | HashRef ],
        traits  => ['Array'],
        default => sub { [] },
        trigger => sub {
            my ( $self, $new ) = @_;
            $self->check_column_relation( $_, 1 ) for @$new;
        },
        handles => {
            "get_${var}_column"    => 'get',
            "set_${var}_column"    => 'set',
            "delete_${var}_column" => 'delete',
            "insert_${var}_column" => 'insert',
            "count_${var}_column"  => 'count',
            "all_${var}_columns"   => 'elements',
        }
    );

    before "set_${var}_column" =>
        sub { $_[0]->check_column_relation( $_[2], 1 ) };
    before "insert_${var}_column" =>
        sub { $_[0]->check_column_relation( $_[2], 1 ) };
}

=attribute_public prefetch_allows

prefetch_allows limits what relations may be prefetched when executing searches
with joins. This is necessary to avoid denial of service attacks in form of
queries which would return a large number of data and unwanted disclosure of
data.

Like the synopsis in DBIC::API shows, you can declare a "template" of what is
allowed (by using an '*'). Each element passed in, will be converted into a
Data::DPath and added to the validator.

    prefetch_allows => [ 'cds', { cds => tracks }, { cds => producers } ] # to be explicit
    prefetch_allows => [ 'cds', { cds => '*' } ] # wildcard means the same thing

=cut

has 'prefetch_allows' => (
    is        => 'ro',
    writer    => '_set_prefetch_allows',
    isa       => ArrayRef [ ArrayRef | Str | HashRef ],
    default   => sub { [] },
    predicate => 'has_prefetch_allows',
    traits    => ['Array'],
    handles   => { all_prefetch_allows => 'elements', },
);

has 'prefetch_validator' => (
    is         => 'ro',
    isa        => 'Catalyst::Controller::DBIC::API::Validator',
    lazy_build => 1,
);

sub _build_prefetch_validator {
    my $self = shift;

    sub _check_rel {
        my ( $self, $rel, $static, $validator ) = @_;
        if ( ArrayRef->check($rel) ) {
            foreach my $rel_sub (@$rel) {
                _check_rel( $self, $rel_sub, $static, $validator );
            }
        }
        elsif ( HashRef->check($rel) ) {
            while ( my ( $k, $v ) = each %$rel ) {
                $self->check_has_relation( $k, $v, undef, $static );
            }
            $validator->load($rel);
        }
        else {
            $self->check_has_relation( $rel, undef, undef, $static );
            $validator->load($rel);
        }
    }

    my $validator = Catalyst::Controller::DBIC::API::Validator->new;

    foreach my $rel ( $self->all_prefetch_allows ) {
        _check_rel( $self, $rel, 1, $validator );
    }

    return $validator;
}

=attribute_public count_arg

Controls how to reference 'count' in the the request_data, defaults to
'list_count'.

=cut

has 'count_arg' => ( is => 'ro', isa => Str, default => 'list_count' );

=attribute_public page_arg

Controls how to reference 'page' in the the request_data, defaults to
'list_page'.

=cut

has 'page_arg' => ( is => 'ro', isa => Str, default => 'list_page' );

=attribute_public offset_arg

Controls how to reference 'offset' in the the request_data, defaults to
'list_offset'.

=cut

has 'offset_arg' => ( is => 'ro', isa => Str, default => 'list_offset' );

=attribute_public bind_arg

Controls how to reference 'bind' in the request_data, defaults to 'bind'.

=cut

has 'bind_arg' => ( is => 'ro', isa => Str, default => 'bind' );

=attribute_public select_arg

Controls how to reference 'select' in the the request_data, defaults to
'list_returns'.

=cut

has 'select_arg' => ( is => 'ro', isa => Str, default => 'list_returns' );

=attribute_public as_arg

Controls how to reference 'as' in the the request_data, defaults to 'as'.

=cut

has 'as_arg' => ( is => 'ro', isa => Str, default => 'as' );

=attribute_public search_arg

Controls how to reference 'search' in the the request_data, defaults to
'search'.

=cut

has 'search_arg' => ( is => 'ro', isa => Str, default => 'search' );

=attribute_public grouped_by_arg

Controls how to reference 'grouped_by' in the the request_data, defaults to
'list_grouped_by'.

=cut

has 'grouped_by_arg' =>
    ( is => 'ro', isa => Str, default => 'list_grouped_by' );

=attribute_public ordered_by_arg

Controls how to reference 'ordered_by' in the the request_data, defaults to
'list_ordered_by'.

=cut

has 'ordered_by_arg' =>
    ( is => 'ro', isa => Str, default => 'list_ordered_by' );

=attribute_public prefetch_arg

Controls how to reference 'prefetch' in the the request_data, defaults to
'list_prefetch'.

=cut

has 'prefetch_arg' => ( is => 'ro', isa => Str, default => 'list_prefetch' );

=attribute_public stash_key

Controls where in the stash the request_data should be stored, defaults to
'response'.

=cut

has 'stash_key' => ( is => 'ro', isa => Str, default => 'response' );

=attribute_public data_root

Controls how to reference where the data is in the the request_data, defaults to
'list'.

=cut

has 'data_root' => ( is => 'ro', isa => Str, default => 'list' );

=attribute_public item_root

Controls how to reference where the data for single object requests is in the
the request_data, defaults to 'data'.

=cut

has 'item_root' => ( is => 'ro', isa => Str, default => 'data' );

=attribute_public total_entries_arg

Controls how to reference 'total_entries' in the the request_data, defaults to
'totalcount'.

=cut

has 'total_entries_arg' =>
    ( is => 'ro', isa => Str, default => 'totalcount' );

=attribute_public use_json_boolean

Controls whether JSON boolean types are used in the success parameter of the
response or if raw strings are used, defaults to false.

=cut

has 'use_json_boolean' => ( is => 'ro', isa => Bool, default => 0 );

=attribute_public return_object

Controls whether the results of create/update are serialized and returned in
the response, defaults to false.

=cut

has 'return_object' => ( is => 'ro', isa => Bool, default => 0 );

=head1 DESCRIPTION

StaticArguments is a role that is composed by the controller to provide
configuration parameters such as where to find specific elements in the request
data and if to use JSON boolean types.

=cut

1;
