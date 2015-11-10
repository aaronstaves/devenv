package DevEnv::VM::Module;
use Moose;

extends 'DevEnv';
with 'DevEnv::Role::Project';

use Path::Class;
use File::Basename;
use File::Path qw/make_path/;
use Template;
use Data::Dumper;

has 'vm_dir' => (
	is      => 'ro',
	isa     => 'Path::Class::Dir',
	lazy    => 1,
	builder => '_build_vm_dir'
);
sub _build_vm_dir {

	my $self = shift;

    return dir( $self->full_path( $self->project_config->{vm}{dir} ) );
}

has 'temp_dir' => (
	is      => 'ro',
	isa     => 'Path::Class::Dir',
	lazy    => 1,
	builder => '_build_temp_dir'
);
sub _build_temp_dir {

	my $self = shift;

	my $dir = Path::Class::tempdir(CLEANUP => 1);

	$self->debug( "Temp directory created at $dir" );

	return $dir;
}

sub process_template {

	my $self = shift;
	my %args = @_;

	my $template_file = $args{template_file};
	my $vars          = $args{vars} // {};

    my $inc_path = sprintf( "%s/templates/", $self->base_dir );

    my $tt = Template->new(
        INCLUDE_PATH => $inc_path
    );

    my $text = "";
    $tt->process( $template_file, $vars, \$text )
        or DevEnv::Exception::VM->throw( "Could not generate $template_file file: " . $tt->error . "." );

    return $text;
}

sub copy_template {

	my $self = shift;
	my %args = @_;

	my $template_file = $args{template_file};
	my $dst_file      = $args{dst_file};
	my $vars          = $args{vars};

	my $text = $self->process_template(
		template_file => $template_file,
		vars          => $vars
	);

	# Make sure the path to the dest file exists
	my ( $name, $path, $suffix ) = fileparse( "$dst_file" );
	make_path $path;

	# Save the text
	open my $fh, ">", "$dst_file";
	print $fh $text;
	close $fh;

	return $text;
}

sub avahi_service {

	my $self = shift;
	my %args = @_;

	my $vars = {
		box_name => $self->instance_name,
		name     => $args{name},
		type     => $args{type},
		port     => $args{port},
		records  => [],
	};

	if ( ( grep { $args{type} eq $_ } ( qw/nfs sftp ftp webdav/ ) ) and defined $args{path} ) {
		push @{$vars->{records}}, "path=" . $args{path};
	}
	if ( grep { $args{type} eq $_ } ( qw/ssh sftp ftp/ ) ) {
		push @{$vars->{records}}, "u=dev";
		push @{$vars->{records}}, "p=dev";
	}
	if ( $args{type} eq "device-info" ) {
		push @{$vars->{records}}, "model=Xserve";
	}

	return $self->process_template(
		template_file => "avahi/generic.tt",
		vars          => $vars
	);
}

sub get_avahi_service_files {

	my $self = shift;

	# Always include the control panel service
	my @avahi_files = (
		{
			name => 'devenv_cp.service',
			file => $self->avahi_service(
				box_name => $self->instance_name,
				name     => "Control Panel",
				type     => "http",
				port     => $self->project_config->{web}{port} // 5999,
				protocal => "tcp"
			)
		}
	);

	foreach my $container_name ( keys %{$self->project_config->{containers}} ) {

		my $config = $self->project_config->{containers}{ $container_name };

		if ( defined $config->{services} ) {

			foreach my $service ( @{$config->{services}} ) {

				# Skip services without tpye
				next if ( not defined $service->{type} );

				my $name = lc $service->{name};
				$name =~ s/[^\w]/_/g;
				$name .= ".service";

				push @avahi_files, {
					name => $name,
					file => $self->avahi_service(
						box_name => $self->instance_name,
						name     => $service->{name},
						type     => $service->{type},
						port     => $service->{src_port},
						protocal => ( $service->{dst_port} =~ m/udp/ )?"udp":"tcp"
					)
				}
			}
        }
    }

	return wantarray ? @avahi_files : \@avahi_files;
}

sub is_running { }
sub start      { }
sub stop       { }
sub remove     { }
sub build      { }
sub status     { }
sub connect    { }

__PACKAGE__->meta->make_immutable;

1;
