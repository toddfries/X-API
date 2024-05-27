package X::API::Trait::Enchilada;
# ABSTRACT: Sometimes you want the whole enchilada

use Moo::Role;
use namespace::clean;

# because you usually want the whole enchilada

my $namespace = __PACKAGE__ =~ s/\w+$//r;
with map join('', $namespace, $_), qw/
    ApiMethods
    NormalizeBooleans
    RetryOnError
    DecodeHtmlEntities
/;

1;

__END__

=pod

=head1 SYNOPSIS

    use X::API;

    my $client = X::API->new_with_traits(
        traits => 'Enchilada',
        %other_new_options
    );

=head1 DESCRIPTION

This is just a shortcut for applying commonly used traits. Because, sometimes, you just want the whole enchilada.

This role simply bundles the following traits. See those modules for details.

=for :list
* L<ApiMethods|X::API::Trait::ApiMethods>
* L<NormalizeBooleans|X::API::Trait::NormalizeBooleans>
* L<RetryOnError|X::API::Trait::RetryOnError>
* L<DecodeHtmlEntites|X::API::Trait::DecodeHtmlEntities>

=cut
