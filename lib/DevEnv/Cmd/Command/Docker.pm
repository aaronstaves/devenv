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

has 'config_file' => (
    traits        => [ "Getopt" ],
    isa           => 'Str',
    is            => 'rw',
	cmd_aliases   => 'c',
	default       => sub {
		return $ENV{DEVENV_CONFIG_FILE};
	}
);

has 'instance' => (
    traits        => [ "Getopt" ],
    isa           => 'Str',
    is            => 'rw',
	cmd_aliases   => 'i',
	documentation => "Give the instance a different name",
	default       => sub {
		return $ENV{DEVENV_NAME};
	}
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

has 'foreground' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	cmd_aliases   => 'F',
	documentation => "Start last container in the foreground"
);

has 'tag' => (
    traits        => [ "Getopt" ],
    isa           => 'ArrayRef[Str]',
    is            => 'rw',
	cmd_aliases   => 't',
	documentation => "Tag"
);

after 'execute' => sub {

	my $self = shift;
	my $opts = shift;
	my $args = shift;

	my $docker = DevEnv::Docker->new(
		config_file   => $self->config_file,
		instance_name => $self->instance,
		verbose       => $self->verbose
	);

	if ( $self->start ) {

		$docker->start(
			command     => $self->command,
			start_until => $self->start_until,
			foreground  => $self->foreground,
			command     => $self->command,
			tags        => $self->tag
		);
	}
	elsif ( $self->stop ) {

		$docker->stop();
	}
	elsif ( $self->remove ) {

		$docker->remove( force => $self->force );
	}
	else {
		die "No command, doing nothing :(";
	}
};

__PACKAGE__->meta->make_immutable;

1;
