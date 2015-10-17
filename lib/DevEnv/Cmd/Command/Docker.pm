package DevEnv::Cmd::Command::Docker;
use Moose;

# ABSTRACT: Docker Control

use DevEnv::Docker;
use DevEnv::Exceptions;

use Data::Dumper;

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

has 'status' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	documentation => "Display Status"
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

has 'container' => (
    traits        => [ "Getopt" ],
    isa           => 'ArrayRef[Str]',
    is            => 'rw',
	cmd_aliases   => 'C',
	documentation => "Tag"
);

has 'port_offset' => (
    traits        => [ "Getopt" ],
    isa           => 'Int',
    is            => 'rw',
	cmd_aliases   => 'o',
	documentation => "Source port offset, default 0",
	default       => sub {
		return $ENV{DEVENV_PORT_OFFSET} // 0
	}
);

has 'match_user' => (
	traits        => [ "Getopt" ],
	isa           => 'Bool',
	is            => 'rw',
	documentation => "Match user/group id of current user"
);

has 'use_home' => (
	traits        => [ "Getopt" ],
	isa           => 'Bool',
	is            => 'rw',
	documentation => "r"
);

after 'execute' => sub {

	my $self = shift;
	my $opts = shift;
	my $args = shift;

	my %params = (
		project_config_file => $self->config_file,
		instance_name       => $self->instance,
		port_offset         => $self->port_offset,
		verbose             => $self->verbose
	);
	if ( $self->match_user ) {
		$params{user_id}  = $<;
		$params{group_id} = $);
	}
	if ( $self->use_home ) {

		if ( not $ENV{DEVENV_VAGRANT} ) {

			$params{home_dir} = $ENV{HOME};
		}
		else {
			print STDERR "NOTE: Using a VM, cannot use the HOME directory of the current user\n";
		}
	}

	my $docker = DevEnv::Docker->new( %params );

	if ( $self->start ) {

		$docker->start(
			command     => $self->command,
			start_until => $self->start_until,
			foreground  => $self->foreground,
			command     => $self->command,
			containers  => $self->container
		);
	}
	elsif ( $self->stop ) {

		$docker->stop();
	}
	elsif ( $self->remove ) {

		$docker->remove( force => $self->force );
	}
	elsif ( $self->status ) {

		my $status = $docker->status();

print STDERR Dumper( $status );

	}
	else {
		DevEnv::Exception->throw( "No command, doing nothing." );
	}
};

__PACKAGE__->meta->make_immutable;

1;
