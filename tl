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

my @files = grep { defined }
            map  { $_->possible_values }
            grep { $_->type eq 'checkbox' }
            $client->mech->form_number(1)->inputs;

my %found;

FILE: for my $file (@files) {
  next FILE if $file eq 'CHECKSUMS';

  my $path = sprintf "authors/id/%s/%s/%s/%s",
    substr($client->username, 0, 1),
    substr($client->username, 0, 2),
    $client->username,
    $file;

  my $dni;

  if ($file =~ m{\.(readme|meta)\z}) {
    my $ext = $1;
    (my $fake = $path) =~ s{\.$1\z}{.tar.gz};

    $dni = CPAN::DistnameInfo->new($fake);
  } else {
    $dni = CPAN::DistnameInfo->new($path);

    unless (defined $dni->extension) {
      warn "ignoring unknown path type: $path";
      next FILE;
    }
  }

  next if $dni->dist eq 'perl';

  my $by_name = $found{ $dni->dist } ||= {};
  my $dist = $by_name->{ eval $dni->version } ||= { values => [] };
  push @{ $dist->{values} }, $file;
}

use YAML::XS;

$client->mech->form_number(1);

my %ticked;

for my $key (sort keys %found) {
  my $dist = $found{ $key };
  next unless keys %$dist > 3;

  my @versions = sort { $b <=> $a } keys %$dist;
  for my $version (map { $versions[$_] } 3 .. $#versions) {
    for my $file (@{ $dist->{ $version }{values} }) {
      print "scheduling $file for deletion\n";
      $ticked{ $file } ++;
    }
  }
}

print "ticked ", scalar keys %ticked, " tickey boxes\n";

for my $input (
  $client->mech->find_all_inputs(name => 'pause99_delete_files_FILE')
) {
  for my $val ($input->possible_values) {
    next if !defined $val || !$ticked{$val};
    $input->value(1);
    last;
  }
}

$client->mech->click('SUBMIT_pause99_delete_files_delete');
print $client->mech->content;
