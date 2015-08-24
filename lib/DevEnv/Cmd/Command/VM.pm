package DevEnv::Cmd::Command::VM;
use Moose;

# ABSTRACT: Docker Control

use DevEnv::VM;

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

has 'halt' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	documentation => "Remove the containers"
);

has 'build' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	documentation => "Remove the containers"
);

has 'tag' => (
    traits        => [ "Getopt" ],
    isa           => 'ArrayRef[Str]',
    is            => 'rw',
	cmd_aliases   => 't',
	documentation => "Tag"
);

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

has 'image' => (
    traits        => [ "Getopt" ],
    isa           => 'Str',
    is            => 'rw',
	documentation => "VM Image"
);

has 'version' => (
    traits        => [ "Getopt" ],
    isa           => 'Str',
    is            => 'rw',
	documentation => "VM Image",
	default       => "0"
);

has 'type' => (
    traits        => [ "Getopt" ],
    isa           => 'Str',
    is            => 'rw',
	documentation => "VM builder type",
	default       => "Vagrant"
);

has 'vm_dir' => (
    traits        => [ "Getopt" ],
    isa           => 'Str',
    is            => 'rw',
	documentation => "VM Directory",
	default       => sub {
		return sprintf( "%s/%s", $ENV{HOME}, ".devenv/vm" )
	}
);

after 'execute' => sub {

	my $self = shift;
	my $opts = shift;
	my $args = shift;

	my $vm = DevEnv::VM->new(
		type          => $self->type,
		vm_dir        => $self->vm_dir,

		config_file   => $self->config_file,
		instance_name => $self->instance,
		verbose       => $self->verbose
	);

	if ( $self->start ) {

		$vm->start( 
			image => $self->image,
			tags  => $self->tag 
		);
	}
	elsif ( $self->stop ) {

		$vm->stop( tags => $self->tag );
	}
	elsif ( $self->halt ) {

		$vm->remove(   );
	}
	elsif ( $self->build ) {

		$vm->build(   );
	}
	else {
	}
};

__PACKAGE__->meta->make_immutable;

1;
