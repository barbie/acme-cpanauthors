package Acme::CPANAuthors;

use strict;
use warnings;
use Carp;
use Acme::CPANAuthors::Utils qw( cpan_authors cpan_packages );

our $VERSION = '0.09';

sub new {
  my ($class, @categories) = @_;

  @categories = _list_categories() unless @categories;

  my %authors;
  foreach my $category ( @categories ) {
    %authors = ( %authors, _get_authors_of($category) );
  }
  bless \%authors, $class;
}

sub count {
  my $self = shift;

  return scalar keys %{ $self };
}

sub id {
  my ($self, $id) = @_;

  unless ( $id ) {
    return sort keys %{ $self };
  }
  else {
    return $self->{$id} ? 1 : 0;
  }
}

sub name {
  my ($self, $id) = @_;

  unless ( $id ) {
    return sort values %{ $self };
  }
  else {
    return $self->{$id};
  }
}

sub distributions {
  my ($self, $id) = @_;

  return unless $id;

  my @packages;
  foreach my $package ( cpan_packages->distributions ) {
    if ( $package->cpanid eq $id ) {
      push @packages, $package;
    }
  }

  return @packages;
}

sub latest_distributions {
  my ($self, $id) = @_;

  return unless $id;

  my @packages;
  foreach my $package ( cpan_packages->latest_distributions ) {
    if ( $package->cpanid eq $id ) {
      push @packages, $package;
    }
  }

  return @packages;
}

sub avatar_url {
  my ($self, $id, %options) = @_;

  return unless $id;

  require Gravatar::URL;
  my $author = cpan_authors->author($id) or return;

  return Gravatar::URL::gravatar_url( email => $author->email, %options );
}

sub kwalitee {
  my ($self, $id) = @_;

  return unless $id;

  require Acme::CPANAuthors::Utils::Kwalitee;
  return  Acme::CPANAuthors::Utils::Kwalitee->fetch($id);
}

sub look_for {
  my ($self, $id_or_name) = @_;

  return unless defined $id_or_name;
  unless (ref $id_or_name eq 'Regexp') {
    $id_or_name = qr/$id_or_name/i;
  }

  my @found;
  foreach my $category ( _list_categories() ) {
    my %authors = _get_authors_of($category);
    while ( my ($id, $name) = each %authors ) {
      if ($id =~ /$id_or_name/ or $name =~ /$id_or_name/) {
        push @found, {
          id       => $id,
          name     => $name,
          category => $category,
        };
      }
    }
  }
  return @found;
}

sub _list_categories {
  require Module::Find;
  return grep { $_ !~ /^(?:Register|Utils|Not)$/ }
         map  { s/^Acme::CPANAuthors:://; $_ }
         Module::Find::findsubmod( 'Acme::CPANAuthors' );
}

sub _get_authors_of {
  my $category = shift;

  $category =~ s/^Acme::CPANAuthors:://;

  return if $category =~ /^(?:Register|Utils)$/;

  my $package = "Acme::CPANAuthors\::$category";
  eval "require $package";
  if ( $@ ) {
    carp "$category CPAN Authors are not registered yet: $@";
    return;
  }
  $package->authors;
}

1;

__END__

=head1 NAME

Acme::CPANAuthors - We are CPAN authors

=head1 SYNOPSIS

    use Acme::CPANAuthors;

    my $authors = Acme::CPANAuthors->new('Japanese');

    my $number   = $authors->count;
    my @ids      = $authors->id;
    my @distros  = $authors->distributions('ISHIGAKI');
    my $url      = $authors->avatar_url('ISHIGAKI');
    my $kwalitee = $authors->kwalitee('ISHIGAKI');
    my @info     = $authors->look_for('ishigaki');

  If you don't like this interface, just use a specific authors list.

    use Acme::CPANAuthors::Japanese;

    my %authors = Acme::CPANAuthors::Japanese->authors;

    # note that ->author is context sensitive.
    # however, you can't write this without dereference
    # as "keys" checks the type (actually, the number) of args.
    for my $name (keys %{ Acme::CPANAuthors::Japanese->authors }) {
      print Acme::CPANAuthors::Japanese->authors->{$name}, "\n";
    }

=head1 DESCRIPTION

Sometimes we just want to know something to confirm we're not
alone, or to see if we're doing right things, or to look for
someone we can rely on. This module provides you some basic
information on us.

=head1 WHY THIS MODULE?

We've been holding a Kwalitee competition for Japanese CPAN Authors
since 2006. Though Japanese names are rather easy to distinguish
from westerner's names (as our names have lots of vowels), it's
tedious to look for Japanese authors every time we hold the contest.
That's why I wrote this module and started maintaining the Japanese
authors list with a script to look for candidates whose name looks
like Japanese by the help of L<Lingua::JA::Romaji::Valid> I coined.

Since then, dozens of lists are uploaded on CPAN. It may be time
to start other games, like offering more useful statistics online.

=head1 METHODS

=head2 new

creates an object and loads the subclasses you specified.
If you don't specify any subclasses, it tries to load all
the subclasses found just under the "Acme::CPANAuthors"
namespace.

=head2 count

returns how many CPAN authors are registered.

=head2 id

returns all the registered ids by default. If called with an
id, this returns if there's a registered author of the id.

=head2 name

returns all the registered authors' name by default. If called
with an id, this returns the name of the author of the id.

=head2 distributions, latest_distributions

returns an array of Parse::CPAN::Packages::Distribution objects
for the author of the id. See L<Parse::CPAN::Packages> for details.

=head2 avatar_url

returns gravatar url of the id shown at search.cpan.org.
see L<http://site.gravatar.com/site/implement> for details.

=head2 kwalitee

returns kwalitee information for the author of the id.
This information is scraped from http://kwalitee.perl.org/.

=head2 look_for

  my @authors = Acme::CPANAuthors->look_for('SOMEONE');
  foreach my $author (@authors) {
    printf "%s (%s) belongs to %s.\n",
      $author->{id}, $author->{name}, $author->{category};
  }

takes an id or a name (or a part of them, or even a regexp)
and returns an array of hash references, each of which contains
an id, a name, and a basename of the class where the person is
registered. Note that this will load all the installed
Acme::CPANAuthors:: modules but L<Acme::CPANAuthors::Not> and
modules with deeper namespaces.

=head1 SEE ALSO

As of writing this, there're more than a dozen of lists on the CPAN,
including:

=over 4

=item L<Acme::CPANAuthors::Arabic>

=item L<Acme::CPANAuthors::Austrian>

=item L<Acme::CPANAuthors::Brazilian>

=item L<Acme::CPANAuthors::Canadian>

=item L<Acme::CPANAuthors::Chinese>

=item L<Acme::CPANAuthors::French>

=item L<Acme::CPANAuthors::German>

=item L<Acme::CPANAuthors::Icelandic>

=item L<Acme::CPANAuthors::Israeli>

=item L<Acme::CPANAuthors::Italian>

=item L<Acme::CPANAuthors::Japanese>

=item L<Acme::CPANAuthors::Norwegian>

=item L<Acme::CPANAuthors::Portuguese>

=item L<Acme::CPANAuthors::Russian>

=item L<Acme::CPANAuthors::Taiwanese>

=item L<Acme::CPANAuthors::Turkish>

=item L<Acme::CPANAuthors::Ukrainian>

=back

These are not regional ones but for some local groups.

=over 4

=item L<Acme::CPANAuthors::CodeRepos>

=item L<Acme::CPANAuthors::GeekHouse>

=back

These are lists for specific module authors.

=over 4

=item L<Acme::CPANAuthors::AnyEvent>

=item L<Acme::CPANAuthors::POE>

=item L<Acme::CPANAuthors::Acme::CPANAuthors::Authors>

=back

And other stuff.

=over 4

=item L<Acme::CPANAuthors::Misanthrope>

=item L<Acme::CPANAuthors::Not>

=item L<Acme::CPANAuthors::You::re_using>

=back

Thank you all. And I hope more to come.

=head1 AUTHOR

Kenichi Ishigaki, E<lt>ishigaki at cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007-2009 by Kenichi Ishigaki.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
