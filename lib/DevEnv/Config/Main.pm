package DevEnv::Config::Main;
use MooseX::Singleton;

use DevEnv;
use DevEnv::Exceptions;

use YAML::Tiny;
use Path::Class;

has 'base_dir' => (
	is       => 'ro',
	isa      => 'Path::Class::Dir',
	lazy     => 1,
	builder  => '_build_base_dir'
);
sub _build_base_dir {

	my $self = shift;

	return DevEnv->new(
		instance_name => "none"
	)->base_dir;
}

has '_config_dirs' => (
	traits   => ['Array'],
	is       => 'ro',
	isa      => 'ArrayRef[Path::Class::Dir]',
	lazy     => 1,
	builder  => '_build_config_dirs',
	handles  => {
		all_config_dirs => "elements"
	}
);
sub _build_config_dirs {
	
	my $self = shift;

	my @dirs = ();

	if ( defined $ENV{DEVENV_CONFIG_DIR} ) {
		push @dirs, dir( $ENV{DEVENV_CONFIG_DIR}, "config" );
	}

	push @dirs, dir( $ENV{HOME}, ".devenv", "config" );
	push @dirs, dir( $self->base_dir, "config" );
	push @dirs, dir( "opt", "devenv", "config" );


	return \@dirs;
}

has 'config_file' => (
	is       => 'ro',
	isa      => 'Str',
	default  => 'config.yml'
);

has 'config' => (
	is      => 'ro',
	isa     => 'HashRef',
	lazy    => 1,
	builder => '_build_config'
);

sub _build_config {

	my $self = shift;
	
	my $config = undef;

	foreach my $config_dir ( $self->all_config_dirs ) {

		my $config_file = $config_dir->subdir( "main" )->file( $self->config_file )->stringify;

		if ( -f $config_file ) {

			$config = YAML::Tiny->read( $config_file )->[0];
			last;
		}
	}

	if ( not defined $config ) {
		DevEnv::Exception::Config->throw( "Cannot find the main config file." );
	}

	return $config;
}

1;
