package DevEnv::Role::Project;
use Moose::Role;

use DevEnv::Config::Project;

use Path::Class;
use File::Spec;

has 'project_config' => (
    is      => 'ro',
    isa     => 'HashRef',
    lazy    => 1,
    builder => '_build_project_config'
);
sub _build_project_config {

    my $self = shift;

	my $project_config = DevEnv::Config::Project->instance;
	$project_config->config_file( $self->project_config_file );

	return $project_config->config;
}

has 'project_config_file' => (
	is       => 'rw',
	isa      => 'Str'
);

has 'instance_name' => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
	trigger  => sub {
		my $self          = shift;
		my $instance_name = shift;

		$instance_name =~ s/\s/_/g;
		$instance_name =~ s/\//-/g;

		$self->{instance_name} = $instance_name;
	}
);

1;
