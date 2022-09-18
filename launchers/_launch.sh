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
                   doesn'"'"'t exist or if `---build` is set.

  Additional flags which will be parsed out of `<run flags>`

    ---help        Print this help
    ---build       Force rebuild if a custom `dockerfile` is set
    ---echo        Force echoing of docker command 
    ---no-tty      Force session not to use a tty (uses `-i` instead of `-it`)
    ---no-ps1      Do not attempt to inject a prompt based on image name
'

# use podman by default, but docker if unavailable/not started
if [ -x "$(command -v podman)" ] && 
   (! (podman machine inspect >/dev/null 2>&1) || 
   [[ "$(podman machine inspect)" == *'"State": "running"'* ]]); 
then 
    engine="podman";
else 
    engine="docker";
    [[ $prot -eq "docker" ]] && export name="$prot.io/$name" && unset prot;
fi

test -t 1 && use_tty="t"
echo_cmd=0
build_image=0
use_ps1=1
newline="
"

hit_dash=0
call_flag_next=0
call_flags=()  # before "--"
call_cmd=()    # after "--" 

for i in "$@"; do
  if (( $call_flag_next )); then
    call_flags+=(" $i")
    call_flag_next=0
    shift
    continue
  fi;

  case $1 in
    ---help)
      echo "$help"
      exit
      ;;
    ---build)
      build_image=1
      shift
      ;;
    ---echo)
      echo_cmd=1
      shift
      ;;
    ---no-tty)
      use_tty=""
      shift
      ;;
    ---no-ps1)
      use_ps1=0
      shift
      ;;
    ---tag=*)
      ver="${i#*=}"
      shift
      ;;
    ---*)
      call_flags+=("${i#--*}")
      [[ $i != *"="* ]] && call_flag_next=1
      shift
      ;;
    --)
      call_cmd=()
      hit_dash=1
      shift
      ;;
    *)
      if (( $hit_dash )); then call_cmd+=("$1"); else call_flags+=("$1"); fi
      shift
      ;;
  esac
done

call_cmd="${call_cmd[@]}"
call_flags="${call_flags[@]}"

# if any ports are published, disable host network
if [[ $call_flags != *"-p="* ]] && [[ $call_flags != *"--publish="* ]]; then
    network="--network host";
fi


# set our launch flags, most importantly this:
#  - only uses a tty if one is available
#  - maps home to /root as well as image user home
#  - sets current directory to the working directory within the image
#  - shares the host network to the image
flags="
    --rm
    -i${use_tty}
    -v $HOME:/root
    -v $HOME:$HOME
    -w \"$(sed "s@^$HOME@/root@g" <<< $PWD)\"
    ${network}
"


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
if [ -z "$org"  ]; then org="library"; fi
if [[ "$prot" -eq "docker" ]]; then org="docker.io/$org"; prot=""; fi
if [ -n "$org"  ]; then name="$org/$name"; fi
if [ -n "$prot" ]; then name="$prot://$name"; fi
if [ -n "$ver"  ]; then name="$name:$ver"; fi

# build local name (same as name unless using a dockerfile via docker)
localname=$name
if [ -n "$dockerfile" ]; then 
  localname="localhost/$img"
fi


# rebuild if needed
if ! ($engine image inspect $localname >/dev/null 2>&1) || (( $build_image )); then
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


if (( $echo_cmd )); then echo "$constructed_cmd"; fi
eval "$constructed_cmd"
