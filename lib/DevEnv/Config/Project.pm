package DevEnv::Config::Project;
use MooseX::Singleton;

use DevEnv;

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

	return DevEnv->new;
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
	else {
		push @dirs, dir( $ENV{HOME}, ".devenv", "config" );
		push @dirs, dir( $self->base_dir, "config"  );
		push @dirs, dir( "opt", "devenv", "config" );
	}

	return \@dirs;
}

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
	
	my $project_config = undef;

	# Load the project config, override values
	foreach my $config_dir ( $self->all_config_dirs ) {

		my $config_file = $config_dir->subdir( "project" )->file( $self->config_file )->stringify;
	
		$self->devenv->debug( "Checking for project config in $config_file" );

		if ( -f $config_file ) {

			my $yaml = YAML::Tiny->read( $config_file )->[0];

			# Just copy the 'vm' section
			$project_config->{vm} = $yaml->{vm};
	
			# Use the name a key to quick lookups
			foreach my $container ( @{$yaml->{containers}} ) {
				$project_config->{containers}{ $container->{name} } = $container;
			}

			$self->devenv->debug( " * Found config" );

			last;
		}
	}

	if ( not defined $project_config ) {
		die "Cannot find the project config file";
	}

	# Merge to the two configs
	return merge( $self->devenv->main_config, $project_config );
}

1;
