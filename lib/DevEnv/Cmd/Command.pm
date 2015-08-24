package DevEnv::Cmd::Command;
use Moose;

extends 'MooseX::App::Cmd::Command';

has 'verbose' => (
	traits        => [ "Getopt" ],
	isa           => 'Bool',
	is            => 'rw',
	cmd_aliases   => 'v',
);

sub execute {

	my $self = shift;
	my $opts = shift;
	my $args = shift;
}

__PACKAGE__->meta->make_immutable;

1;
