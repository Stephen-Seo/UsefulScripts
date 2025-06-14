## wireguardConfigGenerator.sh

    Generates config for wireguard
    -h - prints this help
    -n <name> - gives a name to the config
    -c <count> - number of clients to generate for. Mutually exclusive with "-u"
    -s <ipv4_second> - sets the second byte of the ipv4
    -i <ipv4_third> - sets the third byte of the ipv4
    -e <endpoint> - ip address or domain name (required)
    -p <port> - listen port of server (defaults to 50000)
    -k - enables persistent keepalive for clients
    -o <directory> - output dir to place configs (required)
    -u <subnet> - subnet to use (default 24). Mutually exclusive with "-c"
    -f <ipv4_fourth> - must use with "-u" to set partial fourth byte
    -x <ipv6_template> - set template, "x" will be replaced (must be last)
    -d - disable ipv6 addresses

Note that subnets must not conflict between configurations if they are loaded
on the same machine.

For example, to generate two different server/clients configs with differing
subnets, you can run the following:

    # For 10.1.1.0 to 10.1.1.15 (10.1.1.0 and 10.1.1.15 is reserved)
    # For fc00:1:0 to fc00:1:f (fc00:1:0 and fc00:1:f is reserved)
    ./wireguardConfigGenerator.sh -n first -s 1 -i 1 -f 0 -u 28 \
        -e example.com -p 50001 -o conf_output_dir1 -x fc00:1:x
    # For 10.1.1.16 to 10.1.1.31 (10.1.1.16 and 10.1.1.31 is reserved)
    # For fc00:2:0 to fc00:2:f (fc00:2:0 and fc00:2:f is reserved)
    ./wireguardConfigGenerator.sh -n second -s 1 -i 1 -f 16 -u 28 \
        -e example.com -p 50001 -o conf_output_dir2 -x fc00:2:x

If `ipv6` is not desired, you can skip specifying `-x ...` and use `-d` to
disable `ipv6` generation.

## set_pactl_sink_vol_by_ident.sh

Expects opts: `-n <identifier>`, `-p <percentage>`.

## toggle_pactl_sink_mute_by_ident.sh

Expects opt: `-n <identifier>`.
