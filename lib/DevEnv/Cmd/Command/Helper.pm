package DevEnv::Cmd::Command::Helper;
use Moose;

# ABSTRACT: Helper application

use DevEnv::Exceptions;
use DevEnv::Config::Main;
use DevEnv::Helper;

use Proc::ProcessTable;
use Data::Dumper;

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

	my $main_config = DevEnv::Config::Main->instance;

	if ( $self->start ) {

		print STDERR "Starting DevEnv Helper\n";

		$0 = "devenv_helper";

		my $helper = DevEnv::Helper->new();
		$helper->host( undef );
		$helper->port( $main_config->config->{helper}{port} );
		$helper->background( $main_config->config->{helper}{port} );
	}
	elsif ( $self->stop ) {

		print STDERR "Stopping DevEnv Helper\n";

		my $t = new Proc::ProcessTable;
		foreach my $p ( @{$t->table} ){	
			if( $p->cmndline =~ m/devenv_helper/ ) {
				print STDERR "* Killing process " . $p->pid . "\n";
				$p->kill(9);
			}		
		}
	}
};

__PACKAGE__->meta->make_immutable;

1;
