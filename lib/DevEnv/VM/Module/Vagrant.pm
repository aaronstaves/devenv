package DevEnv::VM::Module::Vagrant;
use Moose;

extends 'DevEnv::VM::Module';

use DevEnv::Docker;
use DevEnv::Config::Project;

use IPC::Run;
use Path::Class;
use File::Which;
use File::Copy;
use File::Path qw/make_path remove_tree/;
use File::Copy::Recursive qw/fcopy rcopy dircopy fmove rmove dirmove/;
use Template;

has 'vagrant_file_name' => (
	is      => 'ro',
	isa     => 'Str',
	default => 'vagrant'
);

has 'vagrant' => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	builder => '_build_vagrant'
);
sub _build_vagrant {
	my $self = shift;
	return which( $self->vagrant_file_name );
}

has 'temp_dir_name' => (
	is      => 'ro',
	isa     => 'Str',
	default => "vm_tmp"
);

has 'vagrant_share_dir' => (
	is      => 'ro',
	isa     => 'Path::Class::Dir',
	default => sub {
		return dir( "/vagrant" );
	}
);

has 'external_temp_dir' => (
	is      => 'ro',
	isa     => 'Path::Class::Dir',
	lazy    => 1,
	builder => '_build_external_temp_dir'
);
sub _build_external_temp_dir {

	my $self = shift;
	return $self->instance_dir->subdir( $self->outside_home, $self->temp_dir_name );
}

has 'internal_temp_dir' => (
	is      => 'ro',
	isa     => 'Path::Class::Dir',
	lazy    => 1,
	builder => "_build_internal_temp_dir"
);
sub _build_internal_temp_dir {

	my $self = shift;
	return $self->vagrant_share_dir->subdir( $self->outside_home, $self->temp_dir_name );
}

has 'vargant_params' => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	builder => "_build_params"
);

sub _build_params {

	my $self = shift;

	my @params = ();

	if ( 
		defined $self->main_config->{vm}{module}{Vagrant}{provider}
	and 
		$self->main_config->{vm}{module}{Vagrant}{provider} ne ""
	and
		$self->main_config->{vm}{module}{Vagrant}{provider} ne "virtualbox" 
	) {
		push @params, "VAGRANT_DEFAULT_PROVIDER=" . $self->main_config->{vm}{module}{Vagrant}{provider};
	}

	return join ( " ", @params );
}

override 'start' => sub { 

	my $self = shift;

	$self->debug( "Starting Vagrant VM" );

	if ( ! -d $self->instance_dir ) {
		$self->build();
	}

	system sprintf( "cd %s; %s %s up", $self->instance_dir, $self->vargant_params, $self->vagrant );

	return undef;
};

override 'stop' => sub { 

	my $self = shift;

	$self->debug( "Stopping Vagrant VM" );

	system sprintf( "cd %s; %s %s halt", $self->instance_dir, $self->vargant_params, $self->vagrant );

	return undef;
};

override 'remove' => sub { 

	my $self = shift;

	$self->debug( "Removing Vagrant box" );

	system sprintf( "cd %s; %s %s destroy -f", $self->instance_dir, $self->vargant_params, $self->vagrant );

	remove_tree $self->instance_dir->stringify;

	return undef;
};

sub _copy_devenv_to_vagrant {

	my $self = shift;

	make_path $self->external_temp_dir->stringify;

	# Copy devenv to vagrant tmp directory
	dircopy (
		$self->base_dir,
		$self->external_temp_dir->subdir( "devenv" )
	);

	remove_tree $self->external_temp_dir->subdir( "devenv", ".git" )->stringify;
	remove_tree $self->external_temp_dir->subdir( "devenv", "local" )->stringify;

	# We are going to use the config created for the instance. Remove the old config directory
	# and copy the instance config.
	remove_tree $self->external_temp_dir->subdir( "devenv", "config", "project" )->stringify;
	make_path $self->external_temp_dir->subdir( "devenv", "config", "project" )->stringify;
	copy $self->instance_dir->file( "config.yml" ), $self->external_temp_dir->subdir( "devenv", "config", "project" )->file( "config.yml" );

#	TODO: Only copy over required config and images
#	remove_tree $self->external_temp_dir->subdir( "devenv", "images" )->stringify;

# 	TODO: Also check .devenv for custom configs


	return undef;
}

override 'build' => sub {
	
	my $self = shift;

	$self->debug( "Building Vagrant box" );

	if ( -d $self->instance_dir ) {
		die "VM already exists at " . $self->instance_dir;
	}
	
	make_path $self->external_temp_dir->stringify;

	# Make a copy of the config file in the instance dir
	DevEnv::Config::Project->instance->instance_config_write();

	my $vars = {
		uid               => $self->user_id,
		gid               => $self->group_id,
		box_name          => $self->instance_name,
		user_home_dir     => $self->vagrant_share_dir->subdir( $self->outside_home )->stringify,
		config_file       => $self->project_config_file,
		internal_temp_dir => $self->internal_temp_dir->stringify,
		services          => [],
	};

	my $service_dir = $self->external_temp_dir->subdir( "services" )->stringify;

	$self->debug( "Make service temp dir at $service_dir" );

	make_path $service_dir or die "Cannot make the service temp dir $service_dir: $!";

	foreach my $avahi_service ( $self->get_avahi_service_files() ) {

		my $file = sprintf( "%s/%s", $service_dir, $avahi_service->{name} );

		$self->debug( "Writing service $file" );

		open my $fh, ">", $file or die "Cannot write $file: $!";
		print $fh $avahi_service->{file};
		close $fh;

		push @{$vars->{services}}, {
			name              => $avahi_service->{name},
			internal_temp_dir => $self->internal_temp_dir->stringify
		}
	}

	$self->_copy_devenv_to_vagrant();


	my $inc_path = sprintf( "%s/templates/vm/vagrant/", $self->base_dir() );

	$self->debug( "Template include path is $inc_path" );

	my $tt = Template->new(
		INCLUDE_PATH => $inc_path
	);

	my $vagrantfile_text = "";
	$tt->process( "Vagrantfile.tt", $vars, \$vagrantfile_text ) or die $tt->error;

	open my $fh, ">", sprintf ( "%s/Vagrantfile", $self->instance_dir ) or die "Could not write Vagrantfile to VM directory " . $self->instance_dir;
	print $fh $vagrantfile_text;
	close $fh;

	system sprintf( "cd %s; %s %s up", $self->instance_dir, $self->vargant_params, $self->vagrant );

	my $cmd = sprintf( "cd %s; %s  %s ssh -c 'devenv docker --start %s'",
		$self->instance_dir,
		$self->vargant_params,
		$self->vagrant,
		$self->verbose?"-v":""
	);

	$self->debug( "Vagrant Provision = $cmd" );

	system $cmd;

	return undef;
};

__PACKAGE__->meta->make_immutable;

1;
