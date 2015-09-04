package DevEnv::Role::Project;
use Moose::Role;

use DevEnv::Config::Project;

use Path::Class;
use File::Spec;

has 'project_config_file' => (
	is       => 'rw',
	isa      => 'Str|Undef',
);

has 'instance_name' => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
	trigger  => sub {
		my $self          = shift;
		my $instance_name = shift;

		$instance_name =~ s/\s/_/g;
		$instance_name =~ s/\//_/g;

		$self->{instance_name} = $instance_name;
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

	return $project_config->config;
}

has 'instance_dir' => (
	is      => 'ro',
	isa     => 'Path::Class::Dir',
	lazy    => 1,
	builder => '_build_instance_dir'
);
sub _build_instance_dir {

	my $self = shift;

	# This is where to build the VMs
	my $vm_dir = $self->project_config->{vm}{dir};

	if ( $vm_dir !~ m/^\// ) {
		$vm_dir = sprintf( "%s/%s", $ENV{HOME}, $vm_dir );
	}

	return dir( $vm_dir, "vm", $self->instance_name );
}

has 'user_id' => (
	is      => 'ro',
	isa     => 'Int',
	lazy    => 1,
	builder => '_build_user_id'
);
sub _build_user_id {
	my $self = shift;
	return $ENV{DEVENV_MY_UID} // $self->project_config->{general}{user_id};
}

has 'group_id' => (
	is      => 'ro',
	isa     => 'Int',
	lazy    => 1,
	builder => '_build_group_id'
);
sub _build_group_id {
	my $self = shift;
	return $ENV{DEVENV_MY_GID} // $self->project_config->{general}{group_id};
}

has 'home_dir' => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	builder => '_build_home_dir'
);
sub _build_home_dir {
	my $self = shift;
	return $ENV{DEVENV_MY_HOME} // $self->project_config->{general}{home_dir};
}

1;
