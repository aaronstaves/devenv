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

has 'instance_name' => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
	trigger  => sub {
		my $self          = shift;
		my $instance_name = shift;

		# Make sure the instance name is fs safe
		$instance_name =~ s/\s/_/g;
		$instance_name =~ s/\//_/g;

		$self->{instance_name} = $instance_name;
	}
);

has 'instance_dir' => (
	is      => 'ro',
	isa     => 'Path::Class::Dir',
	lazy    => 1,
	builder => '_build_instance_dir'
);
sub _build_instance_dir {

	my $self = shift;

	# This is where data for the instance will be stored.
	my $base_dir = DevEnv->full_path(
		$ENV{DEVENV_INSTANCE_BASE} // $self->main_config->{vm}{dir} // $ENV{DEVENV_BASE}
	);

	return dir( $base_dir, $self->instance_name );
}


sub debug {

	my $self    = shift;
	my $message = shift;

	if ( $self->verbose ) {
		print STDERR "$message\n";
	}
}

sub full_path {

	my $class = shift;
	my $path  = shift;

    # TODO: We repeat this in the project role, might be good refector'd someplace
    if ( $path !~ m/^\// ) {
        $path = sprintf( "%s/%s", $ENV{HOME}, $path );
    }

	return $path;
}

__PACKAGE__->meta->make_immutable;

1;
