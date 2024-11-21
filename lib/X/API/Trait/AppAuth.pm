package X::API::Trait::AppAuth;
# ABSTRACT: App-only (OAuth2) Authentication

use Moo::Role;
use Carp;
use URL::Encode qw/url_encode url_decode/;
use namespace::clean;

requires qw/
    _url_for access_token add_authorization api_url consumer_key
    consumer_secret request
/;

# private methods

sub oauth2_url_for {
    my $me = shift;

    $me->_url_for('', $me->api_url, 'oauth2', @_);
}

my $add_consumer_auth_header = sub {
    my ( $me, $req ) = @_;

    $req->headers->authorization_basic(
        $me->consumer_key, $me->consumer_secret);
};

# public methods

=method oauth2_token

Call the C<oauth2/token> endpoint to get a bearer token. The token is not
stored in X::API's state. If you want that, set the C<access_token>
attribute with the returned token.

See L<https://developer.x.com/en/docs/basics/authentication/api-reference/token> for details.

=cut

sub oauth2_token {
    my $me = shift;

    my ( $r, $c ) = $me->request(post => $me->oauth2_url_for('token'), {
        -add_consumer_auth_header => 1,
        grant_type => 'client_credentials',
    });

    # In their wisdom, X sends us a URL encoded token. We need to decode
    # it, so if/when we call invalidate_token, and properly URL encode our
    # parameters, we don't end up with a double-encoded token.
    my $token = url_decode $$r{access_token};
    return wantarray ? ( $token, $c ) : $token;
}

=method invalidate_token($token)

Calls the C<oauth2/invalidate_token> endpoint to revoke a token. See
L<https://developer.x.com/en/docs/basics/authentication/api-reference/invalidate_token> for
details.

=cut

sub invalidate_token {
    my ( $me, $token ) = @_;

    my ( $r, $c ) = $me->request(
        post =>$me->oauth2_url_for('invalidate_token'), {
            -add_consumer_auth_header => 1,
            access_token              => $token,
    });
    my $token_returned = url_decode $$r{access_token};
    return wantarray ? ( $token_returned, $c ) : $token_returned;
}

# request chain modifiers

around add_authorization => sub {
    shift; # we're overriding the base, so we won't call it
    my ( $me, $c ) = @_;

    my $req = $c->http_request;
    if ( $c->get_option('add_consumer_auth_header') ) {
        $me->$add_consumer_auth_header($req);
    }
    else {
        my $token = $c->get_option('token') // $me->access_token // return;
        $req->header(authorization => join ' ', Bearer => url_encode($token));
    }
};

1;

__END__

=pod

=head1 SYNOPSIS

    use X::API;
    my $client = X::API->new_with_traits(
        traits => [ qw/ApiMethods AppAuth/ ]);

    my $r = $client->oauth2_token;
    # return value is hash ref:
    # { token_type => 'bearer', access_token => 'AA...' }
    my $token = $r->{access_token};

    # you can use the token explicitly with the -token argument:
    my $user = $client->show_user('X_api', { -token => $token });

    # or you can set the access_token attribute to use it implicitly
    $client->access_token($token);
    my $user = $client->show_user('twitterapi');

    # to revoke a token
    $client->invalidate_token($token);

    # if you revoke the token stored in the access_token attribute, clear it:
    $client->clear_access_token;

=cut
