use 5.6.0;

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

my $mech = Test::WWW::Mechanize::Catalyst->new;
ok(my $schema = DBICTest->init_schema(), 'got schema');

my $track = $schema->resultset('Track')->first;
my %original_cols = $track->get_columns;

my $track_delete_url = "$base/api/rpc/track/id/" . $track->id . "/delete";

{
  my $req = POST( $track_delete_url, {

  });
  $mech->request($req, $content_type);
  cmp_ok( $mech->status, '==', 200, 'Attempt to delete track ok' );

  my $deleted_track = $schema->resultset('Track')->find($track->id);
  is($deleted_track, undef, 'track deleted');
}

{
  my $req = POST( $track_delete_url, {

  });
  $mech->request($req, $content_type);
  cmp_ok( $mech->status, '==', 400, 'Attempt to delete again caught' );
}

done_testing();