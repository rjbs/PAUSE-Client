#!/usr/local/bin/perl
use 5.010;
use strict;
use warnings;
use lib 'lib';

use Carp;
use CPAN::DistnameInfo;
use File::Spec;

use PAUSE::Client;

my $home = $ENV{HOME} || '.';
my $rc   = File::Spec->catfile($home, '.pause');

# Process .pause
open my $pauserc, '<', $rc or die "can't open $rc for reading: $!";

my %arg;

while (<$pauserc>) {
  chomp;
  next unless $_ and $_ !~ /^\s*#/;

  my ($k, $v) = /^\s*(\w+)\s+(.+)$/;
  croak "multiple enties for $k" if $arg{$k};
  $arg{$k} = $v;
}

my $client = PAUSE::Client->new({
  username => $arg{user},
  password => $arg{password},
});

my $res = $client->mech->get(
  q{https://pause.perl.org/pause/authenquery?ACTION=delete_files}
);

my $form = $client->mech->look_down(_tag => 'form');
my @checkboxes = $form->look_down(_tag => 'input', type => 'checkbox');

my %found;

BOX: for my $box (@checkboxes) {
  my $value = $box->attr('value');
  next BOX if $value eq 'CHECKSUMS';

  my $path = sprintf "authors/id/%s/%s/%s/%s",
    substr($client->username, 0, 1),
    substr($client->username, 0, 2),
    $client->username,
    $value;

  my $dni;

  if ($value =~ m{\.(readme|meta)\z}) {
    my $ext = $1;
    (my $fake = $path) =~ s{\.$1\z}{.tar.gz};

    $dni = CPAN::DistnameInfo->new($fake);
  } else {
    $dni = CPAN::DistnameInfo->new($path);

    unless (defined $dni->extension) {
      warn "ignoring unknown path type: $path";
      next BOX;
    }
  }

  my $by_name = $found{ $dni->dist } ||= {};
  my $dist = $by_name->{ $dni->version } ||= { values => [] };
  push @{ $dist->{values} }, $value;
}

use YAML::XS;
print Dump(\%found);
# Tree-File-0.110.meta
# Tree-File-0.110.readme
# Tree-File-0.110.tar.gz

