package DevEnv::Role::Project;
use Moose::Role;

use DevEnv;
use DevEnv::Config::Project;

use Path::Class;
use File::Spec;
use File::Path qw/make_path/;

requires qw/instance_name/;

has 'project_config_file' => (
	is       => 'rw',
	isa      => 'Str|Undef',
);

has 'containers' => (
	traits  => ['Array'],
	is      => 'rw',
	isa     => 'ArrayRef[Str]',
	default => sub { [] },
	handles => {
		all_containers    => 'elements',
		add_container     => 'push',
		get_container     => 'get',
		count_containers  => 'count',
		has_containers    => 'count',
		has_no_containers => 'is_empty',
		sorted_containers => 'sort',
	}
);

has 'project_config' => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_project_config'
);
sub _build_project_config {

    my $self = shift;

	my $project_config = DevEnv::Config::Project->instance;

	if ( defined $self->project_config_file ) {
		$project_config->config_file( $self->project_config_file );
	}

	$project_config->instance_name( $self->instance_name );

	# Get the hashref config
	my $config_hashref = $project_config->config;

	# If no active containers have been set in the instance, read from config
	if ( $self->has_no_containers and defined $config_hashref->{active_containers} ) {
		$self->containers( $config_hashref->{active_containers} );
	}

	# Flag which containers are enabled/disabled
    foreach my $container_name ( keys %{$config_hashref->{containers}} ) {

        my $container_config = $config_hashref->{containers}{ $container_name };

		$container_config->{name} = $container_name;

        # Set it as not enabled, and enabled it below
        $container_config->{enabled} = 0;

        # If it is required, then enable it
        if ( $container_config->{required} ) {
            $container_config->{enabled} = 1;
        }

        # Check if we should enable this container
        if ( grep { $container_name eq $_ } $self->all_containers ) {
            $container_config->{enabled} = 1;
        }

        # Always start the data container first
        if ( $container_config->{type} eq "data" ) {
            $container_config->{enabled} = 1;
        }

        # If the we want it in the foreground, make sure the work container goes last
        if ( $container_config->{type} eq "work" ) {
            $container_config->{enabled} = 1;
        }
    }

	return $config_hashref;
}

has 'user_id' => (
	is      => 'ro',
	isa     => 'Int',
	lazy    => 1,
	builder => '_build_user_id'
);
sub _build_user_id {
	my $self = shift;
	return $ENV{DEVENV_MY_UID} // $self->project_config->{general}{user_id} // 1000;
}

has 'group_id' => (
	is      => 'ro',
	isa     => 'Int',
	lazy    => 1,
	builder => '_build_group_id'
);
sub _build_group_id {
	my $self = shift;
	return $ENV{DEVENV_MY_GID} // $self->project_config->{general}{group_id} // 1000;
}

has 'home_dir' => (
	is      => 'ro',
	isa     => 'Path::Class::Dir',
	lazy    => 1,
	builder => '_build_home_dir'
);
sub _build_home_dir {
	my $self = shift;
	return dir ( $ENV{DEVENV_MY_HOME} // $self->project_config->{general}{home_dir} // $ENV{HOME} );
}

has 'devenv_dir' => (
	is      => 'ro',
	isa     => 'Path::Class::Dir',
	lazy    => 1,
	builder => '_build_devenv_dir'
);
sub _build_devenv_dir {
	my $self = shift;
	my $dir = dir ( $self->home_dir, ".devenv" );

	make_path ( $dir->stringify );

	return $dir;
}

1;
