package X::API::Error;
# ABSTRACT: X API exception

use Moo;
use Ref::Util qw/is_arrayref is_hashref/;
use Try::Tiny;
use namespace::clean;

use overload '""' => sub { shift->error };

with qw/Throwable StackTrace::Auto/;

=method http_request

Returns the L<HTTP::Request> object used to make the X API call.

=method http_response

Returns the L<HTTP::Response> object for the API call.

=method X_error

Returns the inflated JSON error response from X (if any).

=cut

has context => (
    is       => 'ro',
    required => 1,
    handles  => {
        http_request  => 'http_request',
        http_response => 'http_response',
        X_error => 'result',
    },
);

=method stack_trace

Returns a L<Devel::StackTrace> object encapsulating the call stack so you can discover, where, in your application the error occurred.

=method stack_frame

Delegates to C<< stack_trace->frame >>. See L<Devel::StackTrace> for details.

=method next_stack_fram

Delegates to C<< stack_trace->next_frame >>. See L<Devel::StackTrace> for details.

=cut

has '+stack_trace' => (
    handles => {
        stack_frame      => 'frame',
        next_stack_frame => 'next_frame',
    },
);

=method error

Returns a reasonable string representation of the exception. If X
returned error information in the form of a JSON body, it is mined for error
text. Otherwise, the HTTP response status line is used. The stack frame is
mined for the point in your application where the request initiated and
appended to the message.

When used in a string context, C<error> is called to stringify exception.

=cut

has error => (
    is => 'lazy',
);

sub _build_error {
    my $self = shift;

    my $error = $self->X_error_text || $self->http_response->status_line;
    my ( $location ) = $self->stack_frame(0)->as_string =~ /( at .*)/;
    return $error . ($location || '');
}

sub X_error_text {
    my $self = shift;
    # X does not return a consistent error structure, so we have to
    # try each known (or guessed) variant to find a suitable message...

    return '' unless $self->X_error;
    my $e = $self->X_error;

    return is_hashref($e) && (
        # the newest variant: array of errors
        exists $e->{errors}
            && is_arrayref($e->{errors})
            && exists $e->{errors}[0]
            && is_hashref($e->{errors}[0])
            && exists $e->{errors}[0]{message}
            && $e->{errors}[0]{message}

        # it's single error variant
        || exists $e->{error}
            && is_hashref($e->{error})
            && exists $e->{error}{message}
            && $e->{error}{message}

        # the original error structure (still applies to some endpoints)
        || exists $e->{error} && $e->{error}

        # or maybe it's not that deep (documentation would be helpful, here,
        # X!)
        || exists $e->{message} && $e->{message}
    ) || ''; # punt
}

=method X_error_code

Returns the numeric error code returned by X, or 0 if there is none. See
L<https://developer.x.com/en/docs/basics/response-codes> for details.

=cut

sub X_error_code {
    my $self = shift;

    for ( $self->X_error ) {
        return is_hashref($_)
            && exists $_->{errors}
            && exists $_->{errors}[0]
            && exists $_->{errors}[0]{code}
            && $_->{errors}[0]{code}
            || 0;
    }
}

=method is_token_error

Returns true if the error represents a problem with the access token or its
X account, rather than with the resource being accessed.

Some X error codes indicate a problem with authentication or the
token/secret used to make the API call. For example, the account has been
suspended or access to the application revoked by the user. Other error codes
indicate a problem with the resource requested. For example, the target account
no longer exists.

is_token_error returns true for the following X API errors:

=for :list
* 32: Could not authenticate you
* 64: Your account is suspended and is not permitted to access this feature
* 88: Rate limit exceeded
* 89: Invalid or expired token
* 99: Unable to verify your credentials.
* 135: Could not authenticate you
* 136: You have been blocked from viewing this user's profile.
* 215: Bad authentication data
* 226: This request looks like it might be automated. To protect our users from
  spam and other malicious activity, we can’t complete this action right now.
* 326: To protect our users from spam…

For error 215, X's API documentation says, "Typically sent with 1.1
responses with HTTP code 400. The method requires authentication but it was not
presented or was wholly invalid." In practice, though, this error seems to be
spurious, and often succeeds if retried, even with the same tokens.

The X API documentation describes error code 226, but in practice, they
use code 326 instead, so we check for both. This error code means the account
the tokens belong to has been locked for spam like activity and can't be used
by the API until the user takes action to unlock their account.

See X's L<Error Codes &
Responses|https://dev.x.com/overview/api/response-codes> documentation
for more information.

=cut

use constant TOKEN_ERRORS => (32, 64, 88, 89, 99, 135, 136, 215, 226, 326);
my %token_errors = map +($_ => undef), TOKEN_ERRORS;

sub is_token_error {
    exists $token_errors{shift->X_error_code};
}

=method http_response_code

Delegates to C<< http_response->code >>. Returns the HTTP status code of the
response.

=cut

sub http_response_code { shift->http_response->code }

=method is_pemanent_error

Returns true for HTTP status codes representing an error and with values less
than 500. Typically, retrying an API call with one of these statuses right away
will simply result in the same error, again.

=cut

sub is_permanent_error { shift->http_response_code < 500 }

=method is_temporary_error

Returns true or HTTP status codes of 500 or greater. Often, these errors
indicate a transient condition. Retrying the API call right away may result in
success. See the L<RetryOnError|X::API::Trait::RetryOnError> for
automatically retrying temporary errors.

=cut

sub is_temporary_error { !shift->is_permanent_error }

1;

__END__

=pod

=head1 SYNOPSIS

    use Try::Tiny;
    use X::API;
    use X::API::Util 'is_X_api_error';

    my $client = X::API->new(%options);

    try {
        my $r = $client->get('account/verify_credentials');
    }
    catch {
        die $_ unless is_X_api_error($_);

        warn "X says: ", $_->X_error_text;
    };

=head1 DESCRIPTION

X::API dies, throwing a X::API::Error exception when it receives an
error. The error object contains information about the error so your code can
decide how to respond to various error conditions.

=cut
