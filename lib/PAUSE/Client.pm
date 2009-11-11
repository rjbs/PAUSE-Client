package PAUSE::Client;
use Moose;

use namespace::autoclean;

use WWW::Mechanize;
# use WWW::Mechanize::TreeBuilder;

has [ qw(password username) ] => (
  is  => 'ro',
  isa => 'Str',
  required => 1,
);

has mech => (
  is   => 'ro',
  lazy => 1,
  default => sub {
    my ($self) = @_;
    my $mech = WWW::Mechanize->new;
    # WWW::Mechanize::TreeBuilder->meta->apply($mech);
    $mech->credentials($self->username, $self->password);
    return $mech;
  },
);


1;
