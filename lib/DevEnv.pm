package DevEnv;
use Moose;

our $VERSION = 1.00;

use DevEnv::Config::Main;

use Path::Class;

has 'base_dir' => (
    is      => 'ro',
    isa     => 'Path::Class::Dir',
    lazy    => 1,
    builder => '_build__base_dir'
);
sub _build__base_dir {

    my $self = shift;
	return dir( $ENV{DEVENV_BASE} );
}

has 'main_config' => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_main_config'
);
sub _build_main_config {

	return DevEnv::Config::Main->instance->config;
}

has 'verbose' => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0
);

sub debug {

	my $self    = shift;
	my $message = shift;

	if ( $self->verbose ) {
		print STDERR "$message\n";
	}
}

__PACKAGE__->meta->make_immutable;

1;
