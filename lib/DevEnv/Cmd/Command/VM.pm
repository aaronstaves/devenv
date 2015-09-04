package DevEnv::Cmd::Command::VM;
use Moose;

# ABSTRACT: Docker Control

use DevEnv::VM;

extends 'DevEnv::Cmd::Command';

has 'start' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	documentation => "Start the VM"
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

has 'instance' => (
    traits        => [ "Getopt" ],
    isa           => 'Str',
    is            => 'rw',
	cmd_aliases   => 'i',
	documentation => "Give the instance a different name",
	required      => 1
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

after 'execute' => sub {

	my $self = shift;
	my $opts = shift;
	my $args = shift;

	my $vm = DevEnv::VM->new(
		project_config_file => $self->config_file,
		instance_name       => $self->instance,
		verbose             => $self->verbose
	);

	if ( $self->start ) {

		if ( not defined $self->config_file or $self->config_file eq "" ) {
			die "A config file is required to start a VM.";
		}

		$vm->start( 
			tags  => $self->tag 
		);
	}
	elsif ( $self->stop ) {

		$vm->stop( tags => $self->tag );
	}
	elsif ( $self->remove ) {

		$vm->remove(   );
	}
	elsif ( $self->build ) {

		if ( not defined $self->config_file or $self->config_file eq "" ) {
			die "A config file is required to build a VM.";
		}

		$vm->build(   );
	}
	else {
	}
};

__PACKAGE__->meta->make_immutable;

1;
