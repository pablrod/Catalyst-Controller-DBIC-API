package Catalyst::Controller::DBIC::API::Request::Context;

#ABSTRACT: Provides additional context to the Request
use Moose::Role;
use MooseX::Types::Moose(':all');
use MooseX::Types::Structured('Tuple');
use Catalyst::Controller::DBIC::API::Types(':all');
use namespace::autoclean;

=attribute_public objects

This attribute stores the objects found/created at the object action.
It handles the following methods:

    all_objects   => 'elements'
    add_object    => 'push'
    count_objects => 'count'
    has_objects   => 'count'
    clear_objects => 'clear'

=cut

has objects => (
    is     => 'ro',
    isa    => ArrayRef[Tuple[Object,Maybe[HashRef]]],
    traits => ['Array'],
    default => sub { [] },
    handles => {
        all_objects   => 'elements',
        add_object    => 'push',
        count_objects => 'count',
        has_objects   => 'count',
        clear_objects => 'clear',
        get_object    => 'get',
    },
);

=attribute_public current_result_set

Stores the current ResultSet derived from the initial
L<Catalyst::Controller::DBIC::API::StoredResultSource/stored_model>.

=cut

has current_result_set => (
    is     => 'ro',
    isa    => ResultSet,
    writer => '_set_current_result_set',
);

1;
