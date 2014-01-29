use strict;
use warnings;

use lib 't/lib';

my $base = 'http://localhost';
my $content_type = [ 'Content-Type', 'application/x-www-form-urlencoded' ];

use RestTest;
use DBICTest;
use Test::More;
use Test::WWW::Mechanize::Catalyst 'RestTest';
use HTTP::Request::Common;
use JSON;

my $json = JSON->new->utf8;

my $mech = Test::WWW::Mechanize::Catalyst->new;
ok( my $schema = DBICTest->init_schema(), 'got schema' );

my $track         = $schema->resultset('Track')->first;
my %original_cols = $track->get_columns;

my $track_update_url = "$base/api/rpc/track/id/" . $track->id . "/update";
my $any_track_update_url =
    "$base/api/rpc/any/track/id/" . $track->id . "/update";
my $tracks_update_url = "$base/api/rpc/track/update";

my $artist_update_url = "$base/api/rpc/artist/id/1/update";

# test invalid track id caught
{
    diag 'DBIx::Class warns about a non-numeric id which is ok because we test for that too';
    foreach my $wrong_id ( 'sdsdsdsd', 3434234 ) {
        my $incorrect_url = "$base/api/rpc/track/id/" . $wrong_id . "/update";
        my $req = POST( $incorrect_url, { title => 'value' } );

        $mech->request( $req, $content_type );
        cmp_ok( $mech->status, '==', 400,
            'Attempt with invalid track id caught' );

        my $response = $json->decode( $mech->content );
        like(
            $response->{messages}->[0],
            qr/No object found for id/,
            'correct message returned'
        );

        $track->discard_changes;
        is_deeply(
            { $track->get_columns },
            \%original_cols,
            'no update occurred'
        );
    }
}

# validation when no params sent
{
    my $req = POST( $track_update_url, { wrong_param => 'value' } );
    $mech->request( $req, $content_type );
    cmp_ok( $mech->status, '==', 400, 'Update with no keys causes error' );

    my $response = $json->decode( $mech->content );
    is_deeply( $response->{messages}, ['No valid keys passed'],
        'correct message returned' );

    $track->discard_changes;
    is_deeply(
        { $track->get_columns },
        \%original_cols,
        'no update occurred'
    );
}

{
    my $req = POST( $track_update_url, { wrong_param => 'value' } );
    $mech->request( $req, $content_type );
    cmp_ok( $mech->status, '==', 400, 'Update with no keys causes error' );

    my $response = $json->decode( $mech->content );
    is_deeply( $response->{messages}, ['No valid keys passed'],
        'correct message returned' );

    $track->discard_changes;
    is_deeply(
        { $track->get_columns },
        \%original_cols,
        'no update occurred'
    );
}

{
    my $req = POST( $track_update_url, { title => undef } );
    $mech->request( $req, $content_type );
    cmp_ok( $mech->status, '==', 200, 'Update with key with no value okay' );

    $track->discard_changes;
    isnt( $track->title, $original_cols{title}, 'Title changed' );
    is( $track->title, '', 'Title changed to undef' );
}

{
    my $req = POST( $track_update_url, { title => 'monkey monkey' } );
    $mech->request( $req, $content_type );
    cmp_ok( $mech->status, '==', 200, 'Update with key with value okay' );

    $track->discard_changes;
    is( $track->title, 'monkey monkey', 'Title changed to "monkey monkey"' );
}

{
    my $req = POST(
        $track_update_url,
        {   title     => 'sheep sheep',
            'cd.year' => '2009'
        }
    );
    $mech->request( $req, $content_type );
    cmp_ok( $mech->status, '==', 200,
        'Update with key with value and related key okay' );

    $track->discard_changes;
    is( $track->title,    'sheep sheep', 'Title changed' );
    is( $track->cd->year, '2009',        'Related field changed"' );
}

{
    my $test_data = $json->encode(
        { name => 'Caterwauler B. McCrae',
          cds => [
            {
                cdid => 1,
                title => 'All the bees are gone',
                year => 3030,
            },
            {
                cdid => 2,
                title => 'All the crops are gone',
                year => 3031
            }
          ]
        }
    );

    my $req = POST( $artist_update_url, Content => $test_data );
    $req->content_type('text/x-json');
    $mech->request($req);

    cmp_ok( $mech->status, '==', 200, 'Multi-row update returned 200 OK' );

    my $artist = $schema->resultset('Artist')->search({ artistid => 1 });
    ok ($artist->next->name eq "Caterwauler B. McCrae", "mutliple related row parent record update");

    # make sure the old cds don't exist, it's possible we just inserted the new rows instead of updating them
    my $old_cds = $artist->search_related('cds', { title => ['Spoonful of bees', 'Forkful of bees'] } )->count;
    ok ($old_cds == 0, 'update performed update and not create on related rows');

    my @cds = $artist->search_related('cds', { year => ['3030', '3031'] }, { order_by => 'year' })->all;
    ok (@cds == 2, 'update modified proper number of related rows');
    ok ($cds[0]->title eq 'All the bees are gone', 'update modified column on related row');
    ok ($cds[1]->title eq 'All the crops are gone', 'update modified column on second related row');
}

# update related rows using only unique_constraint on CD vs. primary key
# update the year on constraint match
{
    my $test_data = $json->encode(
        { name => 'Caterwauler McCrae',
          cds => [
            {
                artist => 1,
                title => 'All the bees are gone',
                year => 3032,
            },
            {
                artist => 1,
                title => 'All the crops are gone',
                year => 3032
            }
          ]
        }
    );

    my $req = POST( $artist_update_url, Content => $test_data );
    $req->content_type('text/x-json');
    $mech->request($req);

    cmp_ok( $mech->status, '==', 200, 'Multi-row unique constraint update returned 200 OK' );

    my $artist = $schema->resultset('Artist')->search({ artistid => 1 });
    ok ($artist->next->name eq "Caterwauler McCrae", "multi-row unique constraint related row parent record updated");

    my $old_cds = $artist->search_related('cds', { year => ['3030', '3031'] }, { order_by => 'year' })->count;
    ok ( $old_cds == 0, 'multi-row update with unique constraint updated year' );

    my $cds = $artist->search_related('cds', { 'year' => 3032 } )->count;
    ok ( $cds == 2, 'multi-row update with unique constraint okay' );
}

{
    my $req = POST( $any_track_update_url, { title => 'baa' } );
    $mech->request( $req, $content_type );
    cmp_ok( $mech->status, '==', 200, 'Stash update okay' );

    $track->discard_changes;
    is( $track->title, 'baa', 'Title changed' );
}

{
    my $req = POST( $any_track_update_url, { position => '14' } );
    $mech->request( $req, $content_type );
    cmp_ok( $mech->status, '==', 200, 'Position update okay' );

    $track->discard_changes;
    is( $track->get_column('position'), '14', 'Position changed' );
}


# bulk_update existing objects
{

    # order to get a stable order of rows
    my $tracks_rs =
        $schema->resultset('Track')
        ->search( undef, { order_by => 'trackid', rows => 3 } );
    my $test_data = $json->encode(
        {   list => [
                map +{ id => $_->id, title => 'Track ' . $_->id },
                $tracks_rs->all
            ]
        }
    );
    my $req = POST( $tracks_update_url, Content => $test_data );
    $req->content_type('text/x-json');
    $mech->request($req);
    cmp_ok( $mech->status, '==', 200, 'Attempt to update three tracks ok' );

    $tracks_rs->reset;
    while ( my $track = $tracks_rs->next ) {
        is( $track->title, 'Track ' . $track->id, 'Title changed' );
    }
}

# bulk_update nonexisting objects
{

    # order to get a stable order of rows
    my $test_data = $json->encode(
        {   list => [
                map +{ id => $_, title => 'Track ' . $_ },
                ( 1000 .. 1002 )
            ]
        }
    );
    my $req = POST( $tracks_update_url, Content => $test_data );
    $req->content_type('text/x-json');
    $mech->request($req);
    cmp_ok( $mech->status, '==', 400,
        'Attempt to update three nonexisting tracks fails' );
    my $response = $json->decode( $mech->content );
    is( $response->{success}, 'false',
        'success property returns quoted false' );
    like(
        $response->{messages}->[0],
        qr/No object found for id/,
        'correct message returned'
    );
}

done_testing();
