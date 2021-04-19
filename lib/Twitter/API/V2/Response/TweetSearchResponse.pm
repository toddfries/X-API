package Twitter::API::V2::Response::TweetSearchResponse;
use Moo;
use Sub::Quote;

# Same as GenericTweetsTimelineResponse but without previous_token

use namespace::clean;

extends 'Twitter::API::V2::Tweet::Array';

has meta => (
    is => 'ro',
    isa => quote_sub(q{
        die 'is not a HASH' unless ref $_[0] eq 'HASH';
    }),
    required => 1,
);

has errors => (
    is => 'ro',
    isa => quote_sub(q{
        die 'is not a ARRAY' unless ref $_[0] eq 'ARRAY';
    }),
);

__PACKAGE__->_mk_deep_accessor(qw/meta/, $_) for qw/
    next_token
    newest_id
    oldest_id
    result_count
/;

1;