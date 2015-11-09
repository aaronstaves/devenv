package DevEnv::Config::Project;
use MooseX::Singleton;

use DevEnv;
use DevEnv::Exceptions;

use YAML::Tiny;
use Path::Class;
use Hash::Merge qw(merge);

has 'devenv' => (
	is      => 'ro',
	isa     => 'DevEnv',
	lazy    => 1,
	builder => '_build_devenv'
);
sub _build_devenv {

	my $self = shift;

	return DevEnv->new(
		instance_name => $self->instance_name
	)
}

has 'base_dir' => (
	is       => 'ro',
	isa      => 'Path::Class::Dir',
	lazy     => 1,
	builder  => '_build_base_dir'
);
sub _build_base_dir {

	my $self = shift;
	return $self->devenv->base_dir;
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
		push @dirs, dir( $ENV{DEVENV_CONFIG_DIR} );
	}

	push @dirs, dir( $ENV{HOME}, ".devenv", "config" );
	push @dirs, dir( $self->base_dir, "config"  );
	push @dirs, dir( "opt", "devenv", "config" );

	return \@dirs;
}

has 'instance_name' => (
	is  => 'rw',
	isa => 'Str'
);

has 'config_file' => (
	is       => 'rw',
	isa      => 'Str',
);

has 'config' => (
	is      => 'ro',
	isa     => 'HashRef',
	lazy    => 1,
	builder => '_build_config'
);

sub _build_config {

	my $self = shift;

	my $main_config = $self->devenv->main_config;
	
	my $project_config = {};

	# If the project config has not been set, then pray that one exists in the instance :)
	if ( defined $self->config_file and $self->config_file ne "" ) {

		# Load the project config, override values
		foreach my $config_dir ( $self->all_config_dirs ) {

			my $config_file = $config_dir->subdir( "project" )->file( $self->config_file )->stringify;
		
			$self->devenv->debug( "Checking for project config in $config_file" );

			if ( -f $config_file ) {

				$project_config = YAML::Tiny->read( $config_file )->[0];
				delete $project_config->{vm}{dir};
				$self->devenv->debug( " * Found config" );
				last;
			}
		}
	}

	# Load the config from instance. This will be what the instance was created with. Load
	# last. 
	my $instance_config_file = $self->devenv->instance_dir->file( "config.yml" )->stringify;
	my $instance_config = {};

	if ( -f $instance_config_file ) {

		$self->devenv->debug( "Found instance config" );

		$instance_config = YAML::Tiny->read( $instance_config_file )->[0];
	}

	# Finalize the config

	my $final_config = merge( 
		merge( $main_config, $project_config ),
		$instance_config
	);

	if ( not defined $final_config->{containers} ) {
		DevEnv::Exception::Config->throw( "Cannot find any containers in config file, or no config file specified. Specifiy a config file, or check if the config file is setup correctly." );
	}

	return $final_config;
}

sub reload_config {

	my $self = shift;
	my %args = @_;

	$self->{config} = $self->_build_config();

	return undef;
}

sub instance_config_write {

	my $self = shift;
	my %args = @_;

	my $config = $args{config} // $self->config;
	my $file   = $args{file}   // $self->devenv->instance_dir->file( "config.yml" );

	my $yaml = YAML::Tiny->new( $config );

    $yaml->write( $file->stringify );

	return undef;
}

1;
