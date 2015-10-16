package DevEnv::Cmd::Command::Web;
use Moose;

# ABSTRACT: Web Control Panel

use DevEnv;
use DevEnv::Web;
use DevEnv::Exceptions;

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

has 'instance' => (
    traits        => [ "Getopt" ],
    isa           => 'Str',
    is            => 'rw',
	cmd_aliases   => 'i',
	documentation => "Instance to control",
	default       => sub {
		return $ENV{DEVENV_NAME};
	}
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

after 'execute' => sub {

	my $self = shift;
	my $opts = shift;
	my $args = shift;

	if ( $self->start ) {

		my $devenv = DevEnv->new(
			instance_name => $self->instance
		);

		my $web = DevEnv::Web->new( $devenv->main_config->{web}{port} // 6000 );
		$web->instance_name( $self->instance );
		$web->port_offset(   $self->port_offset );
		$web->run();
	}
};

__PACKAGE__->meta->make_immutable;

1;
