#! /usr/bin/env bash  

help='
  launch.sh

      launch.sh <run flags> -- <cmd>

  Set some generic development environment settings. Parses arguments of the
  form `<run flags> -- <cmd>`. If `cmd` ends with `\;`, the default entrypoint
  will be returned to upon completion of `cmd` - helpful for spawning a
  development REPL which will exit to a shell session. Uses either `podman` if
  available or `docker` otherwise.
    
    <run flags>    Passed as `docker run <run flags> img`
    <cmd>          Passed as `docker run img <cmd>`
  
  Interpreted variables
   
    org img ver    Docker image name, `<org>/<img>:<ver>` or empty
    config_flags   Flags passed as <run_flags> specific to an image. Newline
                   characters will be stripped.
    ps1            Optional image-specific PS1 string, otherwise `<img>:<ver>> `
                   is used.
    dockerfile     Optional dockerfile as string, which will be built if it
                   doesn'"'"'t exist or if `--force-build` is set.
  
  Additional flags which will be parsed out of `<run flags>`
  
    --help         Print this help
    --force-build  Force rebuild if a custom `dockerfile` is set
    --force-echo   Force echoing of docker command 
    --force-no-tty Force session not to use a tty (uses `-i` instead of `-it`)
    --force-no-ps1 Do not attempt to inject a prompt based on image name
'

# use podman by default, but docker if unavailable/not started
if [ -x "$(command -v podman)" ] && 
   ! [ podman machine inspect 2> /dev/null ] || 
   [[ "$(podman machine inspect)" == *'"State": "running"'* ]]; 
then 
    engine="podman";
else 
    engine="docker";
    [[ $prot -eq "docker" ]] && export name="$prot.io/$name" && unset prot;
fi

# determine if launched from a tty (omit -t for podman on macos)
test -t 1 && use_tty="t"

# always run as root user
# map home directory into root user directory
flags="""
    --rm
    -v $HOME:/root
    -v $HOME:$HOME
    -w \"$(sed "s@^$HOME@/root@g" <<< $PWD)\"
    --network host
"""
#    --userns keep-id
#    --init

echo_cmd=0
build_image=0
use_ps1=1

newline="
"

# args to filter from call_flags
script_args=( "--help" "--force-build" "--force-echo" "--force-no-tty" "--force-no-ps1")
all_flags=$@

# choose tty or not
if [[ $all_flags == *"--force-no-tty"* ]]; then
    flags="-i${newline}${flags}"
    all_flags=$(sed "s/['\"]*--force-no-tty['\"]*//g" <<< $all_flags)
else
    flags="-i${use_tty}${newline}${flags}"
fi

# echo command
if [[ $all_flags == *"--force-echo"* ]]; then
    echo_cmd=1
    all_flags=$(sed "s/['\"]*--force-echo['\"]*//g" <<< $all_flags)
fi

# build image
if [[ $all_flags == *"--force-build"* ]]; then
    build_image=1
    all_flags=$(sed "s/['\"]*--force-build['\"]*//g" <<< $all_flags)
fi

# build image
if [[ $all_flags == *"--force-no-ps1"* ]]; then
    use_ps1=0
    all_flags=$(sed "s/['\"]*--force-no-ps1['\"]*//g" <<< $all_flags)
fi


# split flags on " -- ", dividing docker flags from entrypoint cmd
all_flags=$(sed "s/\s['\"]*--['\"]*\s/ -- /g" <<< $all_flags)
if [[ $all_flags =~ "-- " ]]; then
    call_cmd=${all_flags##*-- }
    call_flags=${all_flags%%-- *}
fi

# print help 
if [[ $call_flags =~ ^(.*)--help(.*)$ ]]; then
    echo $help
    exit
fi

# create a nicer ps1 from docker img:ver if not already set
if [ -z "$ps1" ]; then
    if [ -n "$ver" ]; then ps1="$img:$ver"; else ps1="$img:latest"; fi
fi

# append default command, returning to default upon termination
cmd="bash -c \"bash --init-file <(echo \\\"PS1=$ps1\>\ \\\";) --noprofile\""
if [ $use_ps1 -lt 1 ]; then
    cmd="";
elif [[ $call_cmd =~ \;$ ]]; then
    cmd="${call_cmd%;*} && $cmd"
elif [[ -n "$call_cmd" ]]; then 
    cmd=$call_cmd; 
fi

# collapse name
name=$img
if [ -n "$org" ];  then name="$org/$name"; fi
if [ -n "$prot" ]; then name="$prot://$name"; fi
if [ -n "$ver" ];  then name="$name:$ver"; fi

# build local name (same as name unless using a dockerfile via docker)
localname=$name
if [ -n "$dockerfile" ]; then 
  localname="localhost/$img:$ver"
fi

# rebuild if needed
$engine image inspect $localname > /dev/null 2> /dev/null
if ! [ "$?" -eq 0 ] || [ $build_image -gt 0 ]; then
    if [ -n "$dockerfile" ]; then 
        dockerfile="FROM $name$newline$dockerfile";
        echo "$dockerfile";
        $engine image rm --force $localname
        $engine build -t $localname - < <(cat <<< "$dockerfile");
    else 
        $engine pull $name
    fi
fi

# construct a command from extracted components
constructed_cmd="$engine run \
     $call_flags \
     ${config_flags//[$'\t\r\n']} \
     ${flags//[$'\t\r\n']} \
     $localname \
     $cmd"

if [ $echo_cmd -gt 0 ]; then echo "$constructed_cmd"; fi
eval "$constructed_cmd"
