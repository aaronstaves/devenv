package DevEnv::Cmd::Command::Package;
use Moose;

# ABSTRACT: Docker Control

use DevEnv::VM;

extends 'DevEnv::Cmd::Command';

has 'config_file' => (
    traits        => [ "Getopt" ],
    isa           => 'Str',
    is            => 'rw',
	cmd_aliases   => 'c',
	required      => 1,
);

has 'instance' => (
    traits        => [ "Getopt" ],
    isa           => 'Str',
    is            => 'rw',
	cmd_aliases   => 'i',
	documentation => "Give the instance a different name",
	default       => "dockit"
);

after 'execute' => sub {

	my $self = shift;
	my $opts = shift;
	my $args = shift;

};

__PACKAGE__->meta->make_immutable;

1;
