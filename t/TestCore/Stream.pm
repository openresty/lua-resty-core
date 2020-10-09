package t::TestCore::Stream;

use Test::Nginx::Socket::Lua::Stream -Base;
use Cwd qw(cwd);

sub gen_random_port (@);

$ENV{TEST_NGINX_HOTLOOP} ||= 10;

our $pwd = cwd();

our $lua_package_path = './lib/?.lua;../lua-resty-lrucache/lib/?.lua;;';

our $init_by_lua_block = <<_EOC_;
    local verbose = false
    if verbose then
        local dump = require "jit.dump"
        dump.on("b", "$Test::Nginx::Util::ErrLogFile")
    else
        local v = require "jit.v"
        v.on("$Test::Nginx::Util::ErrLogFile")
    end

    require "resty.core"
    jit.opt.start("hotloop=$ENV{TEST_NGINX_HOTLOOP}")
    -- jit.off()
_EOC_

our $StreamConfig = <<_EOC_;
    lua_package_path '$lua_package_path';

    init_by_lua_block {
        $t::TestCore::Stream::init_by_lua_block
    }
_EOC_

our @EXPORT = qw(
    $pwd
    $lua_package_path
    $init_by_lua_block
    $StreamConfig
    gen_random_port
);

add_block_preprocessor(sub {
    my $block = shift;

    if (!defined $block->stream_config) {
        $block->set_value("stream_config", $StreamConfig);
    }
});

# borrowed from Test::Nginx::Util
sub gen_random_port (@) {
    my (@unavailable_port_list) = @_;

    push @unavailable_port_list, $ENV{TEST_NGINX_SERVER_PORT};

    my %unavailable_ports;
    for my $port (@unavailable_port_list) {
        $unavailable_ports{$port} = 1;
    }

    my $server_addr = server_addr;

    srand $$;

    my $random_port;
    my $tries = 1000;
    for (my $i = 0; $i < $tries; $i++) {
        my $port = int(rand 60000) + 1025;

        next if $unavailable_ports{$port};

        my $sock = IO::Socket::INET->new(
            LocalAddr => $server_addr,
            LocalPort => $port,
            Proto => 'tcp',
            Timeout => 0.1,
        );

        if (defined $sock) {
            $sock->close();
            $random_port = $port;
            last;
        }
    }

    if (!defined $random_port) {
        bail_out "Cannot find an available listening port number after $tries attempts.\n";
    }

    return $random_port;
}

1;
