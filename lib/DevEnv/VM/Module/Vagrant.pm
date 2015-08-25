package DevEnv::VM::Module::Vagrant;
use Moose;

extends 'DevEnv::VM::Module';

use DevEnv::Docker;

use IPC::Run;
use Path::Class;
use File::Which;
use File::Path qw/make_path remove_tree/;
use File::Copy::Recursive qw/fcopy rcopy dircopy fmove rmove dirmove/;
use Template;
use Data::Dumper;

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

#	TODO: Only copy over required config and images
#	remove_tree $self->external_temp_dir->subdir( "devenv", "config" )->stringify;
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

	my $vars = {
		uid               => $<,
		gid               => 5000,
		box_name          => $self->instance_name,
		user_home_dir     => $self->vagrant_share_dir->subdir( $self->outside_home )->stringify,
		config_file       => $self->project_config_file,
		internal_temp_dir => $self->internal_temp_dir->stringify,
		services          => [],
	};

	if ( defined $self->project_config->{vm}{services} ) {

		my $service_dir = $self->external_temp_dir->subdir( "services" )->stringify;

		$self->debug( "Make service temp dir at $service_dir" );

		make_path $service_dir or die "Cannot make the service temp dir $service_dir: $!";

		my @services = @{$self->project_config->{vm}{services}};
		push @services, {
			name    => "VM",
			service => "device-info",
			port    => 0,
		};

		foreach my $service ( @services ) {

			my $name = lc $service->{name};
			$name =~ s/[^\w]/_/g;
			$name .= ".service";

			my $file = sprintf( "%s/%s", $service_dir, $name );

			$self->debug( "Writing service $file" );

			open my $fh, ">", $file or die "Cannot write $file: $!";
			print $fh $self->avahi_service(
				%{$service}
			);
			close $fh;

			push @{$vars->{services}}, {
				name              => $name,
				internal_temp_dir => $self->internal_temp_dir->stringify
			}
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

	system sprintf( "cd %s; %s %s ssh", $self->instance_dir, $self->vargant_params, $self->vagrant );
	#system sprintf( "cd %s; %s  %s ssh -c 'devenv docker --start'", $self->instance_dir, $$self->vargant_params, $self->vagrant );

	return undef;
};

__PACKAGE__->meta->make_immutable;

1;
