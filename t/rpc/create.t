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

my $artist_create_url     = "$base/api/rpc/artist/create";
my $any_artist_create_url = "$base/api/rpc/any/artist/create";
my $producer_create_url   = "$base/api/rpc/producer/create";

# test validation when no params sent
{
    my $req = POST(
        $artist_create_url,
        { wrong_param => 'value' },
        'Accept' => 'text/json'
    );
    $mech->request( $req, $content_type );
    cmp_ok( $mech->status, '==', 400,
        'attempt without required params caught' );
    my $response = $json->decode( $mech->content );
    like(
        $response->{messages}->[0],
        qr/No value supplied for name and no default/,
        'correct message returned'
    );
}

# test default value used if default value exists
{
    my $req = POST(
        $producer_create_url,
        {

        },
        'Accept' => 'text/json'
    );
    $mech->request( $req, $content_type );
    cmp_ok( $mech->status, '==', 200,
        'default value used when not supplied' );
    ok( $schema->resultset('Producer')->find( { name => 'fred' } ),
        'record created with default name' );
}

# test create works as expected when passing required value
{
    my $req = POST(
        $producer_create_url,
        { name => 'king luke' },
        'Accept' => 'text/json'
    );
    $mech->request( $req, $content_type );
    cmp_ok( $mech->status, '==', 200, 'param value used when supplied' );

    my $new_obj =
        $schema->resultset('Producer')->find( { name => 'king luke' } );
    ok( $new_obj, 'record created with specified name' );

    my $response = $json->decode( $mech->content );
    is_deeply(
        $response->{list},
        { $new_obj->get_columns },
        'json for new producer returned'
    );
}

# test create of single related row
{
    my $test_data = $json->encode(
        { name => 'Futuristic Artist', cds => { 'title' => 'snarky cd name', year => '3030' } }
    );
    my $req = PUT($artist_create_url);
    $req->content_type('text/x-json');
    $req->content_length(
        do { use bytes; length($test_data) }
    );
    $req->content($test_data);
    $mech->request($req);
    cmp_ok( $mech->status, '==', 200, 'request with single related row okay' );
    my $count = $schema->resultset('Artist')
        ->search({ name => 'Futuristic Artist' })
        ->count;
    ok( $count, 'record with related object created' );
    $count = $schema->resultset('Artist')
        ->search_related('cds', { title => 'snarky cd name' })
        ->count;
    ok( $count, "record's related object created" );
}

# test create of multiple related rows
{
    my $test_data = $json->encode(
        { name => 'Futuristic Artist 2',
          cds => [
            { 'title' => 'snarky cd name 2', year => '3030' },
            { 'title' => 'snarky cd name 3', year => '3030' },
          ]
        }
    );

    my $req = PUT($artist_create_url);
    $req->content_type('text/x-json');
    $req->content_length(
        do { use bytes; length($test_data) }
    );
    $req->content($test_data);
    $mech->request($req);
    cmp_ok( $mech->status, '==', 200, 'request with multiple related rows okay' );
    my $count = $schema->resultset('Artist')
        ->search({ name => 'Futuristic Artist 2' })
        ->count;
    ok( $count, 'record with related object created' );
    $count = $schema->resultset('Artist')
        ->search_related('cds', { title => ['snarky cd name 2','snarky cd name 3'] })
        ->count;
    ok( $count == 2, "record's related objects created" ) or explain diag $count;

}

# test stash config handling
{
    my $req = POST(
        $any_artist_create_url,
        { name => 'queen monkey' },
        'Accept' => 'text/json'
    );
    $mech->request( $req, $content_type );
    cmp_ok( $mech->status, '==', 200, 'stashed config okay' );

    my $new_obj =
        $schema->resultset('Artist')->find( { name => 'queen monkey' } );
    ok( $new_obj, 'record created with specified name' );

    my $response = $json->decode( $mech->content );
    is_deeply(
        $response,
        { success => 'true' },
        'json for new artist returned'
    );
}

# test create returns an error as expected when passing invalid value
{
    my $data = {
        producerid => 100,
        name       => 'Producer',
    };

    my $req = POST($producer_create_url, $data, 'Accept' => 'text/json');
    $mech->request( $req, $content_type );
    cmp_ok( $mech->status, '==', 200, 'create with pk value ok' );
    my $response = $json->decode( $mech->content );
    is_deeply(
        $response,
        { success => 'true', list => $data },
        'json for producer with pk value ok'
    );
    # try to insert same data again, as this seems to be the only way to
    # force an insert to fail for SQLite.
    # It accepts too long columns as well as wrong datatypes without errors.
    # The bind with datatype of newer DBIC versions numifies non-integer
    # values passed as pk value too.
    $mech->request( $req, $content_type );
    cmp_ok( $mech->status, '==', 400, 'invalid param value produces error' );
}

# test creating record with multiple related-rows

done_testing();
