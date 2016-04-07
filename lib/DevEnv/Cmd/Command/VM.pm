package DevEnv::Cmd::Command::VM;
use Moose;

# ABSTRACT: Docker Control

use DevEnv::VM;
use DevEnv::Exceptions;

extends 'DevEnv::Cmd::Command';

has 'start' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	documentation => "Start the VM"
);

has 'suspend' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	documentation => "Suspend the VM"
);

has 'stop' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	documentation => "Stop the VM"
);

has 'remove' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	documentation => "Remove the VM"
);

has 'build' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	documentation => "Build the VM"
);

has 'status' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	documentation => "Give status on all VMs or just one"
);

has 'connect' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	documentation => "Connect to the VM"
);

has 'package' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	documentation => "Package the VM"
);

has 'instance' => (
    traits        => [ "Getopt" ],
    isa           => 'Str',
    is            => 'rw',
	cmd_aliases   => 'i',
	documentation => "Give the instance a name",
);

has 'config_file' => (
    traits        => [ "Getopt" ],
    isa           => 'Str',
    is            => 'rw',
	cmd_aliases   => 'c',
);

has 'tag' => (
    traits        => [ "Getopt" ],
    isa           => 'ArrayRef[Str]',
    is            => 'rw',
	cmd_aliases   => 't',
	documentation => "Tag"
);

has 'version' => (
    traits        => [ "Getopt" ],
    isa           => 'Str',
    is            => 'rw',
	documentation => "VM Version",
	default       => "0"
);

has 'skip_docker_build' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	cmd_aliases   => 'S',
	documentation => "Skip docker build. Build VM only."
);



sub _non_instance_command {

	my $self = shift;
	my $opts = shift;
	my $args = shift;

	if ( $self->status ) {
		DevEnv::VM->global_status();
	}
	elsif ( $self->stop ) {
		DevEnv::VM->global_stop(
			verbose => $self->verbose
		);
		print STDERR "VMs stopped\n";
	}
	elsif ( $self->start ) {
		DevEnv::VM->global_start(
			verbose => $self->verbose
		);
		print STDERR "VMs started\n";
	}
	else {
		print STDERR $self->usage();

		die "Cannot find command";
	}
}

sub _instance_command {

	my $self = shift;
	my $opts = shift;
	my $args = shift;

	my $vm = DevEnv::VM->new(
		project_config_file => $self->config_file,
		instance_name       => $self->instance // "default",
		verbose             => $self->verbose
	);

	if ( $self->start ) {

		$vm->start( 
			tags  => $self->tag 
		);
	}
	elsif ( $self->stop ) {

		$vm->stop( tags => $self->tag );
	}
	elsif ( $self->suspend ) {

		$vm->suspend();
	}
	elsif ( $self->remove ) {

		$vm->remove();
	}
	elsif ( $self->build ) {

		$vm->build( skip_docker_build => $self->skip_docker_build );
	}
	elsif ( $self->connect ) {
		$vm->connect();
	}
	elsif ( $self->package ) {
		$vm->package();
	}
	elsif ( $self->status ) {
		$vm->status();
	}
	else {
		print STDERR $self->usage();
		die "Cannot find command";
	}
}

after 'execute' => sub {

	my $self = shift;
	my $opts = shift;
	my $args = shift;


	if ( not defined $self->instance ) {

		$self->_non_instance_command( opts => $opts, args => $args );
	}
	else {

		$self->_instance_command( opts => $opts, args => $args );
	}
};

__PACKAGE__->meta->make_immutable;

1;
