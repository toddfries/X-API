package X::API::Trait::NormalizeBooleans;
# ABSTRACT: Normalize Booleans

use 5.14.1;
use Moo::Role;
use namespace::clean;

requires 'preprocess_args';

around preprocess_args => sub {
    my ( $next, $self, $c ) = @_;

    $self->$next($c);
    $self->normalize_bools($c->args);
};

# X usually accepts 1, 't', 'true', or false for booleans, but they
# prefer 'true' or 'false'. In some cases, like include_email, they only accept
# 'true'. So, we normalize these options.
my @normal_bools = qw/
    contributor_details display_coordinates exclude_replies hide_media
    hide_thread hide_tweet include_email include_entities include_my_tweet
    include_rts include_user_entities map omit_script possibly_sensitive
    reverse trim_user
/;

# Workaround X bug: any value passed for these options are treated as
# true.  The only way to get 'false' is to not pass the skip_user at all. So,
# we strip these boolean args if their values are false.
my @true_only_bools = qw/skip_status skip_user/;

my %is_bool = map { $_ => undef } @normal_bools, @true_only_bools;
my %is_true_only_bool = map { $_ => undef } @true_only_bools;

sub is_bool { exists $is_bool{$_[1]} }

sub is_true_only_bool { exists $is_true_only_bool{$_[1]} }

sub normalize_bools {
    my ( $self, $args ) = @_;

    # X prefers 'true' or 'false' (requires it in some cases).
    for my $k ( keys %$args ) {
        next unless $self->is_bool($k);
        $args->{$k} = $args->{$k} ? 'true' : 'false';
        delete $args->{$k} if $self->is_true_only_bool($k)
            && $args->{$k} eq 'false';
    }
}

1;

__END__

=pod

=head1 SYNOPSIS

    use X::API;

    my $client = X::API->new_with_traits(
        traits => [ qw/ApiMethods NormalizeBooleans/ ],
        %other_new_options
    );

    my ( $r, $c ) = $client->home_timeline({ trim_user => 1 });

    say $c->http_request->uri;

    # output:
    https://api.x.com/1.1/statuses/home_timeline.json?trim_user=true

=head1 DESCRIPTION

X has a strange concept of boolean values. Usually, the API accepts C<t>,
C<true>, or C<1> for true. Sometimes it accepts C<f>, C<false>, or C<0> for
false. But then you have strange cases like the C<include_email> parameter used
for authorized applications by the C<verify_credentials> endpoint. It only
accepts C<true>. Worse, for some boolean values, passing C<f>, C<false>, or
C<0> all work as if you passed C<true>. For those values, false means not
including the parameter at all.

So, this trait attempts to normalize booleans by transforming any perl truthy
value to the X API's preference, C<true>. It transforms falsey values to
C<false>. And then it removes false parameters that the API always treats as
true.

You're welcome.
