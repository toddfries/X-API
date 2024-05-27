package X::API::Trait::Migration;
# ABSTRACT: Migration support Net::X/::Lite users

use 5.14.1;
use Carp;
use Moo::Role;
use Ref::Util qw/is_ref/;
use namespace::clean;

has [ qw/request_token request_token_secret/ ] => (
    is        => 'rw',
    predicate => 1,
    clearer   => 1,
);

has wrap_result => (
    is      => 'ro',
    default => sub { 0 },
);

around request => sub {
    my ( $next, $self ) = splice @_, 0, 2;

    my ( $r, $c ) = $self->$next(@_);

    # Early exit? Actually just a context object; return it.
    return $r unless defined $c;

    # Net::X/::Lite migraton support
    if ( $self->wrap_result ) {
        unless ( $ENV{TWITTER_API_NO_MIGRATION_WARNINGS} ) {
            carp 'wrap_result is enabled. It will be removed in a future '
                .'version. See X::API::Trait::Migration';
        }
        return $c;
    }

    return wantarray ? ( $c->result, $c ) : $c->result;
};

sub ua { shift->user_agent(@_) }

sub _get_auth_url {
    my ( $self, $endpoint ) = splice @_, 0, 2;
    my %args = @_ == 1 && is_ref($_[0]) ? %{ $_[0] } : @_;

    my $callback = delete $args{callback} // 'oob';
    my ( $r, $c ) = $self->oauth_request_token(callback => $callback);
    $self->request_token($$r{oauth_token});
    $self->request_token_secret($$r{oauth_token_secret});

    my $uri = $self->_auth_url($endpoint,
        oauth_token => $$r{oauth_token},
        %args
    );
    return wantarray ? ( $uri, $c ) : $uri;
}

sub get_authentication_url { shift->_get_auth_url(authenticate => @_) }
sub get_authorization_url  { shift->_get_auth_url(authorize    => @_) }

sub request_access_token {
    my ( $self, %params ) = @_;

    # request_access_token is defined in both Net::X's OAuth and AppAuth
    # traits. We need to know which one to call, here.
    if ( $self->does('X::API::Trait::AppAuth') ) {
        return $self->access_token($self->oauth2_token(@_));
    }

    my ( $r, $c ) = $self->oauth_access_token({
        token        => $self->request_token,
        token_secret => $self->request_token_secret,
        %params, # verifier => $verifier
    });

    # Net::X stores access tokens in the client instance
    $self->access_token($$r{oauth_token});
    $self->access_token_secret($$r{oauth_token_secret});
    $self->clear_request_token;
    $self->clear_request_token_secret;

    return (
        @{$r}{qw/oauth_token oauth_token_secret user_id screen_name/},
        $c,
    );
}

for my $method ( qw/
    get_authentication_url
    get_authorization_url
    request_access_token
    ua
/) {
    around $method => sub {
        my ( $next, $self ) = splice @_, 0, 2;

        unless ( $ENV{TWITTER_API_NO_MIGRATION_WARNINGS} ) {
            carp $method.' will be removed in a future release. '
                .'Please see X::API::Trait::Migration';
        }
        $self->$next(@_);
    };
}

1;

__END__

=pod

=head1 DESCRIPTION

X::API is a rewrite of L<Net::X>. It's leaner, lighter, and
has faster—fewer dependencies, and less baggage. This trait helps Net::X and
Net::X::Lite users migrate to X::API by providing Net::X
compatible behavior where possible and warning politely where code should be
changed.

=head1 Migrating from Net::X

X::API requires a minimum perl version of 5.14.1. Make sure you have that.

Just change your constructor call:

	my $client = Net::X->new(
		traits => [ qw/API::RESTv1_1 OAuth RetryOnError/ ],
		consumer_key        => $key,
		consumer_secret     => $secret,
		access_token        => $token,
		access_token_secret => $token_secret,
	);

Becomes:

	my $client = X::API->new_with_traits(
		traits => [ qw/Migration ApiMethods RetryOnError/ ],
		consumer_key        => $key,
		consumer_secret     => $secret,
		access_token        => $token,
		access_token_secret => $token_secret,
	);

Differences:

=for :list
* replace C<new> with C<new_with_traits>
* replace trait C<API::RESTv1_1> with C<ApiMethods>
* drop trait C<OAuth>, X::API's core includes it
* add the Migration trait so X::API will handle oauth key management in a
  Net::X compatible way and warn

=head2 Traits

X::API supports the following traits:

=for :list
* L<ApiMethods|X::API::Trait::ApiMethods>
* L<AppAuth|X::API::Trait::AppAuth>
* L<DecodeHtmlEntities|X::API::Trait::DecodeHtmlEntities>
* L<NormalizeBooleans|X::API::Trait::NormalizeBooleans>
* L<RetryOnError|X::API::Trait::RetryOnError>
* L<Enchilada|X::API::Trait::Enchilada>

B<ApiMethods >is a direct replacement for Net::X's API::RESTv1_1 trait.

Net::X's B<InflateObjects> trait will be released as a separate distribution
to minimize X::API's dependencies.

If you are using the Net::X's B<WrapResults> trait, X::API provides
a better way to access the what it provides. In list context, API calls return
both the API call results and a L<X::API::Context> object that provides
the same accessors and attributes B<WrapResult> provided, including the
B<result> accessor.

So, if you had:

    my $r = $client->home_timeline;
    $r->result;
    $r->rate_limit_remaining;

You can change that to:

    my ( $result, $context ) = $client->home_timeline;
    $result;
    $context->rate_limit_remaining;

Or for the smallest change to your code:

    my ( undef, $r ) = $client->home_timeline;
    $r->result; i            # same as before
    $r->rate_limit_remaning; # same as before

However, there is migration support for B<WrapResult>. Call the constructor
with option C<< wrap_result => 1 >> and X::API will return the context
object, only, for API calls. This should give you the same behavior you had
with B<WrapResult> while you modify your code. X::API will warn when this
option is used. You may disale warnings with
C<$ENV{TWITTER_API_NO_MIGRATION_WARNINGS} = 1>.

If you are using any other Net::X traits, please contact the author of
X::API.  Additional traits may be added to X::API or released as
separate distributions.

If you are using C<< decode_html_entities => 1 >> in Net::X, drop that
option and add trait B<DecodeHtmlEntities>. Traits B<AppAuth> and
B<RetryOnError> provide the same functionality in X::API as their
Net::X counterparts. So, no changes required, there, if you're using
them. (Although there is a change to one of B<AppAuth>'s methods. See the
L</"OAuth changes"> discussion.)

NormalizeBooleans is something you'll probably want. See the
L<NormalizeBooleans|X::API::Trait::NormalizeBooleans> documentation.

Enchilda just bundles ApiMethods, NormalizeBooleans, RetryOnError, and
DecodeHtmlEntities.

=head2 Other constructor options

Drop option C<< ssl => 1 >>. It is no longer necessary. By default, all
connections use SSL.

If you are setting B<useragent_lass> and/or B<useragent_args> to customize the
user agent, just construct your own pass it to new with C<< user_agent =>
$custom_user_agent >>.

If you are using B<ua> to set a custom user agent, the attribute name has
changed to B<usre_agent>. So, pass it to new with C<< user_agent =>
$custom_user_agent >>.

By default, X::API uses L<HTTP::Thin> as its user agent. You should be
able to use any user agent you like, as long as it has a B<request> method that
takes an L<HTTP::Request> and returns an L<HTTP::Response>.

If you used B<clientname>, B<clientver>, B<clienturl>, or B<useragent>, see
L<X::API/agent> and L<X::API/default_headers>. If all you're after
is a custom User-Agent header, just pass C<< agent => $user_agent_string >>.
It will be used for both User-Agent header and the X-X-Client header on
requests. If you want to include your own application version and url, pass
C<< default_headers => \%my_request_headers >>.

=head2 OAuth changes

Net::X saved request and access tokens in the client instance as part of
the 3-legged OAuth handshake. That was a poor design decision. X::API
returns request and access tokens to the caller. It is the caller's
responsibility to store and cache them appropriately. Hovever, transitional
support is provided, with client instance storage, so your code can run
unmodified while you make the transition.

The following methods exist only for migration from Net::X and will be
removed in a future release. A warning is issued on each call to these methods.
To disable the warnings, set C<$ENV{TWITTER_API_NO_MIGRATION_WARNINGS} = 1>.

=for :list
* B<get_authentication_url>
replace with L<oauth_authentication_url|X::API/oauth_athentication_url>
  or L<oauth_request_token|X::API/oauth_request_token> and
  L<oauth_authentication_url|X::API/oauth_athentication_url>
* B<get_authorization_url>
replace with L<oauth_authorization_url|X::API/oauth_authorization_url> or
  L<oauth_request_token|X::API/oauth_request_token> and
  L<oauth_authorization_url|X::API/oauth_authorization_url>
* B<get_access_token>
replace with L<oauth_access_token|X::API/oauth_access_token>

If you are using the B<AppAuth> trait, replace B<request_access_token> calls
with B<oauth2_token> calls. Method B<oauth2_token> does not set the
C<access_token> attribute. Method C<request_access_token> is provided for
transitional support, only. It warns like the OAuth methods discussed above, and
it sets the C<access_token> attribute so existing code should work as expected
during migration. It will be removed in a future release.

=head1 Migrating from Net::X::Lite

The discussion, above applies for L<Net::X::Lite> with a few exceptions.

Net::X::Lite does not use traits. Change your constructor call from:

    my $client = Net::X::Lite::WithAPIv1_1->new(%args);

To:

    my $client = X::API->new_with_traits(
        traits => [ qw/Migration ApiMethods/ ],
        %args,
    );

If you're using the option B<wrap_result>, see the discussion above about the
Net::X WrapResult trait. There is migration support for B<wrap_result>.
It will be removed in a future release.

=cut
