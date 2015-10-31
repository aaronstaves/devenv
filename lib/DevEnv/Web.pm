package DevEnv::Web;
use Moose;
use MooseX::NonMoose;
extends 'HTTP::Server::Simple::CGI';

use DevEnv;
use DevEnv::Docker;
use DevEnv::Exceptions;

use Template;
use Try::Tiny;
use JSON::XS;
use Net::Address::IP::Local;
use HTML::Entities;

has 'config_file' => (
	isa     => 'Str',
	is      => 'rw',
	default => sub {
		return $ENV{DEVENV_CONFIG_FILE}
	}
);

has 'devenv' => (
	isa     => 'DevEnv',
	is      => 'ro',
	lazy    => 1,
	builder => "_build_devenv"
);
sub _build_devenv {

	my $self = shift;

	return DevEnv->new(
		instance_name => $self->instance_name,
		verbose       => 1
	);
}

has 'instance_name' => (
	isa     => 'Str',
	is      => 'rw',
	default => sub {
		return $ENV{DEVENV_NAME} // "none";
	}
);

has 'port_offset' => (
    isa     => 'Int',
    is      => 'rw',
	default => sub {
		return $ENV{DEVENV_PORT_OFFSET} // 0;
	}
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

sub _docker {
		
	my $self = shift;
	my %args = @_;

	return DevEnv::Docker->new(
        project_config_file => $self->config_file,
        instance_name       => $self->instance_name,
        port_offset         => $self->port_offset,
		containers          => [ $self->all_containers ],
		verbose       => 1
    );
}

sub handle_request {

	my $self = shift;
	my $cgi  = shift;

	my $path = $cgi->path_info();

	my ( $action ) = $path =~ m/([^\/]+)$/;

	print STDERR "Path $path = " . ( $action || "NA" ) . "\n";

	try {

		if ( defined $action and $action =~ m/^(action|page|file)/ and $self->can( "_$action" ) ) {
			my $func = "_$action";
			$self->$func( cgi => $cgi, path => $path );
		}
		elsif ( $path eq "/" ) {
			$self->_page_index(
				cgi => $cgi, path => $path
			);
		}
		else {
			$self->_error(
				status  => 404, 
				error   => "Not Found",
				message => "Could not find an action for $path"
			);
		}
	}
	catch {

		$self->_error(
			cgi     => $cgi,
			error   => "$_",
			message => "Error"
		);
	};

	return undef;
}

sub _template {

	my $self = shift;
	my %args = @_;

	my $vars     = $args{vars} || {};
	my $template = $args{template};

	my $include_path = $self->_docker->base_dir->subdir( "templates", "web" )->stringify();

	print STDERR "Include Path =  $include_path\n";

	my $tt = Template->new({
		INCLUDE_PATH => $include_path,
		EVAL_PERL    => 1,
	}) or die "$Template::ERROR\n";

	my $output = '';
	$tt->process( $template, $vars, \$output) or die "Cannot generate $template";

	print $output;
}

sub _ok {

	my $self = shift;
	my %args = @_;

	my $cgi          = $args{cgi};
	my $template     = $args{template};
	my $vars         = $args{vars} // {};
	my $content_type = $args{content_type} // "text/html";
	my $content      = $args{content};

	print "HTTP/1.0 200 OK\r\n";
	print $cgi->header( $content_type );


	my $hostname = $self->_docker()->project_config->{web}{hostname};

	if ( not defined $hostname and $self->_docker()->project_config->{web}{bonjour} ) {
		$hostname = sprintf( "%s.local", $self->instance_name );
	}
	else {
		$hostname = eval { Net::Address::IP::Local->connected_to('google.com') };
	}

	$vars->{hostname} = $hostname;
	$vars->{instance_name} = $self->instance_name;

	if ( defined $template ) {

		$self->_template(
			template => $template,
			vars     => $vars
		);
	}
	else {
		print $content;
	}

	return undef;
}

sub _error {

	my $self = shift;
	my %args = @_;

	my $cgi     = $args{cgi};
	my $status  = $args{status} || 500;
	my $error   = $args{error};
	my $message = $args{message};

	print STDERR "$error\n";
	print STDERR "$message\n";

	print "HTTP/1.0 $status Error\r\n";
	print $cgi->header;

	$self->_template(
		template => "error.tt",
		vars     => {
			status  => $status,
			title   => $error,
			error   => $error,
			message => $message
		}
	);

	return undef;
}

sub _file {

	my $self = shift;
	my %args = @_;

	my $path = $args{path};

	my ( $file ) = $path =~ m/files\/(.*)$/;

	open my $fh, sprintf ( "%s/files/%s", $self->devenv->base_dir, $file );
	while ( my $data = <$fh> ) {
		print $data;
	}
	close $fh;

	return undef;
}

sub _page_index {

	my $self = shift;
	my %args = @_;

	my $cgi = $args{cgi};

	$self->_ok(
		cgi          => $cgi,
		template     => "index.tt",
	);

	return undef;
}

sub _page_log {

	my $self = shift;
	my %args = @_;

	my $cgi = $args{cgi};

	my $container_name = $cgi->param( "container_name" );

	my $log = encode_entities(
		$self->_docker()->log(
			container_name => $container_name
		)
	);
	$log =~ s/\n/<br\/>/g;
	$log =~ s/\t/&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;/g;

	$self->_ok(
		cgi      => $cgi,
		template => "log.tt",
		vars     => {
			log            => $log,
			container_name => $container_name
		}
	);

	return undef;
}

sub _action_start {

	my $self = shift;
	my %args = @_;

	my $cgi = $args{cgi};

	my @containers = ();
	if ( $cgi->param('containers') ) {
		@containers = grep { $_ ne "" } split /,/, $cgi->param('containers');
	}
	$self->containers( \@containers );

	$self->_docker()->start(); 

	$self->_action_status(
		cgi  => $cgi,
	);

	return undef;
}

sub _action_stop {

	my $self = shift;
	my %args = @_;

	my $cgi = $args{cgi};

	$self->_docker()->stop(); 

	$self->_action_status(
		cgi  => $cgi,
	);

	return undef;
}

sub _action_refresh {

	my $self = shift;
	my %args = @_;

	my $cgi = $args{cgi};

	my @containers = ();
	if ( $cgi->param('containers') ) {
		@containers = grep { $_ ne "" } split /,/, $cgi->param('containers');
	}
	$self->containers( \@containers );

	my $docker = $self->_docker();
	$docker->remove( force => 0 ); 
	$docker->start();

	$self->_action_status(
		cgi  => $cgi,
	);

	return undef;
}

sub _action_remove {

	my $self = shift;
	my %args = @_;

	my $cgi = $args{cgi};

	my @containers = ();
	if ( $cgi->param('containers') ) {
		@containers = grep { $_ ne "" } split /,/, $cgi->param('containers');
	}
	$self->containers( \@containers );

	my $docker = $self->_docker();
	$docker->remove( force => 1 ); 

	$self->_action_status(
		cgi  => $cgi,
	);

	return undef;
}

sub _action_status {

	my $self = shift;
	my %args = @_;

	my $cgi = $args{cgi};

	$self->_ok(
		cgi          => $cgi,
		content_type => "applitcation/json",
		content      => JSON::XS->new->utf8->pretty->encode(
			$self->_docker()->status()
		)
	);

	return undef;
}

no Moose;

__PACKAGE__->meta->make_immutable;
