package DevEnv::Cmd::Command::Helper;
use Moose;

# ABSTRACT: Helper application

use DevEnv::Exceptions;
use DevEnv::Helper;

extends 'DevEnv::Cmd::Command';

has 'start' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	documentation => "Start the helper daemon"
);

has 'stop' => (
    traits        => [ "Getopt" ],
    isa           => 'Bool',
    is            => 'rw',
	documentation => "Stop the helper daemon"
);

after 'execute' => sub {

	my $self = shift;
	my $opts = shift;
	my $args = shift;

	if ( $self->start ) {

		my $helper = DevEnv::Helper->new();
		$helper->run();
	}
};

__PACKAGE__->meta->make_immutable;

1;
