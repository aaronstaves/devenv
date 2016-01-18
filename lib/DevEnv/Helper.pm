package DevEnv::Helper;
use Moose;
use MooseX::NonMoose;
extends 'HTTP::Server::Simple::CGI';

use DevEnv;
use DevEnv::Exceptions;

use Template;
use Try::Tiny;
use JSON::XS;
use Data::Dumper;
use Socket;
use IPC::Run;

has 'devenv' => (
	isa     => 'DevEnv',
	is      => 'ro',
	lazy    => 1,
	builder => "_build_devenv"
);
sub _build_devenv {

	my $self = shift;

	return DevEnv->new(
		instance_name => "default",
		verbose       => 1
	);
}

sub handle_request {

	my $self = shift;
	my $cgi  = shift;

	my $path = $cgi->path_info();

	my ( $action ) = $path =~ m/([^\/]+)$/;

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

	my $include_path = $self->devenv->base_dir->subdir( "templates", "web" )->stringify();

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

sub _page_index {

	my $self = shift;
	my %args = @_;

	my $cgi = $args{cgi};

	$self->_ok(
		cgi          => $cgi,
		template     => "helper_index.tt",
	);

	return undef;
}

sub _action_hosts {

	my $self = shift;
	my %args = @_;

	my $cgi = $args{cgi};

	# List the HTTP services 
	my @cmd = ( "dns-sd", "-Z" );

	my $in = "";
	my $out = "";
	my $err = "";

	eval {
		IPC::Run::run \@cmd, \$in, \$out, \$err, IPC::Run::timeout ( 10 );
	};

	my $hosts = undef;

	foreach my $row ( split /\n/, $out ) {

		next if ( $row =~ m/^;/ );

		# The SRV lines have the host name
		if ( $row =~ m/\bSRV\b/ ) {

			my ( $name, $srv, $n1, $n2, $port, $host ) = split /\s+/, $row;

			# Get the IP, if possible, from the host name
			my $ip = undef;
			eval {
				my @addresses = gethostbyname($host) or die "Can't resolve $host: $!\n";
				( $ip ) = map { inet_ntoa($_) } @addresses[4 .. $#addresses];
			};

			next if ( not defined $ip );

			$host =~ s/\.$//;

			$hosts->{ $host } = $ip;
		}
	}

	my @hosts = ();
	foreach my $host ( keys %{$hosts} ) {

		push @hosts, sprintf( "%s\t%s", $hosts->{$host}, $host );
		
	}

	$self->_ok(
		cgi          => $cgi,
		content_type => "plain/text",
		content      => join ( "\n", @hosts ) . "\n"
	);

	return undef;
}

no Moose;

__PACKAGE__->meta->make_immutable;
