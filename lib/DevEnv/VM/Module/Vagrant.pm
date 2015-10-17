package DevEnv::VM::Module::Vagrant;
use Moose;

extends 'DevEnv::VM::Module';

use DevEnv;
use DevEnv::Docker;
use DevEnv::Exceptions;
use DevEnv::Config::Project;

use IPC::Run;
use Path::Class;
use File::Which;
use File::Copy;
use File::Path qw/make_path remove_tree/;
use File::Copy::Recursive qw/fcopy rcopy dircopy fmove rmove dirmove/;
use Template;
use Clone qw/clone/;

use Data::Dumper;

our $VAGRANT_FILE_NAME = "vagrant";

has 'vagrant_file_name' => (
	is      => 'ro',
	isa     => 'Str',
	default => sub {
		return $VAGRANT_FILE_NAME
	}
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
	return $self->instance_dir->subdir( $self->temp_dir_name );
}

has 'internal_temp_dir' => (
	is      => 'ro',
	isa     => 'Path::Class::Dir',
	lazy    => 1,
	builder => "_build_internal_temp_dir"
);
sub _build_internal_temp_dir {

	my $self = shift;
	return $self->vagrant_share_dir->subdir( $self->temp_dir_name );
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

=head1 METHODS

=head2 CLASS METHODS

=head3 get_global_status

Get the status off all the Vagrant VMs. Returns a hashref
with the name of the VM as the key.

=cut

sub get_global_status {

	my $class = shift;
	my %args = @_;

	my ( $stdout, $stderr );
	IPC::Run::run
		[ which( $VAGRANT_FILE_NAME ), 'global-status' ],
		'>',  \$stdout,
		'2>', \$stderr;

	my @columns = (
		{ title   => 'id',        key => 'id' },
		{ title   => 'name',      key => 'name' },
		{ title   => 'provider',  key => 'provider' },
		{ title   => 'state',     key => 'state' },
		{ title   => 'directory', key => 'directory' },
	);

	my @rows = split /\n/, $stdout;

	my $header     = shift @rows;

	my $last_index = length ( $header ) * 2;
	foreach my $column ( reverse @columns ) {
		$column->{start} = index ( $header, $column->{title} );
		$column->{width} = $last_index - $column->{start};
		$last_index = $column->{start}
	}
	shift @rows;

	my $vm_dir = DevEnv->full_path( DevEnv->new(
		instance_name => "none"
	)->main_config->{vm}{dir} );

	my $vms = undef;
	foreach my $row ( @rows ) {

		$row =~ s/^\s+//;

		# End when we find the end of the list
		last if ( $row eq "" );

		my %record = ();
		foreach my $column ( reverse @columns ) {

			my $value = substr ( $row, $column->{start}, $column->{width} );
			$value =~ s/\s+$//;
			$record{ $column->{key} } = $value;
		}

		# Skip VMs that are not ours :)
		next if ( $record{directory} !~ m/^\Q$vm_dir\E/ );

		my ( $name ) = $record{directory} =~ m/([^\/]+$)/;

		$vms->{ $name } = \%record;
	}

	return $vms;
}

=head2 OBJECT METHODS

=head3 is_running (override )

Is this instance of the VM running

=cut

override 'is_running' => sub { 

	my $self = shift;

	my $vms = $self->get_global_status;

	my $is_running = 0;

	if ( defined $vms->{ $self->instance_name } and $vms->{ $self->instance_name }{state} eq "running" ) {
		$is_running = 1;
	}

	return $is_running;
};


=head3 start (override)

This method will start the VM. If the VM does not exists, it will build the VM.

=cut

override 'start' => sub { 

	my $self = shift;

	$self->debug( "Starting Vagrant VM" );

	if ( ! -d $self->instance_dir ) {
		$self->build();
	}

	system sprintf( "cd %s; %s %s up", $self->instance_dir, $self->vargant_params, $self->vagrant );

	return undef;
};

=head3 stop (override)

This method will stop the VM.

=cut

override 'stop' => sub { 

	my $self = shift;

	$self->debug( "Stopping Vagrant VM" );

	system sprintf( "cd %s; %s %s halt", $self->instance_dir, $self->vargant_params, $self->vagrant );

	return undef;
};

=head3 remove (override)

This method will destory the VM and remove the instance directory.

=cut

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
	remove_tree $self->external_temp_dir->subdir( "devenv", "config" )->stringify;

	make_path $self->external_temp_dir->subdir( "devenv" )->subdir( "config", "main" )->stringify;

	my $project_config = clone( $self->project_config() );

	# Since we are not dealing with a VM, remove the VM config section
	delete $project_config->{vm};

	# Build a config for the project. This config has been cooked with instance information.
	DevEnv::Config::Project->instance->instance_config_write(
		config => $project_config,
		file   => $self->external_temp_dir->subdir( "devenv" )->subdir( "config", "main" )->file( "config.yml" )
	);

	return undef;
}

=head3 build (override)

This method will build the VM.

=cut

override 'build' => sub {
	
	my $self = shift;

	$self->debug( "Building Vagrant box" );

	if ( -d $self->instance_dir ) {
		DevEnv::Exception::VM->throw( "VM already exists at " . $self->instance_dir . "." );
	}

	make_path $self->external_temp_dir->stringify;

	my $vars = {
		uid               => $self->user_id,
		gid               => $self->group_id,
		box_name          => $self->instance_name,
		config_file       => $self->project_config_file,
		internal_temp_dir => $self->internal_temp_dir->stringify,
		services          => [],
	};

	if ( defined $self->project_config->{general}{home_dir} and $self->project_config->{general}{home_dir} ne "" ) {

		my $home_dir = $self->project_config->{general}{home_dir};

		if ( $home_dir !~ m /\// ) {
			$home_dir = $self->vm_dir->subdir( $home_dir )->stringify,
		}
	
		$vars->{home_dir} = $home_dir;
	}

	my $service_dir = $self->external_temp_dir->subdir( "services" )->stringify;

	$self->debug( "Make service temp dir at $service_dir" );

	make_path $service_dir or DevEnv::Exception::VM->throw( "Cannot make the service temp dir $service_dir: $!" );

	foreach my $avahi_service ( $self->get_avahi_service_files() ) {

		my $file = sprintf( "%s/%s", $service_dir, $avahi_service->{name} );

		$self->debug( "Writing service $file" );

		open my $fh, ">", $file or DevEnv::Exception::VM->throw( "Cannot write $file: $!" );
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
	$tt->process( "Vagrantfile.tt", $vars, \$vagrantfile_text )
		or DevEnv::Exception::VM->throw( "Cannot process the Vagrantfile.tt: " . $tt->error . "." );

	open my $fh, ">", sprintf ( "%s/Vagrantfile", $self->instance_dir )
		or DevEnv::Exception::VM->throw( "Could not write Vagrantfile to VM directory " . $self->instance_dir . "." );

	print $fh $vagrantfile_text;
	close $fh;

    DevEnv::Config::Project->instance->instance_config_write(
        config => $self->project_config,
        file   => $self->instance_dir->file( "config.yml" )
    );

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

=head3 status (override)

This method will return the status of the VM instance.

=cut

override 'status' => sub {

	my $self = shift;
	my %args = @_;

};

=head3 connect (override)

Make a shell connection to the VM

=cut

override 'connect' => sub {

	my $self = shift;
	my %args = @_;

	if ( not $self->is_running ) {
		DevEnv::Exceptions->throw( "Instance " . $self->instance_name . " is not running. Cannot connect." );
	}

	system sprintf( "cd %s; %s %s ssh", $self->instance_dir, $self->vargant_params, $self->vagrant );
};

__PACKAGE__->meta->make_immutable;

1;
