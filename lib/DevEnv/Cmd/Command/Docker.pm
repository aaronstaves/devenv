package DevEnv::Cmd::Command::Docker;
use Moose;

# ABSTRACT: Docker Control

use DevEnv::Docker;

extends 'DevEnv::Cmd::Command';

has 'start' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	documentation => "Start the containers based on config"
);

has 'stop' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	documentation => "Stop the running containers"
);

has 'remove' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	documentation => "Remove the containers"
);

has 'config' => (
    traits        => [ "Getopt" ],
    isa           => 'Str',
    is            => 'rw',
	cmd_aliases   => 'c',
	required      => 1,
);

has 'config_dir' => (
    traits        => [ "Getopt" ],
    isa           => 'Str',
    is            => 'rw',
	cmd_aliases   => 'd',
	lazy          => 1,
	builder       => sub {
		return $ENV{DEVENV_CONFIG_DIR} // $ENV{PWD}
	}
);

has 'instance' => (
    traits        => [ "Getopt" ],
    isa           => 'Str',
    is            => 'rw',
	cmd_aliases   => 'i',
	documentation => "Give the instance a different name"
);

has 'force' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	cmd_aliases   => 'F',
	documentation => "Force removal of all containers"
);

has 'command' => (
    traits        => [ "Getopt" ],
    isa           => 'Str',
    is            => 'rw',
	cmd_aliases   => 'cmd',
	documentation => "Command to run"
);

has 'start_until' => (
    traits        => [ "Getopt" ],
    isa           => 'Str',
    is            => 'rw',
	cmd_aliases   => 'until',
	documentation => "Start containers until specififed containter"
);

after 'execute' => sub {

	my $self = shift;
	my $opts = shift;
	my $args = shift;

	my $docker = DevEnv::Docker->new(
		config_dir => $self->config_dir,
		config     => $self->config,
		instance   => $self->instance,
		verbosity  => $self->verbosity
	);

	if ( $self->start ) {

		$docker->start(
			command     => $self->command,
			start_until => $self->start_until
		);
	}
	elsif ( $self->stop ) {

		$docker->stop();
	}
	elsif ( $self->remove ) {

		$docker->remove( force => $self->force );
	}
	else {
	}
}

__PACKAGE__->meta->make_immutable;

1;
